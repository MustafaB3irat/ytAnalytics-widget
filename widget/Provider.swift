// Provider.swift
// WidgetKit timeline provider — fetches from the local Python server

import WidgetKit
import Foundation

// MARK: - Timeline Entry

struct AnalyticsEntry: TimelineEntry {
    let date: Date
    let analytics: AnalyticsResponse?
    let error: String?
    let isPlaceholder: Bool

    static var placeholder: AnalyticsEntry {
        AnalyticsEntry(
            date: Date(),
            analytics: LoadingEntry.placeholder,
            error: nil,
            isPlaceholder: true
        )
    }
}

// MARK: - Provider

struct AnalyticsProvider: TimelineProvider {

    // Server URL — must match config.json port
    private let serverURL = URL(string: "http://localhost:8765/analytics")!

    // Placeholder while widget loads (shown in gallery)
    func placeholder(in context: Context) -> AnalyticsEntry {
        .placeholder
    }

    // Snapshot for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (AnalyticsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            fetchAnalytics { entry in completion(entry) }
        }
    }

    // Full timeline — refreshes every 15 minutes
    func getTimeline(in context: Context, completion: @escaping (Timeline<AnalyticsEntry>) -> Void) {
        fetchAnalytics { entry in
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    // MARK: - Fetch

    private func fetchAnalytics(completion: @escaping (AnalyticsEntry) -> Void) {
        let task = URLSession.shared.dataTask(with: serverURL) { data, response, error in
            if let error = error {
                // Server not running — show error state
                completion(AnalyticsEntry(
                    date: Date(),
                    analytics: nil,
                    error: "Server offline: \(error.localizedDescription)",
                    isPlaceholder: false
                ))
                return
            }

            guard let data = data else {
                completion(AnalyticsEntry(date: Date(), analytics: nil, error: "No data", isPlaceholder: false))
                return
            }

            do {
                let analytics = try JSONDecoder().decode(AnalyticsResponse.self, from: data)
                completion(AnalyticsEntry(date: Date(), analytics: analytics, error: nil, isPlaceholder: false))
            } catch {
                completion(AnalyticsEntry(
                    date: Date(),
                    analytics: nil,
                    error: "Parse error: \(error.localizedDescription)",
                    isPlaceholder: false
                ))
            }
        }
        task.resume()
    }
}
