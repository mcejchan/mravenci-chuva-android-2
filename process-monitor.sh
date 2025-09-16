#!/bin/bash
# Process Monitor Utility
# Manages and monitors processes started by monitoring-wrapper.sh
set -euo pipefail

LOG_DIR="${LOG_DIR:-/tmp/monitoring-logs}"
mkdir -p "$LOG_DIR"

usage() {
    cat <<EOF
Usage: $0 COMMAND [OPTIONS]

COMMANDS:
    list            List all monitored processes
    status NAME     Show status of specific process
    logs NAME       Show logs for specific process
    kill NAME       Kill specific process
    cleanup         Clean up completed/failed processes
    watch [NAME]    Watch process progress (all or specific)

OPTIONS:
    -f, --follow    Follow logs in real-time (for logs command)
    -n, --lines N   Show last N lines (for logs command, default: 50)
    --all           Include completed processes (for list command)

EXAMPLES:
    $0 list                    # List active processes
    $0 list --all             # List all processes
    $0 status bundled-build   # Show status of bundled-build process
    $0 logs gradle-clean -f   # Follow logs for gradle-clean
    $0 watch                  # Watch all processes
    $0 watch bundled-build    # Watch specific process
    $0 kill bundled-build     # Kill bundled-build process
    $0 cleanup                # Clean up old process files
EOF
}

# Find processes by pattern
find_processes() {
    local pattern="$1"
    local include_completed="${2:-false}"

    if [[ "$include_completed" == "true" ]]; then
        find "$LOG_DIR" -name "${pattern}*.status" 2>/dev/null | sort
    else
        find "$LOG_DIR" -name "${pattern}*.status" 2>/dev/null | \
        while read -r status_file; do
            local status=$(cat "$status_file" 2>/dev/null || echo "unknown")
            if [[ "$status" == "running" ]]; then
                echo "$status_file"
            fi
        done
    fi
}

# Get process info from status file
get_process_info() {
    local status_file="$1"
    local basename=$(basename "$status_file" .status)
    local process_name=$(echo "$basename" | cut -d'-' -f1)
    local start_time=$(echo "$basename" | cut -d'-' -f2)
    local process_id=$(echo "$basename" | cut -d'-' -f3)
    local status=$(cat "$status_file" 2>/dev/null || echo "unknown")
    local pid_file="$LOG_DIR/${basename}.pid"
    local log_file="$LOG_DIR/${basename}.log"

    local pid=""
    local running="No"
    if [[ -f "$pid_file" ]]; then
        pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            running="Yes"
        fi
    fi

    local duration="N/A"
    if [[ "$start_time" =~ ^[0-9]+$ ]]; then
        local current_time=$(date +%s)
        duration="${$((current_time - start_time))}s"
    fi

    echo "$process_name|$status|$running|$duration|$pid|$log_file|$basename"
}

# List processes
cmd_list() {
    local include_completed="false"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                include_completed="true"
                shift
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                exit 1
                ;;
        esac
    done

    local status_files
    status_files=$(find_processes "*" "$include_completed")

    if [[ -z "$status_files" ]]; then
        echo "No monitored processes found."
        return 0
    fi

    echo "📊 Monitored Processes:"
    printf "%-15s %-10s %-8s %-10s %-8s %s\n" "NAME" "STATUS" "RUNNING" "DURATION" "PID" "LOG_FILE"
    printf "%-15s %-10s %-8s %-10s %-8s %s\n" "----" "------" "-------" "--------" "---" "--------"

    echo "$status_files" | while read -r status_file; do
        if [[ -n "$status_file" ]]; then
            local info
            info=$(get_process_info "$status_file")
            IFS='|' read -r name status running duration pid log_file basename <<< "$info"
            printf "%-15s %-10s %-8s %-10s %-8s %s\n" "$name" "$status" "$running" "$duration" "$pid" "$log_file"
        fi
    done
}

# Show process status
cmd_status() {
    local process_name="$1"
    local status_files
    status_files=$(find_processes "$process_name" "true")

    if [[ -z "$status_files" ]]; then
        echo "No process found matching: $process_name"
        return 1
    fi

    # Get the most recent process if multiple matches
    local latest_status_file
    latest_status_file=$(echo "$status_files" | tail -1)

    local info
    info=$(get_process_info "$latest_status_file")
    IFS='|' read -r name status running duration pid log_file basename <<< "$info"

    echo "📋 Process Status: $name"
    echo "   • ID: $basename"
    echo "   • Status: $status"
    echo "   • Running: $running"
    echo "   • Duration: $duration"
    echo "   • PID: ${pid:-N/A}"
    echo "   • Log File: $log_file"

    # Show memory usage if running
    if [[ "$running" == "Yes" && -n "$pid" ]]; then
        local mem_info
        mem_info=$(ps -o pid,vsz,rss,pcpu --no-headers -p "$pid" 2>/dev/null || echo "")
        if [[ -n "$mem_info" ]]; then
            echo "   • Memory: $(echo "$mem_info" | awk '{printf "VSZ:%dKB RSS:%dKB CPU:%.1f%%", $2, $3, $4}')"
        fi
    fi

    # Show recent log lines
    if [[ -f "$log_file" ]]; then
        echo ""
        echo "📄 Recent Log (last 5 lines):"
        tail -5 "$log_file" | sed 's/^/   | /'
    fi
}

