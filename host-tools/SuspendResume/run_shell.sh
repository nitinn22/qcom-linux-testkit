#!/bin/sh

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Robustly find and source init_env
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_ENV=""
SEARCH="$SCRIPT_DIR"
while [ "$SEARCH" != "/" ]; do
    if [ -f "$SEARCH/init_env" ]; then
        INIT_ENV="$SEARCH/init_env"
        break
    fi
    SEARCH=$(dirname "$SEARCH")
done

if [ -z "$INIT_ENV" ]; then
    echo "[ERROR] Could not find init_env (starting at $SCRIPT_DIR)" >&2
    exit 1
fi

# Only source if not already loaded (idempotent)
if [ -z "$__INIT_ENV_LOADED" ]; then
    # shellcheck disable=SC1090
    . "$INIT_ENV"
fi
# Always source functestlib.sh, using $TOOLS exported by init_env
# shellcheck disable=SC1090,SC1091
. "$TOOLS/functestlib.sh"

TESTNAME="SuspendResume"
test_path=$(find_test_case_by_name "$TESTNAME")
cd "$test_path" || exit 1
# shellcheck disable=SC2034
res_file="./$TESTNAME.res"

log_info "-----------------------------------------------------------------------------------------"
log_info "-------------------Starting $TESTNAME Testcase----------------------------"
log_info "=== Test Initialization ==="

# ============================================================================
# SETUP PHASE: Prepare system for suspend/resume test
# ============================================================================

# Remount filesystems as read-write (best-effort for systems with ro rootfs)
mount -o remount,rw / >/dev/null 2>&1
mount -o remount,rw /usr >/dev/null 2>&1

# Mount debugfs to access kernel suspend statistics
mount -t debugfs none /sys/kernel/debug >/dev/null 2>&1

# Verify suspend stats are accessible
SUSPEND_STATS_PATH="/sys/power/suspend_stats/success"
if [ ! -r "$SUSPEND_STATS_PATH" ]; then
    log_fail "Cannot read $SUSPEND_STATS_PATH - kernel may not support suspend stats"
    echo "$TESTNAME FAIL" > "$res_file"
    exit 1
fi

# Record initial suspend count for comparison after resume
INITIAL_SUSPEND_COUNT=$(cat "$SUSPEND_STATS_PATH" 2>/dev/null || echo "0")
log_info "Initial suspend count: $INITIAL_SUSPEND_COUNT"

# Clean up old result files from previous runs
log_info "Cleaning up old result files..."
rm -f "$res_file" "$test_path/RESULT_DISPLAY.txt" "$test_path/suspend_monitor.log"

# Configure suspend mode to s2idle (modern suspend-to-idle)
echo s2idle > /sys/power/mem_sleep 2>/dev/null || true

# ============================================================================
# SUSPEND/RESUME PHASE: Execute suspend cycle with RTC wakeup using cron job
# ============================================================================

# Save state for monitoring and validation
echo "$INITIAL_SUSPEND_COUNT" > /tmp/suspend_initial_count
echo "$test_path" > /tmp/suspend_test_path
LOG_FILE="$test_path/suspend_monitor.log"
> "$LOG_FILE"  # Clear log file

log_info "Setting up continuous monitoring via background loop..."

# Create monitoring script that polls system stats continuously in a loop
cat > /tmp/suspend_monitor.sh << 'EOF'
#!/bin/sh
# Continuous monitoring script - runs in background loop

SUSPEND_STATS_PATH="/sys/power/suspend_stats/success"
TEST_PATH=$(cat /tmp/suspend_test_path 2>/dev/null)
LOG_FILE="$TEST_PATH/suspend_monitor.log"

# Monitor for up to 60 seconds (covers suspend + resume + buffer)
END_TIME=$(($(date +%s) + 60))

