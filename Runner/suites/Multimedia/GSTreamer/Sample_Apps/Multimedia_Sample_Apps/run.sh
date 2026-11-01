#!/bin/sh
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause
# Multimedia Sample Apps validation using GStreamer
# Executes sample apps from /usr/bin/ with 30s timeout and Ctrl+C termination
# Supports multiple categories: video, display, camera
# Logs everything to console and local log files.
# PASS/FAIL/SKIP is emitted to .res. Always exits 0 (LAVA-friendly).

SCRIPT_DIR="$(
  cd "$(dirname "$0")" || exit 1
  pwd
)"

TESTNAME="Multimedia_Sample_Apps"
RESULT_TESTNAME="$TESTNAME"
RES_FILE="${SCRIPT_DIR}/${TESTNAME}.res"
LOG_DIR="${SCRIPT_DIR}/logs"
OUTDIR="$LOG_DIR/$TESTNAME"
GST_LOG="$OUTDIR/gst.log"
DMESG_DIR="$OUTDIR/dmesg"

INIT_ENV=""
SEARCH="$SCRIPT_DIR"
while [ "$SEARCH" != "/" ]; do
  if [ -f "$SEARCH/init_env" ]; then
    INIT_ENV="$SEARCH/init_env"
    break
  fi
  SEARCH=$(dirname "$SEARCH")
done

if [ -z "${INIT_ENV:-}" ]; then
  echo "[ERROR] Could not find init_env (starting at $SCRIPT_DIR)" >&2
  echo "$RESULT_TESTNAME SKIP" >"$RES_FILE" 2>/dev/null || true
  exit 0
fi

if [ -z "${__INIT_ENV_LOADED:-}" ]; then
  # shellcheck disable=SC1090
  . "$INIT_ENV"
  __INIT_ENV_LOADED=1
fi

# shellcheck disable=SC1091
. "$TOOLS/functestlib.sh"

# shellcheck disable=SC1091
. "$TOOLS/lib_gstreamer.sh"

if ! mkdir -p "$OUTDIR" "$DMESG_DIR"; then
  log_error "Failed to create required directories"
  echo "$RESULT_TESTNAME FAIL" >"$RES_FILE" 2>/dev/null || true
  exit 0
fi

: >"$RES_FILE"
: >"$GST_LOG"

result="FAIL"
reason="unknown"
pass_count=0
fail_count=0
skip_count=0
total_tests=0

# -------------------- Sample Apps Lists by Category --------------------
# Audio apps - available in both Config1 and Config2
MM_AUDIO_APPS="
gst-audio-encode-example
gst-audio-decode-example
"

# Video apps - available in both Config1 and Config2
MM_VIDEO_APPS_COMMON="
gst-concurrent-videoplay-composition
gst-concurrent-videoplay-composition.py
gst-videocodec-concurrent-playback
gst-audio-video-playback
gst-video-transcode-example
gst-video-playback-example
gst-opencv-transform.py
"

# Video apps only available in Config2 (CAMX/downstream) - NA in Config1 (require qtiqmmfsrc)
MM_VIDEO_APPS_CONFIG2="
gst-smartcodec-example
gst-audio-video-encode
gst-ai-smartcodec-example
"

# Camera apps - available in both Config1 and Config2
MM_CAMERA_APPS_COMMON="
gst-camera-single-stream-example
gst-appsink-example
gst-transform-example
gst-camera-opencv-resize.py
GstD-camera-single-stream-example
gst-camera-encode.py
gst-camera-rotate-downscale-file.py
"

# Camera apps only available in Config2 (CAMX/downstream) - NA in Config1
MM_CAMERA_APPS_CONFIG2="
gst-multi-camera-example
gst-multi-stream-example
gst-snapshot-stream-example
gst-activate-deactivate-streams-runtime-example
gst-add-remove-streams-runtime
gst-camera-metadata-example
gst-add-streams-as-bundle-example
gst-camera-burst-capture-example
gst-camera-switch-example
gst-camera-shdr-ldc-eis-example
gst-multi-camera-stream-example.py
gst-jpg-image-decode.py
gst-jpg-decode-example
"

# Display apps - available in both Config1 and Config2
MM_DISPLAY_APPS="
gst-weston-composition-example
"

# -------------------- Defaults --------------------
appTimeout="${SAMPLE_APP_TIMEOUT:-30}"
gstDebugLevel="${SAMPLE_APP_GST_DEBUG:-${GST_DEBUG_LEVEL:-2}}"
specificApp=""
categoryFilter=""

