// WidgetView.swift
// Native macOS Notification Centre widget — Small / Medium / Large
// All sizes show a channel card header with avatar + name.

import SwiftUI
import WidgetKit

// MARK: - Root dispatcher

struct AnalyticsWidgetView: View {
    var entry: AnalyticsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let error = entry.error {
            ErrorView(message: error)
        } else if let analytics = entry.analytics {
            switch family {
            case .systemSmall:  SmallWidgetView(analytics: analytics)
            case .systemMedium: MediumWidgetView(analytics: analytics)
            case .systemLarge:  LargeWidgetView(analytics: analytics)
            default:            MediumWidgetView(analytics: analytics)
            }
        } else {
            LoadingView()
        }
    }
}

// MARK: - Channel Card (shared header across all sizes)

struct ChannelCard: View {
    let channel: ChannelInfo
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            // Avatar
            Group {
                if !channel.avatarUrl.isEmpty {
                    RemoteImage(
                        url: channel.avatarUrl,
                        placeholder: Image(systemName: "person.circle.fill")
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.red.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.name)
                    .font(.system(size: compact ? 11 : 13, weight: .bold))
                    .lineLimit(1)
                if !channel.handle.isEmpty {
                    Text(channel.handle)
                        .font(.system(size: compact ? 9 : 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // YT logo badge
            Image(systemName: "play.rectangle.fill")
                .foregroundColor(.red)
                .font(.system(size: compact ? 12 : 14))
        }
    }
}

// MARK: - Small (2×2)

struct SmallWidgetView: View {
    let analytics: AnalyticsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ChannelCard(channel: analytics.channel, compact: true)

            Divider()

            if let views = analytics.metrics.views24hr?.data {
                StatRow(icon: "eye.fill", value: views.value.compactFormatted,
                        label: "views (\(views.rangeLabel))", color: .blue)
            }
            if let subs = analytics.metrics.totalSubscribers?.data {
                StatRow(icon: "person.2.fill", value: subs.value.compactFormatted,
                        label: "subscribers",  color: .purple)
            }
            if let delta = analytics.metrics.subscriberDelta?.data {
                let isPos = delta.net >= 0
                StatRow(
                    icon: isPos ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    value: (isPos ? "+" : "") + "\(delta.net)",
                    label: delta.rangeLabel,
                    color: isPos ? .green : .red
                )
            }

            Spacer()

            Text(relativeTime(from: analytics.fetchedAt))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(10)
    }
}

// MARK: - Medium (4×2)

struct MediumWidgetView: View {
    let analytics: AnalyticsResponse

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChannelCard(channel: analytics.channel, compact: false)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            HStack(spacing: 0) {
                // Left — stats
                VStack(alignment: .leading, spacing: 5) {
                    if let views = analytics.metrics.views24hr?.data {
                        StatRow(icon: "eye.fill",      value: views.value.compactFormatted,
                                label: "views (\(views.rangeLabel))",  color: .blue)
                    }
                    if let wt = analytics.metrics.watchTime24hr?.data {
                        StatRow(icon: "clock.fill",    value: "\(wt.hours)h",
                                label: "watch (\(wt.rangeLabel))",   color: .orange)
                    }
                    if let subs = analytics.metrics.totalSubscribers?.data {
                        StatRow(icon: "person.2.fill", value: subs.value.compactFormatted,
                                label: "subscribers",  color: .purple)
                    }
                    if let delta = analytics.metrics.subscriberDelta?.data {
                        let isPos = delta.net >= 0
                        StatRow(
                            icon: isPos ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                            value: (isPos ? "+" : "") + "\(delta.net)",
                            label: "subs (\(delta.rangeLabel))",
                            color: isPos ? .green : .red
                        )
                    }
                    Spacer()
                    Text(relativeTime(from: analytics.fetchedAt))
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().padding(.vertical, 8)

                // Right — top video + latest comment
                VStack(alignment: .leading, spacing: 6) {
                    if let top = analytics.metrics.topVideoToday?.data {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Top today", systemImage: "star.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.yellow)
                            Text(top.title)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2)
                            Text("\(top.views.compactFormatted) views")
                                .font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }
                    Divider()
                    if let comment = analytics.metrics.latestComments?.data?.comments.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Latest", systemImage: "bubble.left.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                            Text(comment.author)
                                .font(.system(size: 9, weight: .semibold))
                            Text(comment.text)
                                .font(.system(size: 9)).foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Large (4×4)

struct LargeWidgetView: View {
    let analytics: AnalyticsResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Channel card header
            ChannelCard(channel: analytics.channel)
            Divider()

            // Stats row
            HStack(spacing: 12) {
                if let views = analytics.metrics.views24hr?.data {
                    BigStat(value: views.value.compactFormatted,
                            label: "Views (\(views.rangeLabel))", icon: "eye.fill", color: .blue)
                }
                if let wt = analytics.metrics.watchTime24hr?.data {
                    BigStat(value: "\(wt.hours)h",
                            label: "Watch (\(wt.rangeLabel))", icon: "clock.fill", color: .orange)
                }
                if let subs = analytics.metrics.totalSubscribers?.data {
                    BigStat(value: subs.value.compactFormatted,
                            label: "Subscribers", icon: "person.2.fill", color: .purple)
                }
            }

            // Subscriber delta pill
            if let delta = analytics.metrics.subscriberDelta?.data {
                let isPos = delta.net >= 0
                HStack(spacing: 6) {
                    Image(systemName: isPos ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(isPos ? .green : .red)
                    Text(isPos ? "+\(delta.net) subs (\(delta.rangeLabel))" : "\(delta.net) subs (\(delta.rangeLabel))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isPos ? .green : .red)
                    Text("(\(delta.vsPrevious >= 0 ? "+" : "")\(delta.vsPrevious) vs prev)")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((isPos ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Top video
            if let top = analytics.metrics.topVideoToday?.data, top.videoId != nil {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Top Video Today", systemImage: "star.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.yellow)
                    Text(top.title)
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text("\(top.views.compactFormatted) views · \(top.watchTimeMinutes / 60)h \(top.watchTimeMinutes % 60)m")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }

            Divider()

            // Comments
            if let cd = analytics.metrics.latestComments?.data, !cd.comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Latest Comments", systemImage: "bubble.left.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                    ForEach(cd.comments.prefix(3)) { c in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary).font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.author).font(.system(size: 10, weight: .semibold))
                                Text(c.text).font(.system(size: 10))
                                    .foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer()

            Text(relativeTime(from: analytics.fetchedAt))
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(14)
    }
}

// MARK: - Reusable components

struct StatRow: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color)
                .font(.system(size: 10)).frame(width: 14)
            Text(value).font(.system(size: 12, weight: .semibold))
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

struct BigStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 16))
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange).font(.system(size: 24))
            Text("Server Offline").font(.system(size: 12, weight: .semibold))
            Text("Run: python server.py").font(.system(size: 10)).foregroundColor(.secondary)
        }
        .padding()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading…").font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}

// MARK: - Time helper

func relativeTime(from isoString: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = f.date(from: isoString) else { return "just now" }
    let m = Int(-date.timeIntervalSinceNow / 60)
    if m < 1  { return "just now" }
    if m < 60 { return "\(m)m ago" }
    return "\(m / 60)h ago"
}