while [ $(date +%s) -lt $END_TIME ]; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Collect current stats
    CURRENT_COUNT=$(cat "$SUSPEND_STATS_PATH" 2>/dev/null || echo "0")
    FAIL_COUNT=$(cat /sys/power/suspend_stats/fail 2>/dev/null || echo "0")
    LAST_FAILED_DEV=$(cat /sys/power/suspend_stats/last_failed_dev 2>/dev/null || echo "none")
    LAST_FAILED_ERRNO=$(cat /sys/power/suspend_stats/last_failed_errno 2>/dev/null || echo "0")
    
    # Log the stats
    echo "[$TIMESTAMP] Suspend Success: $CURRENT_COUNT | Fail: $FAIL_COUNT | Last Failed Dev: $LAST_FAILED_DEV | Errno: $LAST_FAILED_ERRNO" >> "$LOG_FILE"
    
    # Also collect qcom stats if available
    if [ -r /sys/kernel/debug/qcom_stats/ddr ]; then
        DDR_STATS=$(cat /sys/kernel/debug/qcom_stats/ddr 2>/dev/null | head -n 3)
        echo "[$TIMESTAMP] DDR Stats: $DDR_STATS" >> "$LOG_FILE"
    fi
    
    # Poll every 5 seconds
    sleep 5
done
EOF

chmod +x /tmp/suspend_monitor.sh

# Create validation script that runs after expected resume time
cat > /tmp/validate_suspend_resume.sh << 'EOF'
#!/bin/sh
# Post-resume validation script

# Wait for system to stabilize after resume
sleep 5

SUSPEND_STATS_PATH="/sys/power/suspend_stats/success"
INITIAL_COUNT=$(cat /tmp/suspend_initial_count 2>/dev/null || echo "0")
TEST_PATH=$(cat /tmp/suspend_test_path 2>/dev/null)
RES_FILE="$TEST_PATH/SuspendResume.res"
LOG_FILE="$TEST_PATH/suspend_monitor.log"
RESULT_DISPLAY="$TEST_PATH/RESULT_DISPLAY.txt"

# Get current suspend count
CURRENT_COUNT=$(cat "$SUSPEND_STATS_PATH" 2>/dev/null || echo "0")

# Log final validation
echo "[VALIDATION] Initial count: $INITIAL_COUNT, Current count: $CURRENT_COUNT" >> "$LOG_FILE"

# Capture dmesg for validation
OUTPUT=$(dmesg | tail -n 200)