# Show logs
cmd_logs() {
    local process_name="$1"
    local follow="false"
    local lines="50"

    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow="true"
                shift
                ;;
            -n|--lines)
                lines="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                exit 1
                ;;
        esac
    done

    local status_files
    status_files=$(find_processes "$process_name" "true")

    if [[ -z "$status_files" ]]; then
        echo "No process found matching: $process_name"
        return 1
    fi

    # Get the most recent process if multiple matches
    local latest_status_file
    latest_status_file=$(echo "$status_files" | tail -1)

    local info
    info=$(get_process_info "$latest_status_file")
    IFS='|' read -r name status running duration pid log_file basename <<< "$info"

    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi

    echo "📄 Logs for $name ($basename):"
    echo ""

    if [[ "$follow" == "true" ]]; then
        tail -f "$log_file"
    else
        tail -"$lines" "$log_file"
    fi
}

# Kill process
cmd_kill() {
    local process_name="$1"
    local status_files
    status_files=$(find_processes "$process_name" "false")

    if [[ -z "$status_files" ]]; then
        echo "No running process found matching: $process_name"
        return 1
    fi

    # Get the most recent running process if multiple matches
    local latest_status_file
    latest_status_file=$(echo "$status_files" | tail -1)

    local info
    info=$(get_process_info "$latest_status_file")
    IFS='|' read -r name status running duration pid log_file basename <<< "$info"

    if [[ "$running" != "Yes" || -z "$pid" ]]; then
        echo "Process $name is not running (status: $status)"
        return 1
    fi

    echo "🔪 Killing process $name (PID: $pid)..."

    # Try graceful termination first
    if kill -TERM "$pid" 2>/dev/null; then
        echo "   Sent TERM signal, waiting for graceful shutdown..."
        sleep 5

        # Check if still running
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Process still running, sending KILL signal..."
            kill -KILL "$pid" 2>/dev/null || true
        fi

        echo "   Process killed successfully"
        echo "killed" > "${LOG_DIR}/${basename}.status"
    else
        echo "   Failed to kill process (may have already terminated)"
    fi
}

# Watch processes
cmd_watch() {
    local process_pattern="${1:-*}"

    echo "👀 Watching processes matching: $process_pattern"
    echo "   Press Ctrl+C to stop watching"
    echo ""

    while true; do
        clear
        echo "🕐 $(date)"
        echo ""
        cmd_list --all | grep -E "(NAME|$process_pattern)" || echo "No processes found matching: $process_pattern"
        echo ""
        echo "📊 System Memory:"
        free -h | grep -E "(total|Mem)" | sed 's/^/   /'
        echo ""
        sleep 5
    done
}

# Cleanup old processes
cmd_cleanup() {
    echo "🧹 Cleaning up completed/failed processes..."

    local cleaned_count=0
    find "$LOG_DIR" -name "*.status" 2>/dev/null | while read -r status_file; do
        local status=$(cat "$status_file" 2>/dev/null || echo "unknown")
        local basename=$(basename "$status_file" .status)

        if [[ "$status" != "running" ]]; then
            # Remove associated files
            rm -f "$LOG_DIR/${basename}.status"
            rm -f "$LOG_DIR/${basename}.pid"
            # Keep log files for now - they might be useful
            echo "   Cleaned up: $basename (status: $status)"
            ((cleaned_count++)) || true
        fi
    done

    echo "✅ Cleanup complete. Removed $cleaned_count process entries."
    echo "   Log files preserved for review."
}

# Main command dispatch
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    list)
        cmd_list "$@"
        ;;
    status)
        if [[ $# -eq 0 ]]; then
            echo "Error: Process name required for status command" >&2
            exit 1
        fi
        cmd_status "$@"
        ;;
    logs)
        if [[ $# -eq 0 ]]; then
            echo "Error: Process name required for logs command" >&2
            exit 1
        fi
        cmd_logs "$@"
        ;;
    kill)
        if [[ $# -eq 0 ]]; then
            echo "Error: Process name required for kill command" >&2
            exit 1
        fi
        cmd_kill "$@"
        ;;
    watch)
        cmd_watch "$@"
        ;;
    cleanup)
        cmd_cleanup
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Error: Unknown command: $COMMAND" >&2
        usage >&2
        exit 1
        ;;
esac