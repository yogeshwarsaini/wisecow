#!/bin/bash
# ============================================================
# Application Health Checker (Bash Version)
# Checks HTTP status of apps and reports UP/DOWN
#
# Usage:
#   chmod +x app_health_checker.sh
#   ./app_health_checker.sh
#   ./app_health_checker.sh --interval 60
# ============================================================

# ─────────────────────────────────────────────
# CONFIGURATION - Add your app URLs below
# Format: "App Name|http://url"
# ─────────────────────────────────────────────
declare -a APPS=(
    "Wisecow App|http://localhost:4499"
    "Google|https://www.google.com"
    "Example API|https://httpbin.org/status/200"
    "Broken App (test)|https://httpbin.org/status/503"
)

TIMEOUT=10
LOG_FILE="app_health.log"
INTERVAL=0

# ─────────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─────────────────────────────────────────────
# LOG FUNCTION
# ─────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"

    echo "$log_line" >> "$LOG_FILE"

    case "$level" in
        ALERT)   echo -e "${RED}${log_line}${NC}" ;;
        WARNING) echo -e "${YELLOW}${log_line}${NC}" ;;
        INFO)    echo -e "${GREEN}${log_line}${NC}" ;;
        HEADER)  echo -e "${BLUE}${log_line}${NC}" ;;
        *)       echo "$log_line" ;;
    esac
}

# ─────────────────────────────────────────────
# CHECK SINGLE APP
# ─────────────────────────────────────────────
check_app() {
    local name="$1"
    local url="$2"
    local http_code response_time

    # curl: -o /dev/null = discard body
    #       -s = silent, -w = write-out format
    #       --connect-timeout = timeout in seconds
    local result
    result=$(curl -o /dev/null -s -w "%{http_code}|%{time_total}" \
             --connect-timeout "$TIMEOUT" \
             --max-time "$TIMEOUT" \
             "$url" 2>&1)

    if [ $? -ne 0 ]; then
        log "ALERT" "🔴 DOWN | ${name} | CONNECTION ERROR | ${url}"
        return 1
    fi

    http_code=$(echo "$result" | cut -d'|' -f1)
    response_time=$(echo "$result" | cut -d'|' -f2)
    response_ms=$(awk "BEGIN {printf \"%.0f\", $response_time * 1000}")

    # Check if HTTP code is healthy (200-399)
    if [[ "$http_code" =~ ^[23][0-9]{2}$ ]]; then
        log "INFO" "✅ UP   | ${name} | HTTP ${http_code} | ${response_ms}ms | ${url}"
        echo "UP"
    else
        log "ALERT" "🔴 DOWN | ${name} | HTTP ${http_code} | ${response_ms}ms | ${url}"
        echo "DOWN"
    fi
}

# ─────────────────────────────────────────────
# RUN ALL HEALTH CHECKS
# ─────────────────────────────────────────────
run_health_checks() {
    log "HEADER" "======================================================================"
    log "HEADER" "🔍 APPLICATION HEALTH CHECK — $(date '+%Y-%m-%d %H:%M:%S')"
    log "HEADER" "======================================================================"

    local up_count=0
    local down_count=0

    for app_entry in "${APPS[@]}"; do
        local name url status
        name=$(echo "$app_entry" | cut -d'|' -f1)
        url=$(echo "$app_entry" | cut -d'|' -f2)

        status=$(check_app "$name" "$url")

        if [ "$status" = "UP" ]; then
            up_count=$((up_count + 1))
        else
            down_count=$((down_count + 1))
        fi
    done

    log "HEADER" "----------------------------------------------------------------------"
    log "INFO"   "📊 SUMMARY: ${up_count} UP ✅  |  ${down_count} DOWN 🔴  |  Total: ${#APPS[@]}"
    log "INFO"   "📝 Log saved to: ${LOG_FILE}"
    log "HEADER" "======================================================================"
}

# ─────────────────────────────────────────────
# PARSE ARGUMENTS
# ─────────────────────────────────────────────
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
    shift
done

# ─────────────────────────────────────────────
# EXECUTE
# ─────────────────────────────────────────────
if [ "$INTERVAL" -gt 0 ]; then
    echo "🔄 Checking every ${INTERVAL}s. Press Ctrl+C to stop."
    while true; do
        run_health_checks
        sleep "$INTERVAL"
    done
else
    run_health_checks
fi
