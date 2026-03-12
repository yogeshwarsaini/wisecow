#!/usr/bin/env python3
"""
Application Health Checker
============================
Checks if web applications are UP or DOWN using HTTP status codes.
Logs results to console and a log file.

Usage:
    python3 app_health_checker.py
    python3 app_health_checker.py --interval 60    # Check every 60 seconds
"""

import requests
import logging
import argparse
import time
from datetime import datetime

# ─────────────────────────────────────────────
# CONFIGURATION - Add your app URLs here
# ─────────────────────────────────────────────
APPLICATIONS = [
    {"name": "Wisecow App",       "url": "http://localhost:4499"},
    {"name": "Google",            "url": "https://www.google.com"},
    {"name": "Example API",       "url": "https://httpbin.org/status/200"},
    {"name": "Broken App (test)", "url": "https://httpbin.org/status/503"},
]

# HTTP codes considered "UP"
HEALTHY_STATUS_CODES = {200, 201, 202, 301, 302}
REQUEST_TIMEOUT = 10   # seconds before considering app as DOWN
LOG_FILE = "app_health.log"

# ─────────────────────────────────────────────
# LOGGING SETUP
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def check_app(app: dict) -> dict:
    """
    Check a single application's health.
    Returns dict with name, url, status (UP/DOWN), http_code, response_time.
    """
    name = app["name"]
    url = app["url"]
    
    try:
        start_time = time.time()
        response = requests.get(url, timeout=REQUEST_TIMEOUT, allow_redirects=True)
        response_time = round((time.time() - start_time) * 1000, 2)  # in ms
        
        http_code = response.status_code
        
        if http_code in HEALTHY_STATUS_CODES:
            status = "UP"
            logger.info(
                f"✅ UP   | {name:<25} | HTTP {http_code} | {response_time}ms | {url}"
            )
        else:
            status = "DOWN"
            logger.warning(
                f"🔴 DOWN | {name:<25} | HTTP {http_code} | {response_time}ms | {url}"
            )
        
        return {
            "name": name, "url": url,
            "status": status, "http_code": http_code,
            "response_time_ms": response_time
        }
    
    except requests.exceptions.ConnectionError:
        logger.error(f"🔴 DOWN | {name:<25} | CONNECTION REFUSED | {url}")
        return {"name": name, "url": url, "status": "DOWN", "http_code": None, "error": "Connection refused"}
    
    except requests.exceptions.Timeout:
        logger.error(f"🔴 DOWN | {name:<25} | TIMEOUT (>{REQUEST_TIMEOUT}s) | {url}")
        return {"name": name, "url": url, "status": "DOWN", "http_code": None, "error": "Timeout"}
    
    except Exception as e:
        logger.error(f"🔴 DOWN | {name:<25} | ERROR: {e} | {url}")
        return {"name": name, "url": url, "status": "DOWN", "http_code": None, "error": str(e)}


def run_health_checks():
    """Check all configured applications."""
    logger.info("=" * 70)
    logger.info(f"🔍 APPLICATION HEALTH CHECK — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("=" * 70)
    
    results = [check_app(app) for app in APPLICATIONS]
    
    # Summary
    up_count   = sum(1 for r in results if r["status"] == "UP")
    down_count = sum(1 for r in results if r["status"] == "DOWN")
    
    logger.info("-" * 70)
    logger.info(f"📊 SUMMARY: {up_count} UP ✅  |  {down_count} DOWN 🔴  |  Total: {len(results)}")
    
    if down_count > 0:
        logger.warning("⚠️  DOWN Applications:")
        for r in results:
            if r["status"] == "DOWN":
                err = r.get("error", f"HTTP {r.get('http_code')}")
                logger.warning(f"   ❌ {r['name']} — {err}")
    
    logger.info(f"📝 Log saved to: {LOG_FILE}")
    logger.info("=" * 70)
    return results


def main():
    parser = argparse.ArgumentParser(description="Application Health Checker")
    parser.add_argument("--interval", type=int, default=0,
                        help="Check every N seconds continuously (0 = once)")
    args = parser.parse_args()
    
    if args.interval > 0:
        logger.info(f"🔄 Checking apps every {args.interval} seconds. Press Ctrl+C to stop.")
        while True:
            run_health_checks()
            time.sleep(args.interval)
    else:
        run_health_checks()


if __name__ == "__main__":
    main()
