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

## Install

### 1. Download

Grab **YouTube-Analytics.dmg** from the [Releases page](../../releases), open it, and drag the app to your Applications folder.

> If macOS says the app can't be opened, right-click it → **Open** → **Open** to confirm.

---

### 2. Connect to Google (one-time, ~10 minutes)

The app reads your YouTube data using Google's official API. You need to create a free access key — the app walks you through it step by step when you first open it.

Here's what you'll do:

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

1. Go to **APIs & Services → OAuth consent screen**
2. User type: **External** → **Create**
3. Fill in:
   - App name: `ytAnalytics`
   - User support email: your Gmail
   - Developer contact email: your Gmail
4. **Save and Continue** through to **Scopes**
5. Click **Add or Remove Scopes** and add all three:
   - `https://www.googleapis.com/auth/youtube.readonly`
   - `https://www.googleapis.com/auth/yt-analytics.readonly`
   - `https://www.googleapis.com/auth/youtube.force-ssl`
6. **Save and Continue** → **Test users** → **Add Users** → add your YouTube account email
7. **Save and Continue** → **Back to Dashboard**

#### Download your access key

1. Go to **APIs & Services → Credentials**
2. **Create Credentials → OAuth 2.0 Client ID**
3. Application type: **Desktop app** → Name it anything → **Create**
4. Click **Download JSON** on the new credential

---

### 3. Open the app

Open **YouTube Analytics** from your Applications folder. The setup wizard appears and asks you to drop in the JSON file you just downloaded. Do that, and your browser will open for a one-time Google sign-in.

After you approve, your stats appear in the menu bar within a few seconds.

---

### 4. Add the Notification Centre widget (optional)

1. Right-click your desktop → **Edit Widgets**
2. Search **YouTube Analytics**
3. Drag in the size you want — Small, Medium, or Large

---

## Changing settings

Click the `●` dot in your menu bar → **Settings tab**.

Toggle metrics on/off and adjust how many days of data each one covers. YouTube's analytics data has a 48–72 hour delay, so ranges of 7 days or more give the most reliable numbers.

Hit **Save** — changes take effect immediately.

---

## Troubleshooting

**App says "Server Offline"**
The background server stopped. Quit and reopen the app — it will restart automatically.

**Setup wizard appeared but then disappeared without finishing**
Quit the app and reopen it. The wizard will pick up where it left off.

**Browser didn't open for Google sign-in**
Make sure your Google account is added as a test user in the OAuth consent screen (Step 2).

**Sign-in failed or "deleted client" error**
Your access key may have been deleted in Google Cloud Console. Create a new one (Step 2d) and drop it into the app when it asks.

**All metrics show 0**
YouTube's analytics data has a 48–72 hour delay — data for "today" won't be there yet. Increase the time range to 7 days in Settings.

**Comments not showing**
Your channel may have comments disabled, or the `youtube.force-ssl` scope was missed during setup. You can turn off Latest Comments in Settings.

---

## Your data stays on your Mac

The app never sends your data anywhere:

- You sign in with Google once — the access token is saved locally on your Mac only
- The background server fetches your stats directly from YouTube and keeps them in memory
- Everything runs on `localhost` — nothing is reachable from outside your computer
- The app only requests read-only access — it cannot make any changes to your channel

---

<div align="center">
Built for creators who'd rather be making videos than checking dashboards.
</div>
