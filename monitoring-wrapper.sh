#!/bin/bash
# Monitoring Wrapper Script
# Provides progress monitoring and proper cleanup for long-running commands
set -euo pipefail

# Configuration
PROGRESS_INTERVAL=${PROGRESS_INTERVAL:-30}  # Progress report every 30 seconds
COMPLETION_CHECK_INTERVAL=${COMPLETION_CHECK_INTERVAL:-10}  # Check completion every 10 seconds
MAX_RUNTIME=${MAX_RUNTIME:-3600}  # Max 1 hour runtime
LOG_DIR="/tmp/monitoring-logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Usage function
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] -- COMMAND [ARGS...]

OPTIONS:
    -n, --name NAME         Process name for logging (required)
    -i, --interval SECONDS  Progress report interval (default: 30)
    -c, --check SECONDS     Completion check interval (default: 10)
    -t, --timeout SECONDS   Maximum runtime (default: 3600)
    -l, --log-dir PATH      Log directory (default: /tmp/monitoring-logs)
    -h, --help             Show this help

EXAMPLES:
    $0 -n "bundled-build" -- ./expert-bundled-build.sh
    $0 -n "gradle-clean" -t 1800 -- ./gradlew clean
    $0 -n "long-task" -i 60 -c 30 -- some-long-command

FEATURES:
    • Progress reports with timestamps and memory usage
    • Process completion detection with exit code capture
    • Automatic cleanup of zombie processes
    • Structured logging with process registry
    • Timeout protection against runaway processes
EOF
}

# Parse arguments
PROCESS_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            PROCESS_NAME="$2"
            shift 2
            ;;
        -i|--interval)
            PROGRESS_INTERVAL="$2"
            shift 2
            ;;
        -c|--check)
            COMPLETION_CHECK_INTERVAL="$2"
            shift 2
            ;;
        -t|--timeout)
            MAX_RUNTIME="$2"
            shift 2
            ;;
        -l|--log-dir)
            LOG_DIR="$2"
            mkdir -p "$LOG_DIR"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PROCESS_NAME" ]]; then
    echo "Error: Process name is required (-n/--name)" >&2
    usage >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Error: Command is required after --" >&2
    usage >&2
    exit 1
fi

# Generate unique process ID
PROCESS_ID="${PROCESS_NAME}-$(date +%s)-$$"
LOG_FILE="$LOG_DIR/${PROCESS_ID}.log"
PID_FILE="$LOG_DIR/${PROCESS_ID}.pid"
STATUS_FILE="$LOG_DIR/${PROCESS_ID}.status"

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up monitoring for $PROCESS_ID"

    # Kill background monitoring jobs
    jobs -p | xargs -r kill 2>/dev/null || true

    # Update final status
    if [[ -f "$STATUS_FILE" ]]; then
        local status=$(cat "$STATUS_FILE" 2>/dev/null || echo "unknown")
        if [[ "$status" == "running" ]]; then
            echo "interrupted" > "$STATUS_FILE"
        fi
    fi

    # Clean up PID file
    rm -f "$PID_FILE"

    echo "🔚 Monitoring cleanup complete for $PROCESS_ID"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Progress monitoring function
monitor_progress() {
    local start_time=$(date +%s)
    local last_report=0

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        # Check if process is still running
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
                echo "🔍 Process $pid completed - stopping monitor" >> "$LOG_FILE"
                break
            fi
        else
            echo "🔍 PID file missing - process may have completed" >> "$LOG_FILE"
            break
        fi

        # Check timeout
        if [[ $elapsed -gt $MAX_RUNTIME ]]; then
            echo "⏰ Process timed out after ${MAX_RUNTIME}s - terminating" >> "$LOG_FILE"
            if [[ -f "$PID_FILE" ]]; then
                local pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
                if [[ -n "$pid" ]]; then
                    echo "timeout" > "$STATUS_FILE"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 5
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
            break
        fi

        # Progress report
        if [[ $((elapsed - last_report)) -ge $PROGRESS_INTERVAL ]]; then
            local mem_info=$(free -h | grep Mem | awk '{printf "Used: %s/%s", $3, $2}')
            local report="🕐 ${PROCESS_NAME} progress: ${elapsed}s elapsed | Memory: ${mem_info}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') $report" >> "$LOG_FILE"
            echo "$report"
            last_report=$elapsed
        fi

        sleep "$COMPLETION_CHECK_INTERVAL"
    done

    echo "🏁 Progress monitoring finished for $PROCESS_ID" >> "$LOG_FILE"
}

# Main execution
echo "🚀 Starting monitored process: $PROCESS_NAME"
echo "📝 Process ID: $PROCESS_ID"
echo "📄 Log file: $LOG_FILE"
echo "⏱️  Progress reports every ${PROGRESS_INTERVAL}s"
echo "🔍 Completion checks every ${COMPLETION_CHECK_INTERVAL}s"
echo "⏰ Timeout after ${MAX_RUNTIME}s"
echo ""

# Initialize status
echo "running" > "$STATUS_FILE"

# Start the command in background and capture PID
echo "🔧 Executing: $*"
"$@" > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2) &
COMMAND_PID=$!

# Save PID
echo "$COMMAND_PID" > "$PID_FILE"

# Start progress monitoring in background
monitor_progress &
MONITOR_PID=$!

echo "📊 Background monitoring started (monitor PID: $MONITOR_PID, command PID: $COMMAND_PID)"
echo ""

# Wait for command completion
set +e
wait "$COMMAND_PID"
COMMAND_EXIT_CODE=$?
set -e

# Update status with exit code
if [[ $COMMAND_EXIT_CODE -eq 0 ]]; then
    echo "success" > "$STATUS_FILE"
    echo "✅ Process completed successfully (exit code: $COMMAND_EXIT_CODE)"
else
    echo "failed" > "$STATUS_FILE"
    echo "❌ Process failed (exit code: $COMMAND_EXIT_CODE)"
fi

# Stop progress monitoring
kill "$MONITOR_PID" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true

# Final report
local end_time=$(date +%s)
local start_time_from_pid=$(echo "$PROCESS_ID" | cut -d'-' -f2)
local total_duration=$((end_time - start_time_from_pid))

echo ""
echo "📊 Final Report for $PROCESS_NAME:"
echo "   • Process ID: $PROCESS_ID"
echo "   • Total Duration: ${total_duration}s"
echo "   • Exit Code: $COMMAND_EXIT_CODE"
echo "   • Status: $(cat "$STATUS_FILE")"
echo "   • Log File: $LOG_FILE"
echo ""

# Exit with same code as original command
exit $COMMAND_EXIT_CODE