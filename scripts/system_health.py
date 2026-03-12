#!/usr/bin/env python3
"""
System Health Monitoring Script
================================
Monitors CPU, Memory, Disk, and Running Processes.
Sends alert to console and log file if thresholds exceeded.

Usage:
    python3 system_health.py
    python3 system_health.py --interval 30   # check every 30 seconds
"""

import psutil
import logging
import argparse
import time
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION - Change thresholds here
# ─────────────────────────────────────────────
THRESHOLDS = {
    "cpu_percent": 80,       # Alert if CPU usage > 80%
    "memory_percent": 80,    # Alert if RAM usage > 80%
    "disk_percent": 90,      # Alert if Disk usage > 90%
    "max_processes": 300,    # Alert if running processes > 300
}

LOG_FILE = "system_health.log"

# ─────────────────────────────────────────────
# LOGGING SETUP - writes to both console + file
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),   # Save to file
        logging.StreamHandler()           # Print to console
    ]
)
logger = logging.getLogger(__name__)


def check_cpu():
    """Check CPU usage and alert if above threshold."""
    cpu = psutil.cpu_percent(interval=1)
    status = "OK" if cpu < THRESHOLDS["cpu_percent"] else "ALERT"
    
    if status == "ALERT":
        logger.warning(f"🔴 CPU ALERT: {cpu}% usage (threshold: {THRESHOLDS['cpu_percent']}%)")
    else:
        logger.info(f"✅ CPU Usage: {cpu}%")
    
    return {"metric": "CPU", "value": cpu, "status": status}


def check_memory():
    """Check RAM usage and alert if above threshold."""
    mem = psutil.virtual_memory()
    used_percent = mem.percent
    used_gb = mem.used / (1024 ** 3)
    total_gb = mem.total / (1024 ** 3)
    
    status = "OK" if used_percent < THRESHOLDS["memory_percent"] else "ALERT"
    
    if status == "ALERT":
        logger.warning(
            f"🔴 MEMORY ALERT: {used_percent}% used "
            f"({used_gb:.2f}GB / {total_gb:.2f}GB) "
            f"(threshold: {THRESHOLDS['memory_percent']}%)"
        )
    else:
        logger.info(f"✅ Memory Usage: {used_percent}% ({used_gb:.2f}GB / {total_gb:.2f}GB)")
    
    return {"metric": "Memory", "value": used_percent, "status": status}


def check_disk():
    """Check disk usage for all partitions."""
    results = []
    for partition in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            used_percent = usage.percent
            status = "OK" if used_percent < THRESHOLDS["disk_percent"] else "ALERT"
            
            if status == "ALERT":
                logger.warning(
                    f"🔴 DISK ALERT: {partition.mountpoint} is {used_percent}% full "
                    f"(threshold: {THRESHOLDS['disk_percent']}%)"
                )
            else:
                logger.info(f"✅ Disk [{partition.mountpoint}]: {used_percent}% used")
            
            results.append({"mount": partition.mountpoint, "value": used_percent, "status": status})
        except PermissionError:
            pass  # Some partitions may not be accessible
    return results


def check_processes():
    """Check number of running processes."""
    proc_count = len(psutil.pids())
    status = "OK" if proc_count < THRESHOLDS["max_processes"] else "ALERT"
    
    if status == "ALERT":
        logger.warning(
            f"🔴 PROCESS ALERT: {proc_count} processes running "
            f"(threshold: {THRESHOLDS['max_processes']})"
        )
    else:
        logger.info(f"✅ Running Processes: {proc_count}")
    
    # Show top 5 CPU-consuming processes
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
        try:
            processes.append(proc.info)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    
    top5 = sorted(processes, key=lambda x: x['cpu_percent'], reverse=True)[:5]
    logger.info("📊 Top 5 CPU processes:")
    for p in top5:
        logger.info(f"   PID {p['pid']}: {p['name']} — CPU: {p['cpu_percent']}%, MEM: {p['memory_percent']:.1f}%")
    
    return {"metric": "Processes", "value": proc_count, "status": status}


def run_health_check():
    """Run all health checks and print summary."""
    logger.info("=" * 60)
    logger.info(f"🏥 SYSTEM HEALTH CHECK — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("=" * 60)
    
    cpu_result    = check_cpu()
    mem_result    = check_memory()
    disk_results  = check_disk()
    proc_result   = check_processes()
    
    # Summary
    alerts = []
    if cpu_result["status"] == "ALERT":
        alerts.append("CPU")
    if mem_result["status"] == "ALERT":
        alerts.append("Memory")
    if any(d["status"] == "ALERT" for d in disk_results):
        alerts.append("Disk")
    if proc_result["status"] == "ALERT":
        alerts.append("Processes")
    
    logger.info("-" * 60)
    if alerts:
        logger.warning(f"⚠️  ALERTS TRIGGERED: {', '.join(alerts)}")
    else:
        logger.info("✅ All systems healthy! No alerts.")
    logger.info(f"📝 Log saved to: {LOG_FILE}")
    logger.info("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="System Health Monitor")
    parser.add_argument("--interval", type=int, default=0,
                        help="Run continuously every N seconds (0 = run once)")
    args = parser.parse_args()
    
    if args.interval > 0:
        logger.info(f"🔄 Running health check every {args.interval} seconds. Press Ctrl+C to stop.")
        while True:
            run_health_check()
            time.sleep(args.interval)
    else:
        run_health_check()


if __name__ == "__main__":
    main()
