<div align="center">

# ytAnalytics

**Your YouTube channel stats — natively on your Mac.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://apple.com/macos)
[![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python)](https://python.org)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

ytAnalytics puts your YouTube channel analytics directly on your Mac — no browser, no dashboard, no manual refreshing. It runs a lightweight local server that authenticates with Google via OAuth and exposes your stats as a JSON API. Two native macOS interfaces consume it:

- **🖥 Menu bar app** — live view count in your status bar; click for the full popover
- **📊 Notification Centre widget** — Small, Medium, and Large sizes with your channel card

---

## Screenshots

### Menu Bar Popover

```
┌─────────────────────────────────────┐
│ ▶  YouTube Analytics         ↻      │
├─────────────────────────────────────┤
│  ╭──────╮                           │
│  │  👤  │  Mustafa B'irat           │
│  ╰──────╯  @MustafaBirat            │
│            ▶ 42 videos  👁 540K     │
├─────────────────────────────────────┤
│  👁 12.4K     ⏱ 52.0h    👥 8.4K   │
│  Views(24h)  Watch Time  Subscribers│
├─────────────────────────────────────┤
│  ↑ +12 subscribers today            │
│    +5 vs yesterday · 14 gained      │
├─────────────────────────────────────┤
│  ⭐ Top Video Today                 │
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

### Notification Centre Widget (Medium)

```
┌────────────────────────────────────────────┐
│  ╭──╮  Mustafa B'irat              ▶       │
│  ╰──╯  @MustafaBirat                       │
├─────────────────┬──────────────────────────┤
│  👁  12.4K      │  ⭐ Top today            │
│     views (24h) │  Switzerland Camping 🏕  │
│                 │  4.2K views              │
│  ⏱  52.0h       ├──────────────────────────│
│     watch time  │  💬 Latest              │
│                 │  Ahmed K.               │
│  👥  8.4K       │  Mashallah, amazing! 🎥 │
│     subscribers │                          │
│  3m ago         │                          │
└─────────────────┴──────────────────────────┘
```

---

## Features

| Feature | Menu Bar | Widget S | Widget M | Widget L |
|---|:---:|:---:|:---:|:---:|
| Channel card (avatar + name) | ✅ | ✅ | ✅ | ✅ |
| Views (24h) | ✅ | ✅ | ✅ | ✅ |
| Watch time (24h) | ✅ | — | ✅ | ✅ |
| Total subscribers | ✅ | ✅ | ✅ | ✅ |
| Subscriber delta (vs yesterday) | ✅ | ✅ | ✅ | ✅ |
| Top video today + thumbnail | ✅ | — | ✅ | ✅ |
| Latest comments | ✅ | — | ✅ | ✅ |
| Force refresh button | ✅ | — | — | — |
| Open channel / video links | ✅ | — | — | — |

All metrics are **individually toggleable** via `config.json` — no code changes needed.

---

## Architecture

```
YouTube Analytics API  ←── OAuth (one-time browser flow)
YouTube Data API v3    ←── Same OAuth token
        ↓
Python Flask server (localhost:8765)
  • Caches data, auto-refreshes every 5 min
  • Exposes /analytics as JSON
  • Starts automatically on login via launchd
        ↓
  ┌─────────────┬──────────────────┐
  ↓             ↓                  ↓
Widget      Menu Bar App      /analytics
(polls 5m)  (polls 5m)       (any HTTP client)
```

---

## Requirements

- macOS 14 Sonoma or later
- Python 3.10+
- Xcode 15+
- A YouTube channel
- A Google Cloud project (free)

---

## Installation

### Step 1 — Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/ytAnalytics.git ~/Developer/ytAnalytics
cd ~/Developer/ytAnalytics
```

### Step 2 — Google Cloud setup (one-time, ~10 minutes)

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and create a new project named `ytAnalytics`

2. Enable both APIs:
   - Search **"YouTube Data API v3"** → Enable
   - Search **"YouTube Analytics API"** → Enable

3. Configure OAuth consent screen:
   - Go to **APIs & Services → OAuth consent screen**
   - User type: **External** → Create
   - App name: `ytAnalytics`, add your email
   - Scopes: add `youtube.readonly` and `yt-analytics.readonly`
   - Test users: add your YouTube account email

4. Create credentials:
   - Go to **APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID**
   - Application type: **Desktop app**
   - Download the JSON and rename it `client_secret.json`

5. Place it at:
   ```
   ~/Developer/ytAnalytics/server/credentials/client_secret.json
   ```

### Step 3 — Python server

```bash
cd ~/Developer/ytAnalytics/server

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# First run — browser opens for Google sign-in
python server.py
```

Approve access in your browser. The token is saved to `credentials/token.json` — you won't need to sign in again.

Verify it's working:
```bash
curl http://localhost:8765/analytics | python3 -m json.tool
```

### Step 4 — Auto-start on login

```bash
bash install_autostart.sh
```

This installs a launchd agent that starts the server on every login automatically. Logs go to `~/Library/Logs/ytAnalytics/`.

```bash
# Useful commands
tail -f ~/Library/Logs/ytAnalytics/server.log   # Live logs
launchctl list | grep ytanalytics                # Check status
```

### Step 5 — Xcode (Widget + Menu Bar app)

1. Open Xcode → **Open a Project or File**
2. Navigate to `~/Developer/ytAnalytics/xcode/` and open `ytAnalytics.xcodeproj`
3. The project has two targets pre-configured:
   - `ytAnalyticsWidget` — Notification Centre widget
   - `ytAnalyticsMenuBar` — Menu bar app
4. Select your Apple Developer team in **Signing & Capabilities** for each target
5. Build each target (⌘B) then run (⌘R)

**Adding the widget to Notification Centre:**
- Right-click your desktop → **Edit Widgets**
- Search "YouTube" → drag **YouTube Analytics** to your widget area
- Available in Small, Medium, and Large sizes

---

## Configuration

Edit `config.json` to customise metrics — the server picks up changes on restart:

```json
{
  "metrics": {
    "views_24hr":        { "enabled": true,  "label": "Views Today" },
    "watch_time_24hr":   { "enabled": true,  "label": "Watch Time (24h)" },
    "total_subscribers": { "enabled": true,  "label": "Subscribers" },
    "subscriber_delta":  { "enabled": true,  "compare_days": 1 },
    "latest_comments":   { "enabled": true,  "max_count": 5 },
    "top_video_today":   { "enabled": true,  "metric": "views" }
  },
  "server": {
    "port": 8765,
    "refresh_interval_seconds": 300
  }
}
```

---

## API Reference

The server exposes a simple HTTP API — useful for debugging or building your own integrations:

| Method | Endpoint | Description |
|---|---|---|
| GET | `/analytics` | All enabled metrics (cached) |
| GET | `/refresh` | Force immediate re-fetch from YouTube |
| GET | `/config` | Current active configuration |
| GET | `/health` | Server status and last fetch time |

Example response from `/analytics`:
```json
{
  "fetched_at": "2025-04-04T14:30:00Z",
  "channel": {
    "id": "UCxxxxxx",
    "name": "Mustafa B'irat",
    "handle": "@MustafaBirat",
    "avatar_url": "https://yt3.ggpht.com/...",
    "subscriber_count": 8430,
    "video_count": 42
  },
  "metrics": {
    "views_24hr": { "label": "Views (24h)", "data": { "value": 12400 } },
    "subscriber_delta": { "data": { "net": 12, "gained": 14, "lost": 2, "vs_yesterday": 5 } }
  }
}
```

---

## Project Structure

```
ytAnalytics/
├── config.json                    ← Customise metrics here
├── server/
│   ├── server.py                  ← Flask server (localhost:8765)
│   ├── fetcher.py                 ← YouTube API calls
│   ├── auth.py                    ← OAuth flow
│   ├── requirements.txt
│   ├── install_autostart.sh       ← launchd auto-start setup
│   └── credentials/               ← Git-ignored (add client_secret.json here)
├── widget/
│   ├── Models.swift               ← Shared models (widget + menu bar)
│   ├── Provider.swift             ← WidgetKit timeline provider
│   ├── WidgetView.swift           ← Small / Medium / Large UI
│   └── ytAnalyticsWidget.swift    ← Widget entry point
├── menubar/
│   ├── ytAnalyticsApp.swift       ← App delegate + status bar icon
│   ├── AnalyticsViewModel.swift   ← State + polling
│   └── MenuBarView.swift          ← Popover UI
└── xcode/
    ├── ytAnalytics.xcodeproj      ← Pre-configured project (open this)
    ├── ytAnalyticsWidget/         ← Widget assets
    └── ytAnalyticsMenuBar/        ← Menu bar app assets + entitlements
```

---

## Troubleshooting

**Widget shows "Server Offline"**
→ Make sure the Python server is running. Run `bash install_autostart.sh` to set up auto-start.

**Authentication error after a while**
→ Delete `credentials/token.json` and re-run `python server.py` to re-authenticate.

**No data / loading forever**
→ The server is doing its first YouTube API fetch. Wait ~10 seconds then check `curl http://localhost:8765/health`.

**Comments API error**
→ YouTube's Comments API can be unavailable for channels with comments disabled. Set `latest_comments.enabled` to `false` in `config.json`.

**YouTube quota exceeded**
→ The default quota is 10,000 units/day. At 5-minute refresh intervals, ytAnalytics uses ~288 units/day — well within limits.

---

## Security

- OAuth tokens stored **locally only** in `credentials/token.json` (git-ignored)
- The server binds to `127.0.0.1` only — never accessible from the network
- **Read-only** API scopes: `youtube.readonly` and `yt-analytics.readonly`
- Your data never leaves your machine

---

## License

MIT — do whatever you want with it.

---

<div align="center">
Built with ❤️ for creators who'd rather be making videos than checking dashboards.
</div>
