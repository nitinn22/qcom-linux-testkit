#!/bin/sh

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Automated wrapper for suspend/resume test that waits and displays results

echo "================================================================================"
echo "                  AUTOMATED SUSPEND/RESUME TEST"
echo "================================================================================"
echo ""
echo "This script will:"
echo "  1. Run the suspend/resume test"
echo "  2. Wait for the test to complete (~50 seconds)"
echo "  3. Automatically display the results"
echo ""
echo "Note: The shell connection will drop during suspend. This is expected."
echo "      The script will automatically reconnect and show results."
echo ""
echo "================================================================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Clean up old result files to ensure we wait for new results
echo "[$(date '+%H:%M:%S')] Cleaning up old result files..."
rm -f "$SCRIPT_DIR/SuspendResume.res" "$SCRIPT_DIR/RESULT_DISPLAY.txt" "$SCRIPT_DIR/suspend_monitor.log"

# Run the actual test script
echo "[$(date '+%H:%M:%S')] Starting suspend/resume test..."
sh "$SCRIPT_DIR/run_shell.sh"

# The test script exits immediately, but the actual test runs in background
# We need to wait for the test to complete

echo ""
echo "[$(date '+%H:%M:%S')] Test initiated. Waiting for completion..."
echo "[$(date '+%H:%M:%S')] System will suspend in ~5 seconds..."
echo "[$(date '+%H:%M:%S')] Expected completion time: ~50 seconds from now"
echo ""

# Wait for the test to complete (50 seconds total: 5s delay + 30s suspend + 15s validation)
WAIT_TIME=50
for i in $(seq 1 $WAIT_TIME); do
    # Check if result file exists and has content
    if [ -f "$SCRIPT_DIR/SuspendResume.res" ] && [ -s "$SCRIPT_DIR/SuspendResume.res" ]; then
        # Only show "completed early" if it finished before expected time (< 40 seconds)
        if [ $i -lt 40 ]; then
            echo "[$(date '+%H:%M:%S')] Test completed early! (after $i seconds)"
        else
            echo "[$(date '+%H:%M:%S')] Test completed successfully (after $i seconds)"
        fi
        break
    fi
    
    # Show progress every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] Still waiting... ($i/$WAIT_TIME seconds elapsed)"
    fi
    
    sleep 1
done

echo ""
echo "================================================================================"
echo "                           TEST RESULTS"
echo "================================================================================"
echo ""

# Display the result
if [ -f "$SCRIPT_DIR/RESULT_DISPLAY.txt" ]; then
    cat "$SCRIPT_DIR/RESULT_DISPLAY.txt"
else
    echo "WARNING: Result display file not found!"
    echo ""
    if [ -f "$SCRIPT_DIR/SuspendResume.res" ]; then
        echo "Result from SuspendResume.res:"
        cat "$SCRIPT_DIR/SuspendResume.res"
    else
        echo "ERROR: No result files found. Test may have failed to complete."
    fi
fi

echo ""
echo "================================================================================"
echo "                        DETAILED MONITORING LOG"
echo "================================================================================"
echo ""

if [ -f "$SCRIPT_DIR/suspend_monitor.log" ]; then
    cat "$SCRIPT_DIR/suspend_monitor.log"
else
    echo "WARNING: Monitoring log not found!"
fi

echo ""
echo "================================================================================"
echo "                              SUMMARY"
echo "================================================================================"
echo ""

# Extract and display final result
if [ -f "$SCRIPT_DIR/SuspendResume.res" ]; then
    RESULT=$(cat "$SCRIPT_DIR/SuspendResume.res")
    if echo "$RESULT" | grep -q "PASS"; then
        echo "✓ TEST PASSED"
        echo ""
        echo "Result: $RESULT"
        exit 0
    else
        echo "✗ TEST FAILED"
        echo ""
        echo "Result: $RESULT"
        exit 1
    fi
else
    echo "✗ TEST INCOMPLETE - No result file found"
    exit 1
fi
