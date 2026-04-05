// MenuBarView.swift
// Menu bar popover with two tabs: Analytics and Settings.

import SwiftUI

// MARK: - Root view with tab switcher

struct MenuBarView: View {
    @ObservedObject var vm: AnalyticsViewModel
    @State private var selectedTab: Tab = .analytics

    enum Tab { case analytics, settings }

    var body: some View {
        VStack(spacing: 0) {
            // Header + tab bar
            VStack(spacing: 0) {
                HeaderBar(vm: vm, selectedTab: $selectedTab)
                TabBar(selectedTab: $selectedTab)
            }

            // Content
            Group {
                switch selectedTab {
                case .analytics: AnalyticsTab(vm: vm)
                case .settings:  SettingsTab(vm: vm)
                }
            }

            FooterBar(vm: vm, selectedTab: selectedTab)
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Header bar

struct HeaderBar: View {
    @ObservedObject var vm: AnalyticsViewModel
    @Binding var selectedTab: MenuBarView.Tab

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
            Text("YouTube Analytics")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if vm.isLoading || vm.isForceRefreshing {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.6)
                    Text("Loading…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            if selectedTab == .analytics {
                Button(action: { vm.forceRefresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(vm.isForceRefreshing)
                .help("Force refresh from YouTube")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tab bar

struct TabBar: View {
    @Binding var selectedTab: MenuBarView.Tab

    var body: some View {
        HStack(spacing: 0) {
            TabButton(label: "Analytics", icon: "chart.bar.fill",
                      tab: .analytics, selectedTab: $selectedTab)
            TabButton(label: "Settings",  icon: "gearshape.fill",
                      tab: .settings,  selectedTab: $selectedTab)
        }
        .background(Color(NSColor.controlBackgroundColor))
        Divider()
    }
}

struct TabButton: View {
    let label: String
    let icon: String
    let tab: MenuBarView.Tab
    @Binding var selectedTab: MenuBarView.Tab

    var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .primary : .secondary)
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .red : .clear),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analytics tab

struct AnalyticsTab: View {
    @ObservedObject var vm: AnalyticsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = vm.errorMessage {
                    ErrorCard(message: error)
                } else if let analytics = vm.analytics {
                    ChannelHeaderCard(channel: analytics.channel)
                    Divider()
                    StatsGrid(analytics: analytics)
                    SubscriberDeltaCard(analytics: analytics)
                    TopVideoCard(analytics: analytics)
                    CommentsCard(analytics: analytics)
                } else {
                    LoadingCard()
                }
            }
            .padding(14)
        }
        .frame(height: 430)
    }
}

// MARK: - Settings tab

struct SettingsTab: View {
    @ObservedObject var vm: AnalyticsViewModel

    // Picker options: (label, minutes)
    private let intervalOptions: [(String, Int)] = [
        ("5 minutes",  5),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour",     60),
        ("2 hours",    120),
        ("6 hours",    360),
    ]

    // Builds a human-readable range suffix from the configured days value.
    private func rangeSuffix(for key: String) -> String {
        guard let days = vm.metricTimeRangeDays[key] else { return "" }
        return days == 1 ? " (24h)" : " (\(days)d)"
    }

    // Human-readable metric labels — reactive to current time range settings.
    private var metricLabels: [(key: String, label: String)] {
        [
            ("views_24hr",        "Views\(rangeSuffix(for: "views_24hr"))"),
            ("watch_time_24hr",   "Watch Time\(rangeSuffix(for: "watch_time_24hr"))"),
            ("total_subscribers", "Total Subscribers"),
            ("subscriber_delta",  "Subscriber Change\(rangeSuffix(for: "subscriber_delta"))"),
            ("top_video_today",   "Top Video Today\(rangeSuffix(for: "top_video_today"))"),
            ("latest_comments",   "Latest Comments"),
        ]
    }

    // Metrics that support a configurable time range
    private let timeRangeMetrics: [(key: String, label: String)] = [
        ("views_24hr",       "Views"),
        ("watch_time_24hr",  "Watch Time"),
        ("subscriber_delta", "Subscriber Change"),
        ("top_video_today",  "Top Video"),
    ]

    // Only items whose key exists in the VM dictionaries (filtered once per render)
    private var visibleMetricItems: [(key: String, label: String)] {
        metricLabels.filter { vm.metricToggles[$0.key] != nil }
    }

    private var visibleTimeRangeItems: [(key: String, label: String)] {
        timeRangeMetrics.filter { vm.metricTimeRangeDays[$0.key] != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Refresh interval ─────────────────────────────────────────
                SettingsSection(title: "Refresh Interval", icon: "clock.arrow.2.circlepath") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How often to pull new data from YouTube.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Picker("Refresh Interval", selection: $vm.refreshIntervalMinutes) {
                            ForEach(intervalOptions, id: \.1) { label, minutes in
                                Text(label).tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Divider()

                // ── Metrics toggles ──────────────────────────────────────────
                SettingsSection(title: "Visible Metrics", icon: "chart.bar") {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleMetricItems.enumerated()), id: \.element.key) { index, item in
                            MetricToggleRow(
                                label: item.label,
                                isOn: Binding(
                                    get: { vm.metricToggles[item.key] ?? false },
                                    set: { vm.metricToggles[item.key] = $0 }
                                ),
                                showDivider: index < visibleMetricItems.count - 1
                            )
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                Divider()

                // ── Time ranges ───────────────────────────────────────────────
                SettingsSection(title: "Time Ranges", icon: "calendar") {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleTimeRangeItems.enumerated()), id: \.element.key) { index, item in
                            TimeRangeRow(
                                label: item.label,
                                days: Binding(
                                    get: { vm.metricTimeRangeDays[item.key] ?? 1 },
                                    set: { vm.metricTimeRangeDays[item.key] = $0 }
                                ),
                                showDivider: index < visibleTimeRangeItems.count - 1
                            )
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                Divider()

                // ── Info note ─────────────────────────────────────────────────
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Settings are saved to config.json and take effect immediately — no server restart needed.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // ── Save button ───────────────────────────────────────────────
                VStack(spacing: 8) {
                    if vm.settingsSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    Button(action: { vm.saveSettings() }) {
                        HStack(spacing: 6) {
                            if vm.isSavingSettings {
                                ProgressView().scaleEffect(0.7)
                            }
                            Text(vm.isSavingSettings ? "Saving…" : "Save Settings")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(vm.hasUnsavedChanges ? Color.red : Color(NSColor.separatorColor))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!vm.hasUnsavedChanges || vm.isSavingSettings)
                }
            }
            .padding(14)
        }
        .frame(height: 430)
        .animation(.easeInOut(duration: 0.2), value: vm.settingsSaved)
    }
}

// MARK: - Settings sub-components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            content()
        }
    }
}

struct MetricToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var showDivider: Bool = true

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if showDivider { Divider() }
        }
    }
}

