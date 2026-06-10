import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Окно настроек: автозапуск, уведомления, импорт/экспорт, «О программе».
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updater = UpdateService.shared
    @Environment(\.openWindow) private var openWindow

    @AppStorage("updateAutoCheckEnabled") private var autoCheckEnabled = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var message: String?
    @State private var isError = false

    private var updateStatusText: String {
        switch updater.state {
        case .idle: return ""
        case .checking: return "Checking…"
        case .available(let release): return "Update available: \(release.version)"
        case .downloading: return "Downloading…"
        case .installing: return "Installing…"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLogin.setEnabled(newValue)
                        } catch {
                            show(error.localizedDescription, error: true)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }

                Toggle("Renewal notifications", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, isOn in
                        Task {
                            if isOn { await NotificationScheduler.requestAuthorization() }
                            await NotificationScheduler.rescheduleFromStore()
                        }
                    }

                Picker("Sort list by", selection: $settings.sortOrder) {
                    ForEach(SubscriptionSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Toggle("Group by currency", isOn: $settings.groupByCurrency)

                Toggle("Show all subscriptions", isOn: $settings.showAllSubscriptions)
            }

            Section("Data") {
                HStack {
                    Button("Export…") { exportData() }
                    Button("Import…") { importData() }
                    Spacer()
                }
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckEnabled)

                HStack {
                    Button("Check for Updates") {
                        UpdateService.shared.checkForUpdate(manual: true)
                    }
                    .disabled(updater.isBusy)
                    Spacer()
                    if !updateStatusText.isEmpty {
                        Text(updateStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("About Subscriptions Tracker") {
                    openWindow(id: "about")
                    NSApp.activate()
                }
            } footer: {
                Text("Settings are stored locally on this Mac.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .navigationTitle("Settings")
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }

    private func show(_ text: String, error: Bool) {
        message = text
        isError = error
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "subscriptions.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try SubscriptionStore.exportJSON()
            try data.write(to: url)
            show("Exported to \(url.lastPathComponent).", error: false)
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let result = try SubscriptionStore.importJSON(data)
            if result.skipped > 0 {
                show("Imported \(result.added), skipped \(result.skipped) duplicate(s).", error: false)
            } else {
                show("Imported \(result.added) subscription(s).", error: false)
            }
            Task { await NotificationScheduler.rescheduleFromStore() }
        } catch {
            show(error.localizedDescription, error: true)
        }
    }
}
