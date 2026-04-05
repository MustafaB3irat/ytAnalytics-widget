<div align="center">

# ytAnalytics

**Your YouTube channel stats — natively on your Mac.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://apple.com/macos)
[![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python)](https://python.org)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)

</div>

---

A lightweight local server authenticates with Google via OAuth and serves your YouTube analytics as JSON. Two native macOS interfaces display it — no browser, no dashboard, no manual refreshing.

- **Menu bar app** — live view count in your status bar; click for the full popover with all metrics and settings
- **Notification Centre widget** — Small, Medium, and Large sizes with your channel card and stats

```
┌─────────────────────────────────────┐
│ ▶  YouTube Analytics         ↻      │
├─────────────────────────────────────┤
│  ╭──────╮  Mustafa B'irat    ↗      │
│  │  👤  │  @MustafaBirat            │
│  ╰──────╯  ▶ 42 videos  👁 540K    │
├─────────────────────────────────────┤
│  👁 12.4K    ⏱ 52.0h    👥 8.4K    │
│  Views(7d)  Watch Time  Subscribers │
├─────────────────────────────────────┤
│  ↑ +12 subscribers (7d)             │
│    +5 vs previous · 14 gained       │
├─────────────────────────────────────┤
│  ⭐ Top Video                       │
│  [🖼] Switzerland Camping 🏕        │
│       4.2K views · 14h 0m           │
├─────────────────────────────────────┤
│  💬 Latest Comments                 │
│  Ahmed K.  Mashallah, amazing! 🎥   │
│  Sara M.   Can you do hiking next?  │
├─────────────────────────────────────┤
│  Updated 3 minutes ago        Quit  │
└─────────────────────────────────────┘
```

---

## Requirements

- macOS 14 Sonoma or later
- Python 3.10+
- Xcode 15+
- A Google account with an active YouTube channel

---

## Setup

### 1. Clone

```bash
git clone https://github.com/MustafaB3irat/ytAnalytics-widget.git ~/Developer/ytAnalytics
cd ~/Developer/ytAnalytics
```

---

### 2. Google Cloud & OAuth (one-time, ~10 minutes)

#### 2a. Create a project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top-left) → **New Project**
3. Name it `ytAnalytics` → **Create**
4. Make sure the new project is selected in the dropdown before continuing

#### 2b. Enable the APIs

1. Go to **APIs & Services → Library**
2. Search **YouTube Data API v3** → **Enable**
3. Search **YouTube Analytics API** → **Enable**

#### 2c. Configure the OAuth consent screen

1. Go to **APIs & Services → OAuth consent screen**
2. User type: **External** → **Create**
3. Fill in the required fields:
   - App name: `ytAnalytics`
   - User support email: your Gmail
   - Developer contact email: your Gmail
4. Click **Save and Continue** through to **Scopes**
5. Click **Add or Remove Scopes** and add both:
   - `https://www.googleapis.com/auth/youtube.readonly`
   - `https://www.googleapis.com/auth/yt-analytics.readonly`
6. Click **Save and Continue** to **Test users**
7. Click **Add Users** → add your YouTube account email
8. Click **Save and Continue** → **Back to Dashboard**

> **Why "External" and "Test users"?** Google requires apps in development to be external, and only the email addresses you list as test users can authenticate. Your data stays local.

#### 2d. Create the OAuth client credential

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth 2.0 Client ID**
3. Application type: **Desktop app**
4. Name: `ytAnalytics Desktop` (anything is fine)
5. Click **Create**
6. Click **Download JSON** on the newly created credential
7. Rename the downloaded file to `client_secret.json`
8. Move it to:
   ```
   ~/Developer/ytAnalytics/server/credentials/client_secret.json
   ```

The `credentials/` folder is git-ignored — this file never leaves your machine.

---

### 3. Python server

```bash
cd ~/Developer/ytAnalytics/server

# Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start the server
python server.py
```

On first run, a browser tab opens asking you to sign in with your Google account and approve access. After approval:
- The token is saved to `credentials/token.json`
- The server starts listening on `http://localhost:8765`
- You will never be prompted again (tokens auto-refresh)

**Verify it's working:**
```bash
curl http://localhost:8765/health
curl http://localhost:8765/analytics | python3 -m json.tool
```

The first `/analytics` request returns `202 Accepted` while the initial YouTube fetch completes (~5–10 seconds). Subsequent requests return cached JSON instantly.

---

### 4. Auto-start on login

Run the bundled install script once to register the server as a launchd agent — it will start automatically on every login without a terminal window:

```bash
cd ~/Developer/ytAnalytics/server
bash install_autostart.sh
```

The script detects your venv path, writes a plist to `~/Library/LaunchAgents/`, and loads it immediately.

**Useful commands:**
```bash
# View live server logs
tail -f ~/Library/Logs/ytAnalytics/server.log

# Check the agent is registered
launchctl list | grep ytanalytics

# Stop the server
launchctl unload ~/Library/LaunchAgents/com.ytanalytics.server.plist

# Start it again
launchctl load ~/Library/LaunchAgents/com.ytanalytics.server.plist
```

---

### 5. Xcode — Widget & Menu Bar app

The Xcode project is pre-configured with both targets. No setup needed beyond signing.

1. Open Xcode → **Open a Project or File**
2. Navigate to `~/Developer/ytAnalytics/xcode/` → open **ytAnalytics.xcodeproj**
3. For each target (`ytAnalyticsWidget` and `ytAnalyticsMenuBar`):
   - Select the target in the sidebar
   - Go to **Signing & Capabilities**
   - Set your **Team** (your Apple ID — a free account works)
4. Build and run each target (select the target from the scheme picker → ⌘R)

**Adding the widget:**
- Right-click your desktop or open Notification Centre
- Click **Edit Widgets**
- Search "YouTube Analytics" → drag it in
- Available in Small, Medium, and Large sizes

The menu bar app places a `▶` icon in your status bar showing live view counts. Click it to open the full popover.

---

## Configuration

All settings live in `config.json`. The server reads this on startup and the menu bar app's **Settings tab** can update it live (no restart needed).

```json
{
  "metrics": {
    "views_24hr": {
      "enabled": true,
      "time_range_days": 1
    },
    "watch_time_24hr": {
      "enabled": true,
      "time_range_days": 1
    },
    "total_subscribers": {
      "enabled": true
    },
    "subscriber_delta": {
      "enabled": true,
      "time_range_days": 1
    },
    "top_video_today": {
      "enabled": true,
      "time_range_days": 1
    },
    "latest_comments": {
      "enabled": true,
      "max_count": 5
    }
  },
  "server": {
    "port": 8765,
    "refresh_interval_seconds": 900
  },
  "oauth": {
    "credentials_file": "credentials/client_secret.json",
    "token_file": "credentials/token.json",
    "scopes": [
      "https://www.googleapis.com/auth/youtube.readonly",
      "https://www.googleapis.com/auth/yt-analytics.readonly"
    ]
  }
}
```

**`time_range_days`** — how many days back to aggregate (1–90). All time-range metrics support this.  
**`max_count`** — how many latest comments to fetch.  
**`refresh_interval_seconds`** — how often the server re-fetches from YouTube (default: 900 = 15 min).

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/analytics` | All enabled metrics (cached) |
| `GET` | `/refresh` | Force immediate re-fetch from YouTube |
| `GET` | `/settings` | Current interval + metric toggles + time ranges |
| `PATCH` | `/settings` | Update interval / toggles / time ranges live |
| `GET` | `/config` | Raw `config.json` contents |
| `GET` | `/health` | Server status + last fetch time |

**Example `PATCH /settings` body:**
```json
{
  "refresh_interval_seconds": 300,
  "metrics": {
    "views_24hr": { "enabled": true, "time_range_days": 7 },
    "latest_comments": { "enabled": false }
  }
}
```

Changes are written back to `config.json` and take effect immediately.

---

## Project Structure

```
ytAnalytics/
├── config.json                    ← All settings
├── server/
│   ├── server.py                  ← Flask server (localhost:8765)
│   ├── fetcher.py                 ← YouTube API calls
│   ├── auth.py                    ← OAuth flow + token refresh
│   ├── requirements.txt
│   ├── install_autostart.sh       ← One-shot launchd setup
│   └── credentials/               ← Git-ignored
│       ├── client_secret.json     ← You add this (Step 2d)
│       └── token.json             ← Auto-generated on first run
├── widget/
│   ├── Models.swift               ← Shared data models (both targets)
│   ├── Provider.swift             ← WidgetKit timeline provider
│   ├── WidgetView.swift           ← Small / Medium / Large UI
│   └── ytAnalyticsWidget.swift    ← Widget entry point
├── menubar/
│   ├── ytAnalyticsApp.swift       ← NSStatusItem + AppDelegate
│   ├── AnalyticsViewModel.swift   ← Polling + settings state
│   └── MenuBarView.swift          ← Analytics + Settings tabs
└── xcode/
    ├── ytAnalytics.xcodeproj      ← Pre-configured, open this
    ├── ytAnalyticsWidget/         ← Widget assets + Info.plist
    └── ytAnalyticsMenuBar/        ← Menu bar assets + entitlements
```

---

## Troubleshooting

**Widget / app shows "Server Offline"**
→ The Python server isn't running. Run `bash install_autostart.sh` to set up auto-start, or start it manually with `python server.py` in the `server/` directory.

**Browser doesn't open / OAuth fails**
→ Make sure `client_secret.json` is at `server/credentials/client_secret.json` and your Google account is listed as a test user in the OAuth consent screen.

**Token expired or auth error**
→ Delete `credentials/token.json` and restart the server — a new browser-based sign-in will run automatically.

**No data — stays loading**
→ Normal on first run. The server fetches data from YouTube once on startup. Wait 10 seconds then hit `curl http://localhost:8765/health` to check status.

**Comments not showing**
→ YouTube's Comments API is unavailable on channels with comments disabled. Set `"latest_comments": { "enabled": false }` in `config.json`.

**Xcode signing error**
→ Select your Apple ID team in **Signing & Capabilities** for both the `ytAnalyticsWidget` and `ytAnalyticsMenuBar` targets. A free Apple ID works.

**YouTube quota exceeded**
→ Default quota is 10,000 units/day. At 15-minute refresh intervals, ytAnalytics uses ~96 units/day. If you hit the limit, increase `refresh_interval_seconds` in `config.json`.

---

## Security

- OAuth tokens are stored **locally only** in `credentials/token.json` (git-ignored)
- The server binds to `127.0.0.1` — never network-accessible
- API scopes are **read-only**: `youtube.readonly` + `yt-analytics.readonly`
- Your credentials and data never leave your machine

---

<div align="center">
Built for creators who'd rather be making videos than checking dashboards.
</div>