struct TimeRangeRow: View {
    let label: String
    @Binding var days: Int
    var showDivider: Bool = true

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Stepper(
                value: $days,
                in: 1...90,
                step: 1
            ) {
                Text("\(days)d")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if showDivider { Divider() }
        }
    }
}

// MARK: - Channel header card

struct ChannelHeaderCard: View {
    let channel: ChannelInfo

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if !channel.avatarUrl.isEmpty {
                    RemoteImage(url: channel.avatarUrl,
                                placeholder: Image(systemName: "person.circle.fill"))
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable().foregroundColor(.red.opacity(0.7))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name)
                    .font(.system(size: 14, weight: .bold)).lineLimit(1)
                if !channel.handle.isEmpty {
                    Text(channel.handle)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "play.rectangle").font(.system(size: 10))
                        Text(channel.videoCount.compactFormatted).font(.system(size: 10))
                    }.foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "eye").font(.system(size: 10))
                        Text(channel.viewCount.compactFormatted).font(.system(size: 10))
                    }.foregroundColor(.secondary)
                }
            }

            Spacer()

            if let url = channel.youtubeURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 16)).foregroundColor(.red)
                }
                .help("Open channel on YouTube")
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Stats grid

struct StatsGrid: View {
    let analytics: AnalyticsResponse
    var body: some View {
        HStack(spacing: 10) {
            if let v = analytics.metrics.views24hr?.data {
                StatCard(icon: "eye.fill", color: .blue,
                         value: v.value.compactFormatted, label: "Views (\(v.rangeLabel))")
            }
            if let wt = analytics.metrics.watchTime24hr?.data {
                StatCard(icon: "clock.fill", color: .orange,
                         value: "\(wt.hours.trimmedDecimal)h", label: "Watch Time (\(wt.rangeLabel))")
            }
            if let s = analytics.metrics.totalSubscribers?.data {
                StatCard(icon: "person.2.fill", color: .purple,
                         value: s.value.compactFormatted, label: "Subscribers")
            }
        }
    }
}

