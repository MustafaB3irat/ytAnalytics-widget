// ytAnalyticsApp.swift
// Menu bar app entry point — shows a YouTube icon in the menu bar
// with a live stats popover. No Dock icon.

import SwiftUI

@main
struct ytAnalyticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // No main window — menu bar only
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var analyticsVM: AnalyticsViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        let vm = AnalyticsViewModel()
        self.analyticsVM = vm

        // Status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "YouTube Analytics")
            button.imagePosition = .imageLeading
            button.title = " yt"
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(vm: vm)
        )
        self.popover = popover

        // Update menu bar title with live views
        vm.onUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarTitle(vm: vm)
            }
        }

        // Start fetching
        vm.startPolling()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func updateStatusBarTitle(vm: AnalyticsViewModel) {
        guard let button = statusItem?.button else { return }
        if let views = vm.analytics?.metrics.views24hr?.data?.value {
            button.title = " \(views.compactFormatted)"
        } else {
            button.title = " yt"
        }
    }
}
