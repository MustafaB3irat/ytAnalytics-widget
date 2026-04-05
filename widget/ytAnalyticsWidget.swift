// ytAnalyticsWidget.swift
// WidgetKit entry point — registers the widget with macOS

import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct ytAnalyticsWidget: Widget {
    let kind: String = "ytAnalyticsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnalyticsProvider()) { entry in
            AnalyticsWidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("YouTube Analytics")
        .description("Shows your channel's views, watch time, subscribers, and latest comments.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct ytAnalyticsWidgetBundle: WidgetBundle {
    var body: some Widget {
        ytAnalyticsWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    ytAnalyticsWidget()
} timeline: {
    AnalyticsEntry.placeholder
}

#Preview(as: .systemLarge) {
    ytAnalyticsWidget()
} timeline: {
    AnalyticsEntry.placeholder
}
