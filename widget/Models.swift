// Models.swift
// Shared data models — used by both the Widget and Menu Bar app targets.
// Matches the JSON structure returned by the Python server.

import Foundation
import SwiftUI

// MARK: - Top-level response

struct AnalyticsResponse: Codable {
    let fetchedAt: String
    let channel: ChannelInfo
    let metrics: MetricsPayload

    enum CodingKeys: String, CodingKey {
        case fetchedAt = "fetched_at"
        case channel
        case metrics
    }
}

// MARK: - Channel info (always present, shown as header card)

struct ChannelInfo: Codable {
    let id: String
    let name: String
    let handle: String
    let avatarUrl: String
    let description: String
    let country: String
    let subscriberCount: Int
    let videoCount: Int
    let viewCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, handle, description, country
        case avatarUrl       = "avatar_url"
        case subscriberCount = "subscriber_count"
        case videoCount      = "video_count"
        case viewCount       = "view_count"
    }

    var youtubeURL: URL? {
        let h = handle.isEmpty ? id : handle
        return URL(string: "https://youtube.com/\(h)")
    }
}

// MARK: - Metrics payload

struct MetricsPayload: Codable {
    let views24hr:        MetricWrapper<ViewsData>?
    let watchTime24hr:    MetricWrapper<WatchTimeData>?
    let totalSubscribers: MetricWrapper<SubscribersData>?
    let latestComments:   MetricWrapper<CommentsData>?
    let topVideoToday:    MetricWrapper<TopVideoData>?
    let subscriberDelta:  MetricWrapper<SubscriberDeltaData>?

    enum CodingKeys: String, CodingKey {
        case views24hr        = "views_24hr"
        case watchTime24hr    = "watch_time_24hr"
        case totalSubscribers = "total_subscribers"
        case latestComments   = "latest_comments"
        case topVideoToday    = "top_video_today"
        case subscriberDelta  = "subscriber_delta"
    }
}

struct MetricWrapper<T: Codable>: Codable {
    let label: String
    let icon: String
    let data: T?
    let error: String?
}

// MARK: - Individual metric data

struct ViewsData: Codable {
    let value: Int
    let unit: String
    let timeRangeDays: Int
    let rangeLabel: String

    enum CodingKeys: String, CodingKey {
        case value, unit
        case timeRangeDays = "time_range_days"
        case rangeLabel    = "range_label"
    }
}

struct WatchTimeData: Codable {
    let value: Int
    let hours: Double
    let unit: String
    let timeRangeDays: Int
    let rangeLabel: String

    enum CodingKeys: String, CodingKey {
        case value, hours, unit
        case timeRangeDays = "time_range_days"
        case rangeLabel    = "range_label"
    }
}

struct SubscribersData: Codable {
    let value: Int
    let unit: String
}

struct CommentsData: Codable {
    let comments: [CommentItem]
    let count: Int
}

struct CommentItem: Codable, Identifiable {
    var id: String { "\(author)-\(publishedAt)-\(videoId)" }
    let author: String
    let text: String
    let publishedAt: String
    let videoId: String
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case author, text, likeCount
        case publishedAt = "published_at"
        case videoId     = "video_id"
    }
}

struct TopVideoData: Codable {
    let videoId: String?
    let title: String
    let url: String?
    let thumbnailUrl: String?
    let views: Int
    let watchTimeMinutes: Int
    let timeRangeDays: Int
    let rangeLabel: String

    enum CodingKeys: String, CodingKey {
        case title, url, views
        case videoId          = "video_id"
        case thumbnailUrl     = "thumbnail_url"
        case watchTimeMinutes = "watch_time_minutes"
        case timeRangeDays    = "time_range_days"
        case rangeLabel       = "range_label"
    }
}

struct SubscriberDeltaData: Codable {
    let gained: Int
    let lost: Int
    let net: Int
    let vsPrevious: Int
    let trend: String
    let timeRangeDays: Int
    let rangeLabel: String

    enum CodingKeys: String, CodingKey {
        case gained, lost, net, trend
        case vsPrevious    = "vs_previous"
        case timeRangeDays = "time_range_days"
        case rangeLabel    = "range_label"
    }
}

