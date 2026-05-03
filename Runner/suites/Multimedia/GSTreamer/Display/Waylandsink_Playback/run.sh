#!/bin/sh
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause
# Waylandsink Playback validation using GStreamer
# Tests video playback using waylandsink with videotestsrc
# Validates Weston/Wayland server and display connectivity
# CI/LAVA-friendly (always exits 0, writes .res file)
#
# Runs 4 tests at different resolutions: 480p, 720p, 1080p, 2160p

SCRIPT_DIR="$(
  cd "$(dirname "$0")" || exit 1
  pwd
)"

TESTNAME="Waylandsink_Playback"
RES_FILE="${SCRIPT_DIR}/${TESTNAME}.res"
LOG_DIR="${SCRIPT_DIR}/logs"

mkdir -p "$LOG_DIR" >/dev/null 2>&1 || true
: >"$RES_FILE"

SCRIPT_DIR="$(
  cd "$(dirname "$0")" || exit 1
  pwd
)"
 
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
  echo "$TESTNAME SKIP" >"$RES_FILE" 2>/dev/null || true
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

# shellcheck disable=SC1091
[ -f "$TOOLS/lib_display.sh" ] && . "$TOOLS/lib_display.sh"

# -------------------- Defaults --------------------
# Validate environment variables if set
if [ -n "${VIDEO_DURATION:-}" ] && ! echo "$VIDEO_DURATION" | grep -q "^[0-9]\+$"; then
  log_warn "VIDEO_DURATION must be numeric (got '$VIDEO_DURATION')"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi
if [ -n "${RUNTIMESEC:-}" ] && ! echo "$RUNTIMESEC" | grep -q "^[0-9]\+$"; then
  log_warn "RUNTIMESEC must be numeric (got '$RUNTIMESEC')"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi
if [ -n "${VIDEO_FRAMERATE:-}" ] && ! echo "$VIDEO_FRAMERATE" | grep -q "^[0-9]\+$"; then
  log_warn "VIDEO_FRAMERATE must be numeric (got '$VIDEO_FRAMERATE')"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi
if [ -n "${VIDEO_GST_DEBUG:-${GST_DEBUG_LEVEL:-}}" ] && ! echo "${VIDEO_GST_DEBUG:-${GST_DEBUG_LEVEL:-}}" | grep -q "^[0-9]\+$"; then
  log_warn "GST debug level must be numeric (got '${VIDEO_GST_DEBUG:-${GST_DEBUG_LEVEL:-}}')"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi

duration="${VIDEO_DURATION:-${RUNTIMESEC:-30}}"
pattern="${VIDEO_PATTERN:-smpte}"
framerate="${VIDEO_FRAMERATE:-30}"
gstDebugLevel="${VIDEO_GST_DEBUG:-${GST_DEBUG_LEVEL:-2}}"
lava_testcase_id="${LAVA_TESTCASE_ID:-Waylandsink_Playback}"
resolution_list=""

# shellcheck disable=SC2317
cleanup() {
  # Best-effort: try to kill only children first; fall back to name-based kill
  if ! pkill -P "$$" -x gst-launch-1.0 >/dev/null 2>&1; then
    pkill -x gst-launch-1.0 >/dev/null 2>&1 || true
  fi
}
trap cleanup INT TERM EXIT

