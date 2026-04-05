#!/bin/bash
# install_autostart.sh
# Installs a launchd agent so the ytAnalytics server starts automatically on login.
# Run once: bash install_autostart.sh

set -e

# ── Detect paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PYTHON="$SCRIPT_DIR/venv/bin/python"
SERVER_PY="$SCRIPT_DIR/server.py"
PLIST_PATH="$HOME/Library/LaunchAgents/com.ytanalytics.server.plist"
LOG_DIR="$HOME/Library/Logs/ytAnalytics"

# ── Checks ───────────────────────────────────────────────────────────────────

if [ ! -f "$VENV_PYTHON" ]; then
    echo "❌ Virtual environment not found at: $VENV_PYTHON"
    echo "   Run: cd server && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

if [ ! -f "$SERVER_PY" ]; then
    echo "❌ server.py not found at: $SERVER_PY"
    exit 1
fi

# ── Create log directory ──────────────────────────────────────────────────────

mkdir -p "$LOG_DIR"
echo "📁 Logs will be written to: $LOG_DIR"

# ── Write plist ───────────────────────────────────────────────────────────────

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ytanalytics.server</string>

    <key>ProgramArguments</key>
    <array>
        <string>$VENV_PYTHON</string>
        <string>$SERVER_PY</string>
        <string>--config</string>
        <string>$PROJECT_DIR/config.json</string>
    </array>

    <!-- Start immediately when loaded, and restart if it crashes -->
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>

    <!-- Logs -->
    <key>StandardOutPath</key>
    <string>$LOG_DIR/server.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/server.err</string>

    <!-- Working directory -->
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>

    <!-- Throttle restarts — wait 10s before restarting on crash -->
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

echo "✅ plist written to: $PLIST_PATH"

# ── Unload if already loaded (for re-installs) ────────────────────────────────

if launchctl list | grep -q "com.ytanalytics.server"; then
    echo "🔄 Unloading existing agent..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

# ── Load the agent ────────────────────────────────────────────────────────────

launchctl load "$PLIST_PATH"
echo "🚀 Agent loaded — server will now start on every login."
echo ""
echo "Useful commands:"
echo "  View logs:    tail -f $LOG_DIR/server.log"
echo "  Stop server:  launchctl unload $PLIST_PATH"
echo "  Start server: launchctl load $PLIST_PATH"
echo "  Check status: launchctl list | grep ytanalytics"
echo ""
echo "Waiting 3 seconds for server to start..."
sleep 3

if curl -s http://localhost:8765/health | grep -q '"status"'; then
    echo "✅ Server is running at http://localhost:8765"
else
    echo "⚠️  Server may still be starting. Check logs: tail -f $LOG_DIR/server.log"
fi