# -------------------- Build Configuration Detection --------------------
# Detect build configuration: Config1 (upstream) or Config2 (CAMX/downstream)
# Config2 has qtiqmmfsrc plugin, Config1 does not
buildConfig="unknown"
if has_element qtiqmmfsrc; then
  buildConfig="config2"
  log_info "Detected Config2 (CAMX/downstream) - qtiqmmfsrc available"
else
  buildConfig="config1"
  log_info "Detected Config1 (upstream) - qtiqmmfsrc not available"
fi

# Build final app lists based on configuration
if [ "$buildConfig" = "config2" ]; then
  # Config2: Common + Config2-specific apps
  MM_VIDEO_APPS="$MM_VIDEO_APPS_COMMON
$MM_VIDEO_APPS_CONFIG2"
  MM_CAMERA_APPS="$MM_CAMERA_APPS_COMMON
$MM_CAMERA_APPS_CONFIG2"
  log_info "Config2 apps: 2 audio + 10 video + 20 camera + 1 display = 33 total"
else
  # Config1: Common apps only
  MM_VIDEO_APPS="$MM_VIDEO_APPS_COMMON"
  MM_CAMERA_APPS="$MM_CAMERA_APPS_COMMON"
  log_info "Config1 apps: 2 audio + 7 video + 7 camera + 1 display = 17 total"
fi

# Validate environment variables if set
if [ -n "${SAMPLE_APP_TIMEOUT:-}" ]; then
  case "$SAMPLE_APP_TIMEOUT" in
    ''|*[!0-9]*) 
      log_warn "SAMPLE_APP_TIMEOUT must be numeric (got '$SAMPLE_APP_TIMEOUT')"
      echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
      exit 0
      ;;
    *)
      if [ "$SAMPLE_APP_TIMEOUT" -le 0 ] 2>/dev/null; then
        log_warn "SAMPLE_APP_TIMEOUT must be positive (got '$SAMPLE_APP_TIMEOUT')"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      ;;
  esac
fi

# shellcheck disable=SC2317
cleanup() {
  pkill -P "$$" >/dev/null 2>&1 || true
}
trap cleanup INT TERM EXIT

# -------------------- Arg parse --------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --category)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --category"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        case "$2" in
          audio|video|display|camera|all)
            categoryFilter="$2"
            ;;
          *)
            log_warn "Invalid --category '$2' (must be: audio, video, display, camera, or all)"
            echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
            exit 0
            ;;
        esac
      fi
      shift 2
      ;;
    --app)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --app"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      [ -n "$2" ] && specificApp="$2"
      shift 2
      ;;
    --timeout)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --timeout"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        case "$2" in
          ''|*[!0-9]*)
            log_warn "Invalid --timeout '$2' (must be numeric)"
            echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
            exit 0
            ;;
          *)
            appTimeout="$2"
            ;;
        esac
      fi
      shift 2
      ;;
    --gst-debug)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --gst-debug"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      [ -n "$2" ] && gstDebugLevel="$2"
      shift 2
      ;;
    --lava-testcase-id)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --lava-testcase-id"
        echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      [ -n "$2" ] && RESULT_TESTNAME="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Multimedia Sample Apps - GStreamer Sample Applications Validation

OVERVIEW:
  This test suite validates GStreamer multimedia sample applications across
  four categories: audio, video, display, and camera.
  
  Build configuration is auto-detected based on qtiqmmfsrc plugin availability:
  - Config1 (Upstream): 17 apps (2 audio + 7 video + 7 camera + 1 display)
  - Config2 (CAMX/Downstream): 33 apps (2 audio + 10 video + 20 camera + 1 display)