# -------------------- Arg parse --------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --resolution)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --resolution"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        resolution_list="$2"
      fi
      shift 2
      ;;

    --lava-testcase-id)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --lava-testcase-id"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        lava_testcase_id="$2"
      fi
      shift 2
      ;;

    --duration)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --duration"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        if ! echo "$2" | grep -q "^[0-9]\+$"; then
          log_warn "Duration must be a numeric value (got '$2')"
          echo "$TESTNAME SKIP" >"$RES_FILE"
          exit 0
        fi
        duration="$2"
      fi
      shift 2
      ;;

    --pattern)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --pattern"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      # If $2 is empty, keep default and shift 2
      [ -n "$2" ] && pattern="$2"
      shift 2
      ;;

    --framerate)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --framerate"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if [ -n "$2" ]; then
        if ! echo "$2" | grep -q "^[0-9]\+$"; then
          log_warn "Framerate must be a numeric value (got '$2')"
          echo "$TESTNAME SKIP" >"$RES_FILE"
          exit 0
        fi
        framerate="$2"
      fi
      shift 2
      ;;

    --gst-debug)
      if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then
        log_warn "Missing/invalid value for --gst-debug"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      if ! echo "$2" | grep -q "^[0-9]\+$"; then
        log_warn "GST debug level must be numeric (got '$2')"
        echo "$TESTNAME SKIP" >"$RES_FILE"
        exit 0
      fi
      gstDebugLevel="$2"
      shift 2
      ;;

    -h|--help)
      cat <<EOF
Usage:
  $0 [options]

Runs 4 tests at standard resolutions: 480p, 720p, 1080p, 2160p

Options:
  --resolution <list>
      Comma-separated list of resolutions (e.g., "480p,720p,1080p,2160p")
      Supported named resolutions: 480p, 720p, 1080p, 2160p
      Default: 480p,720p,1080p,2160p

  --duration <seconds>
      Playback duration in seconds
      Default: ${duration}

  --pattern <smpte|snow|ball|etc>
      videotestsrc pattern
      Default: ${pattern}

  --framerate <fps>
      Video framerate
      Default: ${framerate}

  --gst-debug <level>
      Sets GST_DEBUG=<level> (1-9)
      Default: ${gstDebugLevel}

  --lava-testcase-id <id>
      LAVA testcase ID prefix for result reporting
      Default: ${lava_testcase_id}

Examples:
  # Run default 4 tests (480p, 720p, 1080p, 2160p)
  ./run.sh

  # Run specific resolutions
  ./run.sh --resolution "480p,1080p"

  # Run with LAVA testcase ID
  ./run.sh --resolution "480p,720p" --lava-testcase-id "Waylandsink_Playback"

EOF
      echo "$TESTNAME SKIP" >"$RES_FILE"
      exit 0
      ;;

    *)
      log_warn "Unknown argument: $1"
      echo "$TESTNAME SKIP" >"$RES_FILE"
      exit 0
      ;;
  esac
done