# Function to display result prominently
display_result() {
    RESULT_MSG="$1"
    RESULT_STATUS="$2"
    
    # Create prominent result display file
    cat > "$RESULT_DISPLAY" << DISPLAY_EOF
                    SUSPEND/RESUME TEST RESULT

Status: $RESULT_STATUS

$RESULT_MSG

Time: $(date '+%Y-%m-%d %H:%M:%S')

To view detailed logs:
  cat $LOG_FILE

To view result file:
  cat $RES_FILE

DISPLAY_EOF

    # Also log to system log
    logger -t SuspendResume "$RESULT_STATUS - $RESULT_MSG"
    
    # Display on all active terminals (best effort)
    for tty in /dev/pts/* /dev/tty[0-9]*; do
        if [ -w "$tty" ] 2>/dev/null; then
            cat "$RESULT_DISPLAY" > "$tty" 2>/dev/null || true
        fi
    done
}

# Validation Check 1: Verify suspend count incremented
if [ "$CURRENT_COUNT" -le "$INITIAL_COUNT" ]; then
    echo "[VALIDATION] FAIL - Suspend count did not increment" >> "$LOG_FILE"
    echo "SuspendResume FAIL - Suspend count did not increment (Initial: $INITIAL_COUNT, Current: $CURRENT_COUNT)" > "$RES_FILE"
    display_result "Suspend count did not increment (Initial: $INITIAL_COUNT, Current: $CURRENT_COUNT)" "FAIL"
    rm -f /tmp/suspend_initial_count /tmp/suspend_test_path /tmp/suspend_monitor.sh /tmp/validate_suspend_resume.sh
    exit 1
fi

# Validation Check 2: Verify suspend entry markers in dmesg
if ! echo "$OUTPUT" | grep -q "PM: suspend entry\|Freezing user space processes"; then
    echo "[VALIDATION] FAIL - No suspend entry markers in dmesg" >> "$LOG_FILE"
    echo "SuspendResume FAIL - No suspend entry markers found in dmesg" > "$RES_FILE"
    display_result "No suspend entry markers found in dmesg" "FAIL"
    rm -f /tmp/suspend_initial_count /tmp/suspend_test_path /tmp/suspend_monitor.sh /tmp/validate_suspend_resume.sh
    exit 1
fi

# Validation Check 3: Verify resume markers in dmesg
if ! echo "$OUTPUT" | grep -q "PM: suspend exit\|Restarting tasks"; then
    echo "[VALIDATION] FAIL - No resume markers in dmesg" >> "$LOG_FILE"
    echo "SuspendResume FAIL - No resume markers found in dmesg" > "$RES_FILE"
    display_result "No resume markers found in dmesg" "FAIL"
    rm -f /tmp/suspend_initial_count /tmp/suspend_test_path /tmp/suspend_monitor.sh /tmp/validate_suspend_resume.sh
    exit 1
fi

# All validations passed
echo "[VALIDATION] PASS - All checks passed" >> "$LOG_FILE"
echo "SuspendResume PASS - Suspend count: $INITIAL_COUNT -> $CURRENT_COUNT" > "$RES_FILE"
display_result "All validation checks passed! Suspend count: $INITIAL_COUNT -> $CURRENT_COUNT" "PASS"

# Collect final debug stats
echo "" >> "$LOG_FILE"
echo "=== Final System Stats ===" >> "$LOG_FILE"
cat /sys/kernel/debug/suspend_stats 2>/dev/null >> "$LOG_FILE" || true
cat /sys/kernel/debug/qcom_stats/aosd 2>/dev/null >> "$LOG_FILE" || true
cat /sys/kernel/debug/qcom_stats/adsp 2>/dev/null >> "$LOG_FILE" || true
cat /sys/kernel/debug/qcom_stats/cdsp 2>/dev/null >> "$LOG_FILE" || true
cat /sys/kernel/debug/qcom_stats/ddr 2>/dev/null >> "$LOG_FILE" || true

# Cleanup temp files
rm -f /tmp/suspend_initial_count /tmp/suspend_test_path /tmp/suspend_monitor.sh /tmp/validate_suspend_resume.sh
EOF

chmod +x /tmp/validate_suspend_resume.sh

# Start monitoring script in background with nohup
log_info "Starting continuous monitoring in background..."
nohup /tmp/suspend_monitor.sh >/dev/null 2>&1 &
MONITOR_PID=$!

log_info "Monitoring started (PID: $MONITOR_PID). Will monitor for 60 seconds."
log_info "Monitor log: $LOG_FILE"

# Schedule validation to run after expected resume (45 seconds from now)
# This accounts for 30s suspend + 15s buffer for resume and stabilization
nohup sh -c "sleep 45 && /tmp/validate_suspend_resume.sh" >/dev/null 2>&1 &

log_info "Scheduling suspend command to execute in 5 seconds..."
log_info "Command: rtcwake -d /dev/rtc0 -m no -s 30 && systemctl suspend"
log_info "System will suspend for 30 seconds then automatically resume"

# Schedule suspend command to run in 5 seconds (gives time for cron to start)
nohup sh -c "sleep 5 && rtcwake -d /dev/rtc0 -m no -s 30 && systemctl suspend" >/dev/null 2>&1 &

log_info ""
log_info "============================================================"
log_info "Suspend/Resume test initiated successfully"
log_info "============================================================"
log_info "The shell will disconnect when suspend occurs."
log_info "After ~40 seconds, reconnect and the result will be displayed."
log_info ""
log_info "To check results manually:"
log_info "  - Result file: $res_file"
log_info "  - Monitor log: $LOG_FILE"
log_info "  - Result display: $test_path/RESULT_DISPLAY.txt"
log_info ""
log_info "Or simply run: cat $test_path/RESULT_DISPLAY.txt"
log_info "============================================================"
log_info ""

# Exit cleanly so user can reconnect later to check results
exit 0