// MARK: - Int formatting

extension Int {
    /// 12400 → "12.4K", 1_200_000 → "1.2M"
    var compactFormatted: String {
        switch self {
        case 0..<1_000:           return "\(self)"
        case 1_000..<10_000:      return String(format: "%.1fK", Double(self) / 1_000)
        case 10_000..<1_000_000:  return "\(self / 1_000)K"
        default:                  return String(format: "%.1fM", Double(self) / 1_000_000)
        }
    }
}

// MARK: - Async remote image (widget + menu bar safe)

/// Fetches a remote image URL and caches it in memory.
/// Works in both WidgetKit (no async/await) and regular SwiftUI contexts.
class RemoteImageCache {
    static let shared = RemoteImageCache()
    private var cache: [String: Image] = [:]

    func image(for urlString: String) -> Image? {
        cache[urlString]
    }

    func store(_ image: Image, for urlString: String) {
        cache[urlString] = image
    }
}

struct RemoteImage: View {
    let url: String
    let placeholder: Image

    @State private var image: Image?

    var body: some View {
        Group {
            if let img = image ?? RemoteImageCache.shared.image(for: url) {
                img.resizable()
            } else {
                placeholder.resizable()
                    .task { await load() }
            }
        }
    }

    private func load() async {
        guard let u = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: u),
              let ns = NSImage(data: data) else { return }
        let img = Image(nsImage: ns)
        RemoteImageCache.shared.store(img, for: url)
        image = img
    }
}

// MARK: - Placeholder / preview data

struct LoadingEntry {
    static let placeholder = AnalyticsResponse(
        fetchedAt: ISO8601DateFormatter().string(from: Date()),
        channel: ChannelInfo(
            id: "UCxxxxxx",
            name: "Mustafa B'irat",
            handle: "@MustafaBirat",
            avatarUrl: "",
            description: "Arabic travel & filmmaking channel",
            country: "GB",
            subscriberCount: 8_430,
            videoCount: 42,
            viewCount: 540_000
        ),
        metrics: MetricsPayload(
            views24hr: MetricWrapper(
                label: "Views (24h)", icon: "eye",
                data: ViewsData(value: 12_400, unit: "views", timeRangeDays: 1, rangeLabel: "24h"), error: nil),
            watchTime24hr: MetricWrapper(
                label: "Watch Time (24h)", icon: "clock",
                data: WatchTimeData(value: 3120, hours: 52.0, unit: "minutes", timeRangeDays: 1, rangeLabel: "24h"), error: nil),
            totalSubscribers: MetricWrapper(
                label: "Subscribers", icon: "person.2",
                data: SubscribersData(value: 8_430, unit: "subscribers"), error: nil),
            latestComments: MetricWrapper(
                label: "Latest Comments", icon: "bubble.left",
                data: CommentsData(comments: [
                    CommentItem(author: "Ahmed K.", text: "Mashallah, amazing video! 🎥",
                                publishedAt: "2024-01-01T10:00:00Z", videoId: "v1", likeCount: 3),
                    CommentItem(author: "Sara M.", text: "Can you do a hiking video next?",
                                publishedAt: "2024-01-01T09:00:00Z", videoId: "v2", likeCount: 1)
                ], count: 2), error: nil),
            topVideoToday: MetricWrapper(
                label: "Top Video Today", icon: "star",
                data: TopVideoData(
                    videoId: "dQw4w9WgXcQ",
                    title: "Switzerland Camping Adventure 🏕",
                    url: "https://youtu.be/dQw4w9WgXcQ",
                    thumbnailUrl: nil,
                    views: 4200,
                    watchTimeMinutes: 840,
                    timeRangeDays: 1,
                    rangeLabel: "24h"), error: nil),
            subscriberDelta: MetricWrapper(
                label: "Subscriber Change", icon: "arrow.up.person",
                data: SubscriberDeltaData(gained: 14, lost: 2, net: 12,
                                          vsPrevious: 5, trend: "up",
                                          timeRangeDays: 1, rangeLabel: "24h"), error: nil)
        )
    )
}
