"""
ytAnalytics local server.
Runs on localhost and exposes your YouTube analytics as a JSON API.
The macOS widget and menu bar app poll this server to display your stats.

Usage:
    python server.py
    python server.py --config ../config.json
"""

import json
import time
import threading
import argparse
from pathlib import Path
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS

from auth import get_credentials
from fetcher import YouTubeFetcher

# ── Setup ─────────────────────────────────────────────────────────────────────

app = Flask(__name__)
CORS(app)

_cache = {
    "data": None,
    "fetched_at": None,
    "error": None
}
_config = {}
_config_path: Path = None
_fetcher: YouTubeFetcher = None

# Event used to reset the background timer when the interval changes
_refresh_event = threading.Event()

# ── Config helpers ────────────────────────────────────────────────────────────

def load_config(config_path: str) -> dict:
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    with open(path) as f:
        return json.load(f)


def save_config():
    """Persist the in-memory config back to config.json."""
    with open(_config_path, "w") as f:
        json.dump(_config, f, indent=2)
    print(f"💾 Config saved to {_config_path}")


def get_interval() -> int:
    return _config.get("server", {}).get("refresh_interval_seconds", 900)

# ── Data fetching ─────────────────────────────────────────────────────────────

def refresh_cache():
    global _cache
    try:
        print(f"\n🔄 [{datetime.now().strftime('%H:%M:%S')}] Refreshing analytics...")
        data = _fetcher.fetch_all()
        _cache["data"] = data
        _cache["fetched_at"] = datetime.now(timezone.utc).isoformat()
        _cache["error"] = None
        print(f"✅ Done. Next refresh in {get_interval()}s")
    except Exception as e:
        _cache["error"] = str(e)
        print(f"❌ Refresh failed: {e}")


def background_refresh():
    """
    Background thread. Uses an Event so changing the interval in settings
    takes effect immediately — no need to restart the server.
    """
    while True:
        interval = get_interval()
        # Wait for either the interval to elapse or a reset signal
        fired = _refresh_event.wait(timeout=interval)
        if fired:
            # Settings changed — just reset the timer, don't fetch yet
            _refresh_event.clear()
            print(f"⚙️  Interval updated to {get_interval()}s — timer reset")
        else:
            refresh_cache()

# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return jsonify({
        "service": "ytAnalytics",
        "status": "running",
        "refresh_interval_seconds": get_interval(),
        "endpoints": ["/analytics", "/refresh", "/config", "/settings", "/health"]
    })


@app.route("/analytics")
def analytics():
    """Main endpoint — returns cached analytics data."""
    if _cache["error"]:
        return jsonify({"error": _cache["error"]}), 500
    if not _cache["data"]:
        return jsonify({"status": "loading", "message": "Fetching data for the first time..."}), 202
    return jsonify(_cache["data"])


@app.route("/refresh", methods=["POST", "GET"])
def force_refresh():
    """Force an immediate cache refresh."""
    threading.Thread(target=refresh_cache, daemon=True).start()
    return jsonify({"status": "refreshing"})


@app.route("/config")
def get_config():
    """Return the current full config."""
    return jsonify(_config)


@app.route("/settings", methods=["GET"])
def get_settings():
    """Return just the user-facing settings (interval + metric toggles)."""
    return jsonify({
        "refresh_interval_seconds": get_interval(),
        "metrics": {
            k: {
                "enabled":         v.get("enabled", False),
                "label":           v.get("label", k),
                "time_range_days": v.get("time_range_days", None),  # None if not applicable
            }
            for k, v in _config.get("metrics", {}).items()
        }
    })


@app.route("/settings", methods=["PATCH"])
def update_settings():
    """
    Update interval and/or metric toggles from the menu bar settings UI.
    Persists changes to config.json immediately.

    Accepted body (all fields optional):
    {
        "refresh_interval_seconds": 900,
        "metrics": {
            "views_24hr": { "enabled": true },
            "latest_comments": { "enabled": false }
        }
    }
    """
    body = request.get_json(silent=True) or {}
    changed = False

    # Update refresh interval
    if "refresh_interval_seconds" in body:
        new_interval = int(body["refresh_interval_seconds"])
        # Clamp to sensible range: 5 min – 24 hr
        new_interval = max(300, min(new_interval, 86400))
        old_interval = get_interval()
        if new_interval != old_interval:
            _config.setdefault("server", {})["refresh_interval_seconds"] = new_interval
            _config["server"]["cache_ttl_seconds"] = new_interval
            # Signal the background thread to reset its timer
            _refresh_event.set()
            changed = True
            print(f"⚙️  Refresh interval → {new_interval}s")

    # Update metric toggles and time ranges
    if "metrics" in body:
        for metric_key, updates in body["metrics"].items():
            if metric_key in _config.get("metrics", {}):
                if "enabled" in updates:
                    _config["metrics"][metric_key]["enabled"] = bool(updates["enabled"])
                    changed = True
                if "time_range_days" in updates:
                    days = int(updates["time_range_days"])
                    days = max(1, min(days, 90))  # clamp 1–90 days
                    _config["metrics"][metric_key]["time_range_days"] = days
                    changed = True

    if changed:
        save_config()

    return jsonify({
        "status": "ok",
        "refresh_interval_seconds": get_interval(),
        "metrics": {
            k: {"enabled": v.get("enabled", False)}
            for k, v in _config.get("metrics", {}).items()
        }
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "cached_at": _cache.get("fetched_at"),
        "has_data": _cache["data"] is not None,
        "refresh_interval_seconds": get_interval()
    })


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    global _config, _config_path, _fetcher

    parser = argparse.ArgumentParser(description="ytAnalytics local server")
    parser.add_argument(
        "--config",
        default=str(Path(__file__).parent.parent / "config.json"),
        help="Path to config.json"
    )
    args = parser.parse_args()

    print("🎬 ytAnalytics Server")
    print("=" * 40)

    _config_path = Path(args.config)
    _config = load_config(args.config)
    port = _config.get("server", {}).get("port", 8765)
    print(f"⚙️  Config: {args.config}")
    print(f"⏱  Refresh interval: {get_interval()}s ({get_interval() // 60} min)")

    # Auth
    creds = get_credentials(_config)
    _fetcher = YouTubeFetcher(creds, _config)

    # Initial blocking fetch — widget has data as soon as server is ready
    print("\n📡 Fetching initial data...")
    refresh_cache()

    # Background refresh thread
    t = threading.Thread(target=background_refresh, daemon=True)
    t.start()

    print(f"\n🚀 Server running at http://localhost:{port}")
    print(f"   Analytics: http://localhost:{port}/analytics")
    print(f"   Settings:  http://localhost:{port}/settings")
    print(f"   Refresh:   http://localhost:{port}/refresh")
    print("   Press Ctrl+C to stop\n")

    app.run(host="127.0.0.1", port=port, debug=False)


if __name__ == "__main__":
    main()
