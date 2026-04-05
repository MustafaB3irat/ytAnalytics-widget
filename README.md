<div align="center">

# YouTube Analytics

**Your YouTube channel stats — right in your Mac's menu bar and Notification Centre.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://apple.com/macos)

</div>

---

A tiny Mac app that shows your YouTube channel stats without opening a browser. Your data stays entirely on your Mac — nothing is sent anywhere.

- **Menu bar** — see your views at a glance; click for the full breakdown
- **Notification Centre widget** — Small, Medium, and Large sizes

<div align="center">
<img src="docs/screenshots/analytics.png" width="300" alt="Analytics view" />
&nbsp;&nbsp;&nbsp;
<img src="docs/screenshots/settings.png" width="300" alt="Settings view" />
</div>

---

## Requirements

- Mac running macOS 14 Sonoma or later
- A Google account with an active YouTube channel

---

## Setup

### 1. Download

Grab the latest release from the [Releases page](../../releases) and unzip it anywhere — your Desktop works fine.

---

### 2. Connect to Google (one-time, ~10 minutes)

The app reads your YouTube data using Google's official API. You need to create a free access key in Google Cloud Console. You only do this once.

#### Create a project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top-left) → **New Project**
3. Name it `ytAnalytics` → **Create**
4. Make sure the new project is selected before continuing

#### Turn on YouTube access

1. Go to **APIs & Services → Library**
2. Search **YouTube Data API v3** → **Enable**
3. Search **YouTube Analytics API** → **Enable**

#### Set up the consent screen

This is what Google shows when asking for your permission.

1. Go to **APIs & Services → OAuth consent screen**
2. User type: **External** → **Create**
3. Fill in:
   - App name: `ytAnalytics`
   - User support email: your Gmail
   - Developer contact email: your Gmail
4. Click **Save and Continue** through to **Scopes**
5. Click **Add or Remove Scopes** and add all three:
   - `https://www.googleapis.com/auth/youtube.readonly`
   - `https://www.googleapis.com/auth/yt-analytics.readonly`
   - `https://www.googleapis.com/auth/youtube.force-ssl`
6. **Save and Continue** → **Test users** → **Add Users** → add your YouTube account email
7. **Save and Continue** → **Back to Dashboard**

#### Create the access key

1. Go to **APIs & Services → Credentials**
2. **Create Credentials → OAuth 2.0 Client ID**
3. Application type: **Desktop app** → Name it anything → **Create**
4. Click **Download JSON** on the new credential
5. Rename the file to `client_secret.json`
6. Place it inside the unzipped folder at:
   ```
   server/credentials/client_secret.json
   ```

---

### 3. Run setup.command

Double-click **`setup.command`** inside the unzipped folder.

It will:
- Install the menu bar app to your Applications folder
- Set up the background server that fetches your stats
- Register it to start automatically on every login
- Open your browser for a one-time Google sign-in

After you approve access in the browser, your stats will appear in the menu bar within a few seconds.

> If macOS says the file can't be opened, right-click it and choose **Open**.

---

### 4. Add the Notification Centre widget (optional)

1. Right-click your desktop → **Edit Widgets** (or open Notification Centre and scroll down)
2. Search **YouTube Analytics**
3. Drag in the size you want — Small, Medium, or Large

---

## Changing settings

Click the `●` dot in your menu bar → **Settings tab**.

You can toggle metrics on/off and adjust how many days of data each metric covers. YouTube's analytics data has a 48–72 hour delay, so setting ranges to 7 days or more gives the most reliable numbers.

Hit **Save** — changes take effect immediately without restarting anything.

---

## Troubleshooting

**App says "Server Offline"**
The background server isn't running. Re-run `setup.command` to restart it.

**Browser didn't open for Google sign-in**
Make sure `server/credentials/client_secret.json` exists and your Google account is added as a test user in the OAuth consent screen (Step 2).

**Sign-in failed or auth error**
Delete `server/credentials/token.json` and re-run `setup.command` — it will ask you to sign in again.

**All metrics show 0**
YouTube's analytics API has a 48–72 hour delay. Data for "today" isn't available yet — increase the time range to 7 days in Settings.

**Comments not showing**
Your channel may have comments disabled, or the `youtube.force-ssl` scope wasn't added during setup. You can turn off Latest Comments in Settings.

**macOS blocks the app on first open**
Right-click the app or `setup.command` → **Open** → **Open** again to confirm.

---

## Your data stays on your Mac

The app never sends your data anywhere. Here's what actually happens:

- You sign in with Google once — the access token is saved in `server/credentials/token.json` on your Mac only
- The background server fetches your stats directly from YouTube and stores them in memory
- Everything runs on `localhost` — nothing is reachable from outside your computer
- The app only requests read-only access to your YouTube data — it cannot make any changes to your channel

---

<div align="center">
Built for creators who'd rather be making videos than checking dashboards.
</div>