struct StatCard: View {
    let icon: String; let color: Color; let value: String; let label: String
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.12)).cornerRadius(10)
    }
}

// MARK: - Subscriber delta

struct SubscriberDeltaCard: View {
    let analytics: AnalyticsResponse
    var body: some View {
        guard let delta = analytics.metrics.subscriberDelta?.data,
              delta.gained > 0 || delta.lost > 0
        else { return AnyView(EmptyView()) }
        let isPos = delta.net >= 0
        let color: Color = isPos ? .green : .red
        let vsSign = delta.vsPrevious >= 0 ? "+" : ""
        return AnyView(
            HStack(spacing: 12) {
                Image(systemName: isPos ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(color).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(isPos ? "+\(delta.net)" : "\(delta.net)")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(color)
                        Text("subscribers (\(delta.rangeLabel))")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Text("\(vsSign)\(delta.vsPrevious) vs previous \(delta.rangeLabel) · \(delta.gained) gained, \(delta.lost) lost")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(color.opacity(0.08)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Top video

struct TopVideoCard: View {
    let analytics: AnalyticsResponse
    var body: some View {
        guard let top = analytics.metrics.topVideoToday?.data, top.videoId != nil else {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Label("Top Video Today", systemImage: "star.fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.yellow)
                HStack(alignment: .top, spacing: 10) {
                    if let thumbURL = top.thumbnailUrl {
                        RemoteImage(url: thumbURL, placeholder: Image(systemName: "film"))
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 72, height: 40)
                            .cornerRadius(6).clipped()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(top.title)
                            .font(.system(size: 12, weight: .medium)).lineLimit(2)
                        HStack(spacing: 8) {
                            Label(top.views.compactFormatted, systemImage: "eye")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                            Label("\(top.watchTimeMinutes / 60)h \(top.watchTimeMinutes % 60)m",
                                  systemImage: "clock")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let urlStr = top.url, let link = URL(string: urlStr) {
                        Link("Open ↗", destination: link).font(.system(size: 10))
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor)).cornerRadius(10)
        )
    }
}

// MARK: - Comments

struct CommentsCard: View {
    let analytics: AnalyticsResponse
    var body: some View {
        guard let cd = analytics.metrics.latestComments?.data,
              !cd.comments.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label("Latest Comments", systemImage: "bubble.left.fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                ForEach(cd.comments) { c in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.author).font(.system(size: 11, weight: .semibold))
                            Text(c.text).font(.system(size: 11))
                                .foregroundColor(.secondary).lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if c.likeCount > 0 {
                            Label("\(c.likeCount)", systemImage: "hand.thumbsup")
                                .font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }
                    if c.id != cd.comments.last?.id { Divider() }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor)).cornerRadius(10)
        )
    }
}

// MARK: - Error / Loading

struct ErrorCard: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Error").font(.system(size: 12, weight: .semibold))
                Text(message).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1)).cornerRadius(10)
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Connecting to server…").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(30)
    }
}

// MARK: - Footer

struct FooterBar: View {
    @ObservedObject var vm: AnalyticsViewModel
    let selectedTab: MenuBarView.Tab
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private func minutesLabel(from date: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60)h ago"
    }

    var body: some View {
        Divider()
        HStack {
            if selectedTab == .analytics {
                if let updated = vm.lastUpdated {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Text("Updated \(minutesLabel(from: updated))")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .onReceive(ticker) { now = $0 }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                    Text("Refresh: every \(vm.refreshIntervalMinutes) min")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
