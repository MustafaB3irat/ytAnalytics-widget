// OnboardingView.swift
// First-run setup wizard shown in a dedicated window.
// Guides the user through installing Google credentials and signing in.

import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var server = ServerManager.shared
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            switch server.state {
            case .checking, .launching:
                SpinnerStep(message: "Starting up…")

            case .installing(let msg):
                SpinnerStep(message: msg)

            case .needsCredentials:
                CredentialsStep()

            case .waitingForAuth:
                SpinnerStep(
                    message: "Your browser opened for Google sign-in.\nComplete it and come back — this window will update automatically.",
                    showBrowserHint: true
                )

            case .ready:
                // Triggers onComplete via onChange below
                SpinnerStep(message: "Connected! Loading your stats…")

            case .error(let msg):
                ErrorStep(message: msg)
            }
        }
        .frame(width: 480, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: server.state) { newState in
            if newState == .ready { onComplete() }
        }
    }
}

// MARK: - Step: Spinner

private struct SpinnerStep: View {
    let message: String
    var showBrowserHint: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if showBrowserHint {
                Text("If the browser didn't open, check your Dock for a pending window.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .padding(40)
    }
}

// MARK: - Step: Credentials

private struct CredentialsStep: View {
    @ObservedObject private var server = ServerManager.shared
    @State private var isTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("Connect your YouTube channel")
                    .font(.system(size: 20, weight: .bold))
                Text("You need a free Google access key. Follow these steps:")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Steps
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    StepRow(number: "1", text: "Go to **console.cloud.google.com** → create a new project named `ytAnalytics`") {
                        openURL("https://console.cloud.google.com/projectcreate")
                    }
                    StepRow(number: "2", text: "Enable **YouTube Data API v3** and **YouTube Analytics API**") {
                        openURL("https://console.cloud.google.com/apis/library")
                    }
                    StepRow(number: "3", text: "Set up the **OAuth consent screen** (External, add your email as test user, add the 3 scopes listed in the README)") {
                        openURL("https://console.cloud.google.com/apis/credentials/consent")
                    }
                    StepRow(number: "4", text: "Create an **OAuth 2.0 Client ID** (Desktop app) and download the JSON file") {
                        openURL("https://console.cloud.google.com/apis/credentials")
                    }
                    StepRow(number: "5", text: "Drop the downloaded JSON file below ↓", isLast: true)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 180)

            Divider()

            // Drop zone
            VStack(spacing: 8) {
                DropZone(isTargeted: $isTargeted) { url in
                    handleDrop(url: url)
                }
                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
        }
    }

    private func handleDrop(url: URL) {
        errorMessage = nil
        do {
            try server.installCredentials(from: url)
            server.startAfterCredentials()
        } catch {
            errorMessage = "Couldn't read the file: \(error.localizedDescription)"
        }
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Step: Error

private struct ErrorStep: View {
    let message: String
    @ObservedObject private var server = ServerManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Setup failed")
                .font(.system(size: 18, weight: .bold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Try Again") { server.start() }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

// MARK: - Reusable: Step row

private struct StepRow: View {
    let number: String
    let text: String
    var isLast: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.red)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(text))
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button("Open in Browser →", action: action)
                        .font(.system(size: 11))
                        .buttonStyle(.link)
                }
            }
        }
    }
}

// MARK: - Reusable: Drop zone

private struct DropZone: View {
    @Binding var isTargeted: Bool
    var onDrop: (URL) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Color.red : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isTargeted ? Color.red.opacity(0.05) : Color.clear)
                )
                .frame(height: 72)

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundStyle(isTargeted ? .red : .secondary)
                Text(isTargeted ? "Release to install" : "Drop client_secret.json here")
                    .font(.system(size: 13))
                    .foregroundStyle(isTargeted ? .red : .secondary)
                Text("or")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                browseButton
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { onDrop(url) }
            }
            return true
        }
    }

    private var browseButton: some View {
        Button("Browse…") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                onDrop(url)
            }
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12))
    }
}