SAMPLE APPS BY CATEGORY:

  MM_Audio (2 apps - both configs):
    - gst-audio-encode-example
    - gst-audio-decode-example

  MM_Video (Config1: 7 apps | Config2: 10 apps):
    Common (both configs):
      - gst-concurrent-videoplay-composition
      - gst-concurrent-videoplay-composition.py
      - gst-videocodec-concurrent-playback
      - gst-audio-video-playback
      - gst-video-transcode-example
      - gst-video-playback-example
      - gst-opencv-transform.py
    Config2 only:
      - gst-smartcodec-example
      - gst-audio-video-encode
      - gst-ai-smartcodec-example

  MM_Camera (Config1: 7 apps | Config2: 20 apps):
    Common (both configs):
      - gst-camera-single-stream-example
      - gst-appsink-example
      - gst-transform-example
      - gst-camera-opencv-resize.py
      - GstD-camera-single-stream-example
      - gst-camera-encode.py
      - gst-camera-rotate-downscale-file.py
    Config2 only (require qtiqmmfsrc):
      - gst-multi-camera-example
      - gst-multi-stream-example
      - gst-snapshot-stream-example
      - gst-activate-deactivate-streams-runtime-example
      - gst-add-remove-streams-runtime
      - gst-camera-metadata-example
      - gst-add-streams-as-bundle-example
      - gst-camera-burst-capture-example
      - gst-camera-switch-example
      - gst-camera-shdr-ldc-eis-example
      - gst-multi-camera-stream-example.py
      - gst-jpg-image-decode.py
      - gst-jpg-decode-example

  MM_Display (1 app - both configs):
    - gst-weston-composition-example

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --category <name>       Run specific category (default: all)
                          Options: audio, video, display, camera, all
                          Examples:
                            --category audio    (2 apps)
                            --category video    (7 or 10 apps)
                            --category camera   (7 or 20 apps)
                            --category display  (1 app)
                            --category all      (17 or 33 apps)

  --app <name>            Run specific sample app only
                          Example: --app gst-video-playback-example

  --timeout <seconds>     Timeout per app in seconds (default: 30)
                          Apps are terminated with SIGINT (Ctrl+C) after timeout

  --gst-debug <level>     GStreamer debug level 1-9 (default: 2)
                          Higher levels provide more detailed debug output

  --lava-testcase-id <name>
                          Override test case name for LAVA reporting

  -h, --help              Display this help message

ENVIRONMENT VARIABLES:
  SAMPLE_APP_TIMEOUT      Same as --timeout
  SAMPLE_APP_GST_DEBUG    Same as --gst-debug
  GST_DEBUG_LEVEL         Alternative to SAMPLE_APP_GST_DEBUG

EXAMPLES:
  # Run all sample apps (auto-detects config: 17 or 33 apps)
  $0

  # Run specific category
  $0 --category audio
  $0 --category video
  $0 --category camera
  $0 --category display

  # Run specific app
  $0 --app gst-video-playback-example

  # Run with custom timeout
  $0 --category video --timeout 60

  # Run specific app with custom timeout and debug
  $0 --app gst-audio-video-playback --timeout 45 --gst-debug 5

OUTPUT:
  Result File:  Multimedia_Sample_Apps.res (PASS/FAIL/SKIP)
  Logs:         logs/Multimedia_Sample_Apps/<app-name>.log
  GStreamer:    logs/Multimedia_Sample_Apps/gst.log

NOTES:
  - Apps are executed from /usr/bin/ with no additional parameters
  - Each app runs for specified timeout and is terminated with SIGINT
  - Exit code 0 or 124 (timeout) are considered success
  - GStreamer error validation is performed on all apps
  - Build configuration auto-detected via qtiqmmfsrc plugin availability

EOF
      exit 0
      ;;
    *)
      log_warn "Unknown argument: $1"
      echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
      exit 0
      ;;
  esac
done

# -------------------- Pre-checks --------------------
check_dependencies "gst-launch-1.0 gst-inspect-1.0" >/dev/null 2>&1 || {
  log_skip "Missing required tools (gst-launch-1.0, gst-inspect-1.0)"
  echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
  exit 0
}

log_info "Test: $TESTNAME"
log_info "Timeout per app: ${appTimeout}s"
log_info "GST debug: GST_DEBUG=$gstDebugLevel"
log_info "Logs: $OUTDIR"

if [ -n "$specificApp" ]; then
  log_info "Running specific app: $specificApp"
elif [ -n "$categoryFilter" ]; then
  log_info "Running category: $categoryFilter"
else
  log_info "Running all categories (video, display, camera)"
  categoryFilter="all"
fi

# -------------------- GStreamer debug capture --------------------
export GST_DEBUG_NO_COLOR=1
export GST_DEBUG="$gstDebugLevel"
export GST_DEBUG_FILE="$GST_LOG"

