#!/bin/bash
# ============================================================
# System Health Monitoring Script (Bash Version)
# Monitors CPU, Memory, Disk, Processes
# Sends alerts to console + log file
#
# Usage:
#   chmod +x system_health.sh
#   ./system_health.sh
#   ./system_health.sh --interval 30    # Run every 30 seconds
# ============================================================

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=90
PROCESS_THRESHOLD=300
LOG_FILE="system_health.log"
INTERVAL=0   # 0 = run once; set via --interval flag

# ─────────────────────────────────────────────
# COLORS for terminal output
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'   # No Color

# ─────────────────────────────────────────────
# LOGGING FUNCTION
# ─────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"

    # Write to log file (no color)
    echo "$log_line" >> "$LOG_FILE"

    # Print to console (with color)
    case "$level" in
        ALERT)   echo -e "${RED}$log_line${NC}" ;;
        WARNING) echo -e "${YELLOW}$log_line${NC}" ;;
        *)       echo -e "${GREEN}$log_line${NC}" ;;
    esac
}

# ─────────────────────────────────────────────
# CHECK CPU
# ─────────────────────────────────────────────
check_cpu() {
    # Get CPU idle % and calculate usage
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    local cpu_usage=$((100 - cpu_idle))

    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        log "ALERT" "🔴 CPU ALERT: ${cpu_usage}% usage (threshold: ${CPU_THRESHOLD}%)"
    else
        log "INFO" "✅ CPU Usage: ${cpu_usage}%"
    fi
}

# ─────────────────────────────────────────────
# CHECK MEMORY
# ─────────────────────────────────────────────
check_memory() {
    local total used free mem_percent
    total=$(free -m | awk '/^Mem:/{print $2}')
    used=$(free -m | awk '/^Mem:/{print $3}')
    mem_percent=$(awk "BEGIN {printf \"%.0f\", ($used/$total)*100}")

    if [ "$mem_percent" -gt "$MEMORY_THRESHOLD" ]; then
        log "ALERT" "🔴 MEMORY ALERT: ${mem_percent}% used (${used}MB / ${total}MB) (threshold: ${MEMORY_THRESHOLD}%)"
    else
        log "INFO" "✅ Memory Usage: ${mem_percent}% (${used}MB / ${total}MB)"
    fi
}

# ─────────────────────────────────────────────
# CHECK DISK
# ─────────────────────────────────────────────
check_disk() {
    # Loop through all mounted filesystems
    df -H | grep -vE '^Filesystem|tmpfs|cdrom|udev' | while read -r line; do
        local disk_percent mount
        disk_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        mount=$(echo "$line" | awk '{print $6}')

        if [ "$disk_percent" -gt "$DISK_THRESHOLD" ]; then
            log "ALERT" "🔴 DISK ALERT: ${mount} is ${disk_percent}% full (threshold: ${DISK_THRESHOLD}%)"
        else
            log "INFO" "✅ Disk [${mount}]: ${disk_percent}% used"
        fi
    done
}

# ─────────────────────────────────────────────
# CHECK PROCESSES
# ─────────────────────────────────────────────
check_processes() {
    local proc_count
    proc_count=$(ps aux | wc -l)
    proc_count=$((proc_count - 1))   # Remove header line

    if [ "$proc_count" -gt "$PROCESS_THRESHOLD" ]; then
        log "ALERT" "🔴 PROCESS ALERT: ${proc_count} processes running (threshold: ${PROCESS_THRESHOLD})"
    else
        log "INFO" "✅ Running Processes: ${proc_count}"
    fi

    # Top 5 CPU-consuming processes
    log "INFO" "📊 Top 5 CPU processes:"
    ps aux --sort=-%cpu | head -6 | tail -5 | while read -r line; do
        local pid name cpu mem
        pid=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | awk '{print $11}')
        cpu=$(echo "$line" | awk '{print $3}')
        mem=$(echo "$line" | awk '{print $4}')
        log "INFO" "   PID ${pid}: ${name} — CPU: ${cpu}%, MEM: ${mem}%"
    done
}

# ─────────────────────────────────────────────
# MAIN HEALTH CHECK FUNCTION
# ─────────────────────────────────────────────
run_health_check() {
    log "INFO" "============================================================"
    log "INFO" "🏥 SYSTEM HEALTH CHECK — $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "============================================================"

    check_cpu
    check_memory
    check_disk
    check_processes

    log "INFO" "------------------------------------------------------------"
    log "INFO" "📝 Log saved to: $LOG_FILE"
    log "INFO" "============================================================"
}

# ─────────────────────────────────────────────
# PARSE ARGUMENTS
# ─────────────────────────────────────────────
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# ─────────────────────────────────────────────
# RUN
# ─────────────────────────────────────────────
if [ "$INTERVAL" -gt 0 ]; then
    echo "🔄 Running health check every ${INTERVAL} seconds. Press Ctrl+C to stop."
    while true; do
        run_health_check
        sleep "$INTERVAL"
    done
else
    run_health_check
fi