# ==================== FUNCTION: Run display test at specified resolution ====================
run_display_test() {
  test_width="$1"
  test_height="$2"
  test_name="$3"
  
  OUTDIR="$LOG_DIR/${test_name}"
  GST_LOG="$OUTDIR/gst.log"
  RUN_LOG="$OUTDIR/run.log"
  
  mkdir -p "$OUTDIR" >/dev/null 2>&1 || true
  : >"$GST_LOG"
  : >"$RUN_LOG"
  
  # Basic sanity
  if [ "$duration" -le 0 ] || [ "$test_width" -le 0 ] || [ "$test_height" -le 0 ] || [ "$framerate" -le 0 ]; then
    log_warn "Invalid parameters: duration=$duration width=$test_width height=$test_height framerate=$framerate"
    return 2  # SKIP
  fi
  
  log_info "Test: $test_name"
  log_info "Duration: ${duration}s, Resolution: ${test_width}x${test_height}, Framerate: ${framerate}fps"
  log_info "Pattern: $pattern"
  log_info "GST debug: GST_DEBUG=$gstDebugLevel"
  log_info "Logs: $OUTDIR"
  
  # -------------------- GStreamer debug capture --------------------
  export GST_DEBUG_NO_COLOR=1
  export GST_DEBUG="$gstDebugLevel"
  export GST_DEBUG_FILE="$GST_LOG"
  
  # -------------------- Build and run pipeline --------------------
  num_buffers=$((duration * framerate))
  
  pipeline="videotestsrc is-live=true num-buffers=${num_buffers} pattern=${pattern} ! video/x-raw,width=${test_width},height=${test_height},framerate=${framerate}/1 ! videoconvert ! waylandsink"
  
  log_info "Pipeline: $pipeline"
  
  # Run with timeout
  start_ts=$(date +%s)
  timeout_sec=$((duration + 15))
  
  if gstreamer_run_gstlaunch_timeout "$timeout_sec" "$pipeline" >>"$RUN_LOG" 2>&1; then
    gstRc=0
  else
    gstRc=$?
  fi
  
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  
  log_info "Playback finished: rc=${gstRc} elapsed=${elapsed}s"
  
  # -------------------- Validation --------------------
  if [ "$duration" -gt 2 ]; then
    min_duration=$((duration - 2))
  else
    min_duration=0
  fi
  
  # Check for GStreamer errors in both run log and GST debug log
  run_log_ok=1
  gst_log_ok=1
  
  # Validate run log
  if ! gstreamer_validate_log "$RUN_LOG" "$test_name"; then
    run_log_ok=0
  fi
  
  # Validate last 1000 lines of GST debug log if it exists and has content
  if [ -s "$GST_LOG" ]; then
    tmp_tail=$(mktemp "${OUTDIR}/gst.tail.XXXXXX" 2>/dev/null || mktemp) || tmp_tail=""
    if [ -n "$tmp_tail" ]; then
      tail -n 1000 "$GST_LOG" >"$tmp_tail" 2>/dev/null || true
      if ! gstreamer_validate_log "$tmp_tail" "$test_name"; then
        gst_log_ok=0
      fi
      rm -f "$tmp_tail" >/dev/null 2>&1 || true
    else
      # If mktemp failed, fall back to validating the full GST log
      if ! gstreamer_validate_log "$GST_LOG" "$test_name"; then
        gst_log_ok=0
      fi
    fi
    rm -f "${GST_LOG}.tail"
  fi
  
  if [ "$run_log_ok" -eq 0 ] || [ "$gst_log_ok" -eq 0 ]; then
    result="FAIL"
    if [ "$run_log_ok" -eq 0 ] && [ "$gst_log_ok" -eq 0 ]; then
      reason="GStreamer errors detected in both run log and GST debug log"
    elif [ "$run_log_ok" -eq 0 ]; then
      reason="GStreamer errors detected in run log"
    else
      reason="GStreamer errors detected in GST debug log"
    fi
  else
    # First check if it ran long enough
    if [ "$elapsed" -ge "$min_duration" ]; then
      # If it ran long enough, check exit code
      case "$gstRc" in
        0)  # Normal exit
          result="PASS"
          reason="Playback completed successfully (elapsed=${elapsed}/${duration}s)"
          ;;
        124)
          result="FAIL"
          reason="Playback timed out (timeout=${timeout_sec}s, elapsed=${elapsed}s) - pipeline did not exit cleanly"
          ;;
        137|143)
          result="FAIL"
          reason="Playback killed by signal (rc=$gstRc, elapsed=${elapsed}s) - unexpected termination"
          ;;
        *)  # Unexpected return code
          result="FAIL"
          reason="Playback failed with unexpected exit code (rc=$gstRc, elapsed=${elapsed}/${duration}s)"
          ;;
      esac
    else
      # Didn't run long enough - always fail regardless of return code
      result="FAIL"
      reason="Playback exited too quickly (elapsed=${elapsed}s, minimum required=${min_duration}s)"
    fi
  fi
  
  # Helpful tails on failure (stdout visibility in CI)
  if [ "$result" != "PASS" ]; then
    log_info "---- gst-launch output (tail) ----"
    tail -n 120 "$RUN_LOG" 2>/dev/null || true
    if [ -s "$GST_LOG" ]; then
      log_info "---- GST debug log (tail) ----"
      tail -n 120 "$GST_LOG" 2>/dev/null || true
    fi
  fi
  
  # -------------------- Emit result --------------------
  case "$result" in
    PASS)
      log_pass "$test_name $result: $reason"
      return 0
      ;;
    *)
      log_fail "$test_name $result: $reason"
      return 1
      ;;
  esac
}

