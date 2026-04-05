#!/bin/bash
# setup.command
# Double-click this file in Finder — Terminal opens and runs full setup.
# Safe to re-run at any time (updates deps and re-registers launchd).

# ── Always run from repo root ─────────────────────────────────────────────────
cd "$(dirname "$BASH_SOURCE")"
REPO="$(pwd)"
SERVER_DIR="$REPO/server"
VENV="$SERVER_DIR/venv"
CREDENTIALS="$SERVER_DIR/credentials/client_secret.json"
LOG_DIR="$HOME/Library/Logs/ytAnalytics"

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ytAnalytics — One-click Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Pre-flight: client_secret.json ────────────────────────────────────────────

if [ ! -f "$CREDENTIALS" ]; then
    echo "❌  Missing: server/credentials/client_secret.json"
    echo ""
    echo "   You need a Google OAuth credential before running this:"
    echo "   1. Go to console.cloud.google.com → your project"
    echo "   2. APIs & Services → Credentials"
    echo "   3. Create Credentials → OAuth 2.0 Client ID → Desktop app"
    echo "   4. Download JSON → rename to client_secret.json"
    echo "   5. Place it at:  server/credentials/client_secret.json"
    echo ""
    echo "   See README.md Step 2 for the full walkthrough."
    echo ""
    read -rp "Press Enter to exit…"
    exit 1
fi

# ── Pre-flight: python3 ───────────────────────────────────────────────────────

if ! command -v python3 &>/dev/null; then
    echo "❌  python3 not found."
    echo "   Install via Homebrew:  brew install python3"
    echo "   Or download from:      https://www.python.org/downloads/"
    echo ""
    read -rp "Press Enter to exit…"
    exit 1
fi

echo "✓  python3  $(python3 --version)"
echo ""

# ── Virtual environment ───────────────────────────────────────────────────────

if [ ! -d "$VENV" ]; then
    echo "📦  Creating virtual environment…"
    python3 -m venv "$VENV"
    echo "✓  venv created"
else
    echo "✓  venv already exists"
fi

# ── Dependencies ──────────────────────────────────────────────────────────────

echo "📥  Installing Python dependencies…"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r "$SERVER_DIR/requirements.txt"
echo "✓  Dependencies ready"
echo ""

# ── launchd auto-start ────────────────────────────────────────────────────────

echo "⚙️   Registering server to run on login (launchd)…"
echo ""

PLIST_PATH="$HOME/Library/LaunchAgents/com.ytanalytics.server.plist"
VENV_PYTHON="$VENV/bin/python"
SERVER_PY="$SERVER_DIR/server.py"

mkdir -p "$LOG_DIR"

cat > "$PLIST_PATH" << PLIST
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
        <string>$REPO/config.json</string>
    </array>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/server.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/server.err</string>

    <key>WorkingDirectory</key>
    <string>$SERVER_DIR</string>

    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLIST

# Unload if already running (re-install)
if launchctl list 2>/dev/null | grep -q "com.ytanalytics.server"; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

launchctl load "$PLIST_PATH"
echo "✓  launchd agent registered — server starts on every login"
echo ""

# ── First-run OAuth notice ────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐  Google sign-in"
echo ""
echo "   Your browser will open in a moment asking you to"
echo "   sign in with Google and approve read-only access"
echo "   to your YouTube data."
echo ""
echo "   After approval, the token is saved locally and"
echo "   you will never be asked again."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Waiting for server to start…"
sleep 4

# ── Health check ──────────────────────────────────────────────────────────────

MAX=15
COUNT=0
while [ $COUNT -lt $MAX ]; do
    if curl -sf http://localhost:8765/health | grep -q '"status"'; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅  Setup complete!"
        echo ""
        echo "   Server: http://localhost:8765"
        echo "   Logs:   tail -f $LOG_DIR/server.log"
        echo ""
        echo "   Next steps:"
        echo "   1. Open xcode/ytAnalytics.xcodeproj in Xcode"
        echo "   2. Set your Apple ID signing team on both targets"
        echo "   3. Build and run each target (⌘R)"
        echo "   4. Add the widget via Notification Centre → Edit Widgets"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -rp "Press Enter to close…"
        exit 0
    fi
    sleep 2
    COUNT=$((COUNT + 1))
done

# Timed out — likely waiting for OAuth in browser
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳  Server is waiting for Google sign-in in your browser."
echo ""
echo "   Complete the sign-in, then the server starts"
echo "   automatically. Check status with:"
echo "   curl http://localhost:8765/health"
echo ""
echo "   Logs: tail -f $LOG_DIR/server.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -rp "Press Enter to close…"