# -------------------- Sample App Execution Function --------------------
run_sample_app() {
  app_name="$1"
  category="$2"
  
  total_tests=$((total_tests + 1))
  
  log_info "=========================================="
  log_info "Running: $app_name [$category]"
  log_info "=========================================="
  
  # Check if app exists in /usr/bin
  app_path="/usr/bin/$app_name"
  if [ ! -f "$app_path" ] && [ ! -L "$app_path" ]; then
    log_warn "$app_name: Not found in /usr/bin"
    skip_count=$((skip_count + 1))
    return 1
  fi
  
  # Check if app is executable
  if [ ! -x "$app_path" ]; then
    log_warn "$app_name: Not executable"
    skip_count=$((skip_count + 1))
    return 1
  fi
  
  test_log="$OUTDIR/${app_name}.log"
  : >"$test_log"
  
  log_info "Executing: $app_path (timeout: ${appTimeout}s)"
  
  # Execute app with timeout, sending SIGINT (Ctrl+C) for graceful termination
  # gstreamer_run_bounded escalates to SIGKILL after GST_KILL_GRACE seconds if app doesn't respond
  gstreamer_run_bounded "$appTimeout" INT "$app_path" >>"$test_log" 2>&1
  app_rc=$?
  
  log_info "Exit code: $app_rc (raw: ${GST_BOUNDED_RAW_RC:-$app_rc})"
  
  # Check for SIGKILL escalation (137 normalized to 124)
  # A SIGKILL means the app hung and had to be force-killed - this is a failure
  if [ "${GST_BOUNDED_RAW_RC:-}" = "137" ]; then
    log_fail "$app_name: FAIL (app hung and required SIGKILL, raw exit: 137, normalized: $app_rc)"
    fail_count=$((fail_count + 1))
    return 1
  fi
  
  # Validate log for GStreamer errors
  if ! gstreamer_validate_log "$test_log" "$app_name"; then
    log_fail "$app_name: FAIL (GStreamer errors detected)"
    fail_count=$((fail_count + 1))
    return 1
  fi
  
  # Check exit status
  # For sample apps that run until timeout, SIGINT termination (124) is success
  if [ "$app_rc" -eq 0 ] || gstreamer_bounded_timed_out "$app_rc"; then
    log_pass "$app_name: PASS"
    pass_count=$((pass_count + 1))
    return 0
  else
    log_fail "$app_name: FAIL (rc=$app_rc)"
    fail_count=$((fail_count + 1))
    return 1
  fi
}

# -------------------- Category Runner --------------------
run_category() {
  category_name="$1"
  apps_list="$2"
  
  log_info "=========================================="
  log_info "Category: $category_name"
  log_info "=========================================="
  
  for app in $apps_list; do
    # Skip empty lines
    [ -z "$app" ] && continue
    run_sample_app "$app" "$category_name"
  done
}

# -------------------- Main Execution --------------------
if [ -n "$specificApp" ]; then
  # Run specific app only (determine category automatically)
  run_sample_app "$specificApp" "specific"
else
  # Run by category filter
  case "$categoryFilter" in
    audio)
      run_category "MM_Audio" "$MM_AUDIO_APPS"
      ;;
    video)
      run_category "MM_Video" "$MM_VIDEO_APPS"
      ;;
    display)
      run_category "MM_Display" "$MM_DISPLAY_APPS"
      ;;
    camera)
      run_category "MM_Camera" "$MM_CAMERA_APPS"
      ;;
    all|*)
      run_category "MM_Audio" "$MM_AUDIO_APPS"
      run_category "MM_Video" "$MM_VIDEO_APPS"
      run_category "MM_Display" "$MM_DISPLAY_APPS"
      run_category "MM_Camera" "$MM_CAMERA_APPS"
      ;;
  esac
fi

# -------------------- Summary --------------------
log_info "=========================================="
log_info "Test Summary"
log_info "=========================================="
log_info "Total tests: $total_tests"
log_info "Passed: $pass_count"
log_info "Failed: $fail_count"
log_info "Skipped: $skip_count"
log_info "=========================================="

# Determine overall result
if [ "$total_tests" -eq 0 ]; then
  result="SKIP"
  reason="No tests executed"
elif [ "$skip_count" -eq "$total_tests" ]; then
  result="SKIP"
  reason="All tests skipped"
elif [ "$fail_count" -gt 0 ]; then
  result="FAIL"
  reason="$fail_count of $total_tests tests failed"
else
  result="PASS"
  reason="All $pass_count tests passed"
fi

# -------------------- Emit result --------------------
case "$result" in
  PASS)
    log_pass "$RESULT_TESTNAME $result: $reason"
    echo "$RESULT_TESTNAME PASS" >"$RES_FILE"
    ;;
  SKIP)
    log_skip "$RESULT_TESTNAME $result: $reason"
    echo "$RESULT_TESTNAME SKIP" >"$RES_FILE"
    ;;
  *)
    log_fail "$RESULT_TESTNAME $result: $reason"
    echo "$RESULT_TESTNAME FAIL" >"$RES_FILE"
    ;;
esac

exit 0