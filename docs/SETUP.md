# ytAnalytics — Setup Guide

A native macOS Notification Centre widget that displays your YouTube channel analytics in real time.

---

## Architecture

```
Python Server (localhost:8765)
    ↓  OAuth → YouTube Analytics API
    ↓  JSON response
Swift WidgetKit (Notification Centre)
    ↓  Polls every 5 minutes
    ↓  Displays stats natively
```

---

## Step 1 — Google Cloud Project & OAuth Credentials

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (e.g. `ytAnalytics`)
3. Enable these two APIs:
   - **YouTube Data API v3**
   - **YouTube Analytics API**
4. Go to **APIs & Services → OAuth consent screen**
   - Select **External**
   - Fill in app name (`ytAnalytics`) and your email
   - Under **Scopes**, add:
     - `youtube.readonly`
     - `yt-analytics.readonly`
   - Under **Test users**, add your YouTube account email
5. Go to **APIs & Services → Credentials**
   - Click **Create Credentials → OAuth 2.0 Client ID**
   - Application type: **Desktop app**
   - Download the JSON file
6. Rename it to `client_secret.json` and place it at:
   ```
   ~/Developer/ytAnalytics/server/credentials/client_secret.json
   ```

---

## Step 2 — Python Server Setup

```bash
cd ~/Developer/ytAnalytics/server

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the server (first run will open browser for OAuth)
python server.py
```

On first run, your browser will open for Google sign-in. Approve access and the token is saved — you won't need to re-authenticate.

The server runs at **http://localhost:8765**. Verify with:
```bash
curl http://localhost:8765/analytics
```

---

## Step 3 — Auto-start Server on Login

Run the included install script — it sets up a launchd agent so the server starts automatically every time you log in (no terminal needed):

```bash
cd ~/Developer/ytAnalytics/server
bash install_autostart.sh
```

The script will:
- Detect your venv Python path automatically
- Write a plist to `~/Library/LaunchAgents/`
- Load it immediately (server starts right away)
- Print control commands for stopping/starting

**Useful commands after installing:**
```bash
# View live logs
tail -f ~/Library/Logs/ytAnalytics/server.log

# Stop the server
launchctl unload ~/Library/LaunchAgents/com.ytanalytics.server.plist

# Restart it
launchctl load ~/Library/LaunchAgents/com.ytanalytics.server.plist

# Check it's running
launchctl list | grep ytanalytics
```

---

## Step 4 — Menu Bar App (optional but recommended)

The menu bar app shows live stats in your menu bar and opens a full popover on click.

1. Open **Xcode → File → New → Project**
2. Choose **macOS → App**
3. Name it `ytAnalyticsMenuBar`
4. Add the files from `menubar/`:
   - `ytAnalyticsApp.swift`
   - `AnalyticsViewModel.swift`
   - `MenuBarView.swift`
5. Also add the shared `widget/Models.swift` (add as reference, not copy)
6. In `Info.plist`, add key: `Application is agent (UIElement)` = `YES` (hides Dock icon)
7. Build & run — a ▶️ icon appears in your menu bar

**Menu bar shows:** live view count right in the status bar, click for full popover with all metrics.

---

## Step 5 — Xcode Widget Setup

1. Open **Xcode → File → New → Project**
2. Choose **Widget Extension** (under macOS)
3. Name it `ytAnalyticsWidget`
4. Replace the generated Swift files with the files in `widget/`:
   - `Models.swift`
   - `Provider.swift`
   - `WidgetView.swift`
   - `ytAnalyticsWidget.swift`
5. Build & run (⌘R)
6. Right-click your desktop/Notification Centre → **Edit Widgets**
7. Find **YouTube Analytics** and add it

---

## Customising Metrics

Edit `config.json` to toggle metrics on/off or change labels — no code changes needed:

```json
{
  "metrics": {
    "views_24hr": { "enabled": true, "label": "Views Today" },
    "watch_time_24hr": { "enabled": true },
    "total_subscribers": { "enabled": true },
    "latest_comments": { "enabled": true, "max_count": 3 },
    "top_video_today": { "enabled": false }
  },
  "server": {
    "refresh_interval_seconds": 300
  }
}
```

Then restart the server. The widget picks up changes on its next 5-minute refresh.

---

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /analytics` | All enabled metrics (cached) |
| `GET /refresh` | Force immediate refresh |
| `GET /config` | Current config |
| `GET /health` | Server health + last fetch time |

---

## Troubleshooting

**Widget shows "Server Offline"**
→ Make sure `python server.py` is running in a terminal, or set up the launchd auto-start.

**Authentication error**
→ Delete `credentials/token.json` and re-run — it will re-authenticate.

**No data / 202 response**
→ The server is still doing its first fetch. Wait a few seconds and try `/analytics` again.

**YouTube quota exceeded**
→ The YouTube Analytics API allows 10,000 quota units/day. With 5-minute refresh intervals, this project uses ~288 units/day — well within limits.