# ==================== PRE-CHECKS (Common for all tests) ====================
check_dependencies "gst-launch-1.0 gst-inspect-1.0 grep head sed tail date mktemp" >/dev/null 2>&1 || {
  log_skip "Missing required tools (gst-launch-1.0, gst-inspect-1.0, grep, head, sed, tail, date, mktemp)"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
}

# -------------------- Display connectivity check --------------------
if command -v display_debug_snapshot >/dev/null 2>&1; then
  display_debug_snapshot "pre-test"
fi

have_connector=0
if command -v display_connected_summary >/dev/null 2>&1; then
  sysfs_summary=$(display_connected_summary)
  if [ -n "$sysfs_summary" ] && [ "$sysfs_summary" != "none" ]; then
    have_connector=1
    log_info "Connected display (sysfs): $sysfs_summary"
  fi
fi

# Fallback: check /sys/class/drm/*/status
if [ "$have_connector" -eq 0 ]; then
  drm_connected=""
  for st in /sys/class/drm/card*-*/status; do
    [ -f "$st" ] || continue
    if grep -qi "connected" "$st"; then
      conn=$(basename "$(dirname "$st")")
      drm_connected="${drm_connected}${drm_connected:+,}${conn}"
    fi
  done
  if [ -n "$drm_connected" ]; then
    have_connector=1
    log_info "Connected display (drm sysfs): $drm_connected"
  fi
fi

if [ "$have_connector" -eq 0 ]; then
  log_warn "No connected DRM display found, skipping ${TESTNAME}."
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi

# -------------------- Wayland/Weston environment check --------------------
if command -v wayland_debug_snapshot >/dev/null 2>&1; then
  wayland_debug_snapshot "${TESTNAME}: start"
fi

sock=""

# Try to find existing Wayland socket
if command -v discover_wayland_socket_anywhere >/dev/null 2>&1; then
  sock=$(discover_wayland_socket_anywhere | head -n 1 || true)
fi

# Adopt socket environment if found
if [ -n "$sock" ] && command -v adopt_wayland_env_from_socket >/dev/null 2>&1; then
  log_info "Found existing Wayland socket: $sock"
  if ! adopt_wayland_env_from_socket "$sock"; then
    log_warn "Failed to adopt env from $sock"
  fi
fi

# Try starting Weston if no socket found
if [ -z "$sock" ]; then
  if command -v weston_pick_env_or_start >/dev/null 2>&1; then
    log_info "No usable Wayland socket; trying weston_pick_env_or_start..."
    if weston_pick_env_or_start "${TESTNAME}"; then
      # Re-discover socket after Weston start
      if command -v discover_wayland_socket_anywhere >/dev/null 2>&1; then
        sock=$(discover_wayland_socket_anywhere | head -n 1 || true)
      fi
      if [ -n "$sock" ]; then
        log_info "Weston started successfully with socket: $sock"
        if command -v adopt_wayland_env_from_socket >/dev/null 2>&1; then
          adopt_wayland_env_from_socket "$sock" >/dev/null 2>&1 || true
        fi
      fi
    else
      log_warn "weston_pick_env_or_start failed"
    fi
  elif command -v overlay_start_weston_drm >/dev/null 2>&1; then
    log_info "No usable Wayland socket; trying overlay_start_weston_drm (fallback)..."
    if overlay_start_weston_drm; then
      if command -v discover_wayland_socket_anywhere >/dev/null 2>&1; then
        sock=$(discover_wayland_socket_anywhere | head -n 1 || true)
      fi
      if [ -n "$sock" ]; then
        log_info "Weston created Wayland socket: $sock"
        if command -v adopt_wayland_env_from_socket >/dev/null 2>&1; then
          adopt_wayland_env_from_socket "$sock" >/dev/null 2>&1 || true
        fi
      fi
    fi
  else
    log_warn "No Weston startup helper available (weston_pick_env_or_start or overlay_start_weston_drm)"
  fi
