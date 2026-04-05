"""
YouTube Analytics fetcher.
Reads config.json to determine which metrics to fetch — fully customisable.
Time ranges for each metric are controlled by `time_range_days` in config.json.
"""

from datetime import datetime, timedelta, timezone
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials


class YouTubeFetcher:
    def __init__(self, creds: Credentials, config: dict):
        self.config = config
        self.metrics_config = config.get("metrics", {})

        self.youtube      = build("youtube",          "v3", credentials=creds)
        self.yt_analytics = build("youtubeAnalytics", "v2", credentials=creds)

        self._channel_id   = None
        self._channel_info = None

    # ── Channel info ──────────────────────────────────────────────────────────

    def get_channel_id(self) -> str:
        if self._channel_id:
            return self._channel_id
        self._ensure_channel_info()
        return self._channel_id

    def _ensure_channel_info(self):
        if self._channel_info:
            return
        response = self.youtube.channels().list(
            part="id,snippet,statistics", mine=True
        ).execute()
        items = response.get("items", [])
        if not items:
            raise ValueError("No YouTube channel found for this account.")
        item     = items[0]
        snippet  = item.get("snippet", {})
        stats    = item.get("statistics", {})
        thumbs   = snippet.get("thumbnails", {})
        avatar   = (
            thumbs.get("high",   {}).get("url") or
            thumbs.get("medium", {}).get("url") or
            thumbs.get("default",{}).get("url") or ""
        )
        self._channel_id   = item["id"]
        self._channel_info = {
            "id":               item["id"],
            "name":             snippet.get("title", ""),
            "handle":           snippet.get("customUrl", ""),
            "avatar_url":       avatar,
            "description":      snippet.get("description", "")[:200],
            "country":          snippet.get("country", ""),
            "subscriber_count": int(stats.get("subscriberCount", 0)),
            "video_count":      int(stats.get("videoCount", 0)),
            "view_count":       int(stats.get("viewCount", 0)),
        }

    def fetch_channel_info(self) -> dict:
        self._ensure_channel_info()
        return self._channel_info

    # ── Date range helpers ────────────────────────────────────────────────────

    def _date_range(self, days: int):
        """
        Return (start, end) date strings for the past `days` days.
        YouTube Analytics API uses YYYY-MM-DD and works in UTC calendar days,
        so 1 day = yesterday → today, 7 days = 7 days ago → today, etc.
        """
        today = datetime.now(timezone.utc).date()
        start = today - timedelta(days=days)
        return str(start), str(today)

    def _range_label(self, days: int) -> str:
        """Human-readable label: 1→'24h', 7→'7d', 30→'30d'."""
        if days == 1:
            return "24h"
        return f"{days}d"

    def _metric_days(self, metric_key: str, default: int = 1) -> int:
        """Read time_range_days from config for a given metric key."""
        return int(self.metrics_config.get(metric_key, {}).get("time_range_days", default))

    # ── Individual metric fetchers ────────────────────────────────────────────

    def fetch_views_24hr(self) -> dict:
        days       = self._metric_days("views_24hr", 1)
        start, end = self._date_range(days)
        response   = self.yt_analytics.reports().query(
            ids=f"channel=={self.get_channel_id()}",
            startDate=start, endDate=end,
            metrics="views"
        ).execute()
        rows = response.get("rows", [[0]])
        return {
            "value":           int(rows[0][0]) if rows else 0,
            "unit":            "views",
            "time_range_days": days,
            "range_label":     self._range_label(days),
        }

    def fetch_watch_time_24hr(self) -> dict:
        days       = self._metric_days("watch_time_24hr", 1)
        start, end = self._date_range(days)
        response   = self.yt_analytics.reports().query(
            ids=f"channel=={self.get_channel_id()}",
            startDate=start, endDate=end,
            metrics="estimatedMinutesWatched"
        ).execute()
        rows    = response.get("rows", [[0]])
        minutes = int(rows[0][0]) if rows else 0
        return {
            "value":           minutes,
            "hours":           round(minutes / 60, 1),
            "unit":            "minutes",
            "time_range_days": days,
            "range_label":     self._range_label(days),
        }

    def fetch_total_subscribers(self) -> dict:
        self._ensure_channel_info()
        return {
            "value": self._channel_info.get("subscriber_count", 0),
            "unit":  "subscribers",
        }

    def fetch_latest_comments(self) -> dict:
        cfg       = self.metrics_config.get("latest_comments", {})
        max_count = cfg.get("max_count", 5)
        response  = self.youtube.commentThreads().list(
            part="snippet",
            allThreadsRelatedToChannelId=self.get_channel_id(),
            maxResults=max_count,
            order="time"
        ).execute()
        comments = []
        for item in response.get("items", []):
            top = item["snippet"]["topLevelComment"]["snippet"]
            comments.append({
                "author":       top.get("authorDisplayName", "Unknown"),
                "text":         top.get("textDisplay", ""),
                "published_at": top.get("publishedAt", ""),
                "video_id":     top.get("videoId", ""),
                "like_count":   top.get("likeCount", 0),
            })
        return {"comments": comments, "count": len(comments)}

    def fetch_top_video_today(self) -> dict:
        days        = self._metric_days("top_video_today", 1)
        start, end  = self._date_range(days)
        cfg         = self.metrics_config.get("top_video_today", {})
        sort_metric = cfg.get("metric", "views")

        response = self.yt_analytics.reports().query(
            ids=f"channel=={self.get_channel_id()}",
            startDate=start, endDate=end,
            metrics="views,estimatedMinutesWatched",
            dimensions="video",
            sort=f"-{sort_metric}",
            maxResults=1
        ).execute()

        rows = response.get("rows", [])
        if not rows:
            return {
                "video_id": None, "title": "No data yet",
                "views": 0, "watch_time_minutes": 0, "url": None,
                "time_range_days": days, "range_label": self._range_label(days),
            }

        video_id   = rows[0][0]
        views      = int(rows[0][1])
        watch_time = int(rows[0][2])

        video_resp    = self.youtube.videos().list(part="snippet", id=video_id).execute()
        title         = "Unknown"
        thumbnail_url = None
        if video_resp.get("items"):
            snip          = video_resp["items"][0]["snippet"]
            title         = snip.get("title", "Unknown")
            thumbs        = snip.get("thumbnails", {})
            thumbnail_url = (
                thumbs.get("medium",  {}).get("url") or
                thumbs.get("default", {}).get("url")
            )

        return {
            "video_id":         video_id,
            "title":            title,
            "url":              f"https://youtu.be/{video_id}",
            "thumbnail_url":    thumbnail_url,
            "views":            views,
            "watch_time_minutes": watch_time,
            "time_range_days":  days,
            "range_label":      self._range_label(days),
        }

    def fetch_subscriber_delta(self) -> dict:
        days       = self._metric_days("subscriber_delta", 1)
        today      = datetime.now(timezone.utc).date()
        period_end = today
        period_start   = today - timedelta(days=days)
        prev_start     = period_start - timedelta(days=days)

        def parse_row(resp):
            rows = resp.get("rows", [[0, 0]])
            return (int(rows[0][0]), int(rows[0][1])) if rows else (0, 0)

        resp_curr = self.yt_analytics.reports().query(
            ids=f"channel=={self.get_channel_id()}",
            startDate=str(period_start), endDate=str(period_end),
            metrics="subscribersGained,subscribersLost"
        ).execute()

        resp_prev = self.yt_analytics.reports().query(
            ids=f"channel=={self.get_channel_id()}",
            startDate=str(prev_start), endDate=str(period_start),
            metrics="subscribersGained,subscribersLost"
        ).execute()

        gained_curr, lost_curr = parse_row(resp_curr)
        gained_prev, lost_prev = parse_row(resp_prev)
        net_curr = gained_curr - lost_curr
        net_prev = gained_prev - lost_prev

        return {
            "gained":          gained_curr,
            "lost":            lost_curr,
            "net":             net_curr,
            "vs_previous":     net_curr - net_prev,
            "trend":           "up" if net_curr >= net_prev else "down",
            "time_range_days": days,
            "range_label":     self._range_label(days),
        }

    # ── Main entry point ──────────────────────────────────────────────────────

    def fetch_all(self) -> dict:
        print("  📡 Fetching channel info...")
        channel = self.fetch_channel_info()

        result = {
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "channel":    channel,
            "metrics":    {}
        }

        fetchers = {
            "views_24hr":        self.fetch_views_24hr,
            "watch_time_24hr":   self.fetch_watch_time_24hr,
            "total_subscribers": self.fetch_total_subscribers,
            "latest_comments":   self.fetch_latest_comments,
            "top_video_today":   self.fetch_top_video_today,
            "subscriber_delta":  self.fetch_subscriber_delta,
        }

        for key, fn in fetchers.items():
            cfg = self.metrics_config.get(key, {})
            if not cfg.get("enabled", False):
                continue
            try:
                print(f"  📊 Fetching {key}...")
                result["metrics"][key] = {
                    "label": cfg.get("label", key),
                    "icon":  cfg.get("icon", "chart.bar"),
                    "data":  fn()
                }
            except Exception as e:
                result["metrics"][key] = {
                    "label": cfg.get("label", key),
                    "icon":  cfg.get("icon", "chart.bar"),
                    "error": str(e)
                }

        return result
