// ytAnalyticsApp.swift
// Menu bar app entry point — shows a YouTube icon in the menu bar
// with a live stats popover. On first run, shows an onboarding window.

import SwiftUI
import Combine

@main
struct ytAnalyticsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var analyticsVM: AnalyticsViewModel?
    var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        let server = ServerManager.shared
        server.start()

        server.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.handleServerState(state) }
            .store(in: &cancellables)
    }

    // MARK: - Server state handling

    private func handleServerState(_ state: ServerManager.State) {
        switch state {
        case .needsCredentials, .installing, .waitingForAuth, .error:
            showOnboarding()
        case .ready:
            closeOnboarding()
            analyticsVM?.startPolling()
        default:
            break
        }
    }

    // MARK: - Onboarding window

    private func showOnboarding() {
        guard onboardingWindow == nil else { return }

        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "YouTube Analytics — Setup"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: OnboardingView { [weak self] in self?.closeOnboarding() }
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        analyticsVM?.startPolling()
    }

    // MARK: - Menu bar setup

    private func setupMenuBar() {
        let vm = AnalyticsViewModel()
        analyticsVM = vm

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "play.rectangle.fill",
                                   accessibilityDescription: "YouTube Analytics")
            button.imagePosition = .imageLeft
            button.attributedTitle = Self.dotTitle(color: .systemGray)
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(vm: vm))
        self.popover = popover

        vm.onUpdate = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let vm = self.analyticsVM else { return }
                self.updateStatusBarTitle(vm: vm)
            }
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover {
            if popover.isShown { popover.performClose(nil) }
            else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func updateStatusBarTitle(vm: AnalyticsViewModel) {
        guard let button = statusItem?.button else { return }
        let color: NSColor = vm.errorMessage != nil ? .systemRed
                           : vm.analytics    != nil ? .systemGreen
                           : .systemGray
        button.attributedTitle = Self.dotTitle(color: color)
    }

    private static func dotTitle(color: NSColor) -> NSAttributedString {
        NSAttributedString(string: " ●", attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 9)
        ])
    }
}
