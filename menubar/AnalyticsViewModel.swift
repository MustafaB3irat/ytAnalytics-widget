// AnalyticsViewModel.swift
// Polls the local Python server and manages app-wide state.
// Also handles reading/writing settings via PATCH /settings.

import Foundation
import Combine

@MainActor
class AnalyticsViewModel: ObservableObject {

    // ── Analytics state ───────────────────────────────────────────────────────
    @Published var analytics: AnalyticsResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // ── Settings state (mirrors server config) ────────────────────────────────
    @Published var refreshIntervalMinutes: Int = 15
    @Published var metricToggles: [String: Bool] = [:]
    @Published var metricTimeRangeDays: [String: Int] = [:]  // key → days (nil keys = not applicable)
    @Published var isSavingSettings: Bool = false
    @Published var settingsSaved: Bool = false

    var onUpdate: (() -> Void)?

    // ── Internals ─────────────────────────────────────────────────────────────
    private let base = "http://localhost:8765"
    private var analyticsURL: URL { URL(string: "\(base)/analytics")! }
    private var settingsURL:  URL { URL(string: "\(base)/settings")! }
    private var refreshURL:   URL { URL(string: "\(base)/refresh")! }

    private var pollTimer: Timer?

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    func startPolling() {
        fetch()
        loadSettings()
        schedulePollTimer()
    }

    private func schedulePollTimer() {
        pollTimer?.invalidate()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchAsync() }
        }
    }

    // ── Fetch analytics ───────────────────────────────────────────────────────

    func fetch() {
        Task { await fetchAsync() }
    }

    func forceRefresh() {
        Task {
            _ = try? await URLSession.shared.data(from: refreshURL)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await fetchAsync()
        }
    }

    private func fetchAsync() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: analyticsURL)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            if http.statusCode == 202 {
                errorMessage = "Loading for the first time…"
                return
            }

            let decoded = try JSONDecoder().decode(AnalyticsResponse.self, from: data)
            analytics = decoded
            lastUpdated = Date()
            onUpdate?()

        } catch let e as URLError where e.code == .cannotConnectToHost || e.code == .networkConnectionLost {
            errorMessage = "Server offline — run: python server.py"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Settings ──────────────────────────────────────────────────────────────

    /// Load current settings from the server (called once at startup).
    func loadSettings() {
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: settingsURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            if let seconds = json["refresh_interval_seconds"] as? Int {
                refreshIntervalMinutes = max(5, seconds / 60)
            }
            if let metrics = json["metrics"] as? [String: [String: Any]] {
                var toggles:    [String: Bool] = [:]
                var timeRanges: [String: Int]  = [:]
                for (key, val) in metrics {
                    toggles[key] = val["enabled"] as? Bool ?? false
                    if let days = val["time_range_days"] as? Int {
                        timeRanges[key] = days
                    }
                }
                metricToggles       = toggles
                metricTimeRangeDays = timeRanges
            }
        }
    }

    /// Push updated settings to the server (saves to config.json + resets timer).
    func saveSettings() {
        Task {
            isSavingSettings = true
            defer { isSavingSettings = false }

            var body: [String: Any] = [
                "refresh_interval_seconds": refreshIntervalMinutes * 60
            ]

            // Build metrics patch (enabled + time_range_days)
            var metricsPatch: [String: [String: Any]] = [:]
            for (key, enabled) in metricToggles {
                var patch: [String: Any] = ["enabled": enabled]
                if let days = metricTimeRangeDays[key] {
                    patch["time_range_days"] = days
                }
                metricsPatch[key] = patch
            }
            if !metricsPatch.isEmpty {
                body["metrics"] = metricsPatch
            }

            guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

            var req = URLRequest(url: settingsURL)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = data

            guard let (_, response) = try? await URLSession.shared.data(for: req),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200
            else { return }

            // Re-schedule the poll timer with the new interval
            schedulePollTimer()

            // Flash "Saved ✓" in the UI
            settingsSaved = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            settingsSaved = false
        }
    }

    deinit {
        pollTimer?.invalidate()
    }
}