fi

# Final check
if [ -z "$sock" ]; then
  log_warn "No Wayland socket found; skipping ${TESTNAME}."
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi

# Verify Wayland connection
if command -v wayland_connection_ok >/dev/null 2>&1; then
  if ! wayland_connection_ok; then
    log_warn "Wayland connection test failed; skipping ${TESTNAME}."
    echo "$TESTNAME SKIP" >"$RES_FILE"
    exit 0
  fi
  log_info "Wayland connection test: OK"
fi

# -------------------- Check waylandsink element --------------------
if ! has_element waylandsink; then
  log_warn "waylandsink element not available"
  echo "$TESTNAME SKIP" >"$RES_FILE"
  exit 0
fi

log_info "waylandsink element: available"

# ==================== RUN TESTS ====================
# Use resolution_list if provided, otherwise default to 4 standard resolutions
if [ -z "$resolution_list" ]; then
  resolution_list="480p,720p,1080p,2160p"
fi

# Convert comma-separated list to space-separated for iteration
resolutions=$(echo "$resolution_list" | tr ',' ' ')

# Count total tests
total_tests=0
for res in $resolutions; do
  total_tests=$((total_tests + 1))
done

log_info "=========================================="
log_info "Running $total_tests resolution test(s)"
log_info "Resolutions: $resolution_list"
log_info "=========================================="

passed_tests=0
failed_tests=0
test_num=0

  # Run test for each resolution
  for res in $resolutions; do
    test_num=$((test_num + 1))
    
    # Convert resolution to width x height using library function
    wh=$(gstreamer_resolution_to_wh "$res")
  if [ -z "$wh" ]; then
    log_warn "Invalid resolution: $res"
    failed_tests=$((failed_tests + 1))
    echo "${lava_testcase_id}_${res} FAIL" >>"$RES_FILE"
    continue
  fi
  
  test_width=$(echo "$wh" | cut -d' ' -f1)
  test_height=$(echo "$wh" | cut -d' ' -f2)
  
  # Determine test name suffix
  case "$res" in
    480p|720p|1080p|2160p|4k)
      test_suffix=$(echo "$res" | tr '[:lower:]' '[:upper:]' | sed 's/P$/p/')
      ;;
    *)
      test_suffix="${test_width}x${test_height}"
      ;;
  esac
  
  test_name="${lava_testcase_id}_${test_suffix}"
  
  log_info ""
  log_info "=========================================="
  log_info "Test $test_num/$total_tests: $test_name"
  log_info "Resolution: ${test_width}x${test_height}"
  log_info "=========================================="
  
  if run_display_test "$test_width" "$test_height" "$test_name"; then
    passed_tests=$((passed_tests + 1))
    echo "$test_name PASS" >>"$RES_FILE"
  else
    failed_tests=$((failed_tests + 1))
    echo "$test_name FAIL" >>"$RES_FILE"
  fi
done

# -------------------- Summary --------------------
log_info ""
log_info "=========================================="
log_info "Multi-Resolution Test Suite Summary"
log_info "=========================================="
log_info "Total tests: $total_tests"
log_info "Passed: $passed_tests"
log_info "Failed: $failed_tests"
log_info "=========================================="

# Overall result
if [ "$failed_tests" -eq 0 ]; then
  log_pass "${lava_testcase_id} PASS ($passed_tests/$total_tests tests passed)"
  echo "${lava_testcase_id} PASS" >"$RES_FILE"
else
  log_fail "${lava_testcase_id} FAIL ($failed_tests/$total_tests tests failed)"
  echo "${lava_testcase_id} FAIL" >"$RES_FILE"
fi

exit 0
