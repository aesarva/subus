import AppKit
import Observation
import OSLog
import SubusCore
import SwiftUI

@MainActor @Observable
final class LoginItemModel {
    private(set) var state = LoginItem.state
    private(set) var failed = false
    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "ui")

    func refresh() { state = LoginItem.state }

    func set(_ on: Bool) {
        failed = false
        do { try LoginItem.setEnabled(on) } catch {
            failed = true
            log.error("Open at login failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }
}

struct GeneralTab: View {
    let model: AppModel
    let updates: UpdateController
    @State private var login = LoginItemModel()
    @State private var language = LanguageModel()

    var body: some View {
        Form {
            LabeledContent("Base currency") {
                CurrencyPicker(selection: Binding(get: { model.settings.baseCurrency },
                                                  set: { value in model.update { $0.baseCurrency = value } }),
                               accessibilityLabel: String(localized: "Base currency"))
            }

            Section {
                Toggle("Open at login", isOn: Binding(get: { login.state == .enabled }, set: { login.set($0) }))
                    .disabled(login.state == .unavailable)
                if login.failed {
                    Text("Couldn't change Open at login.").font(.callout).foregroundStyle(.red)
                }
                switch login.state {
                case .requiresApproval:
                    HStack {
                        Text("Allow Subus in Login Items.").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items Settings") { LoginItem.openSystemSettings() }
                    }
                case .unavailable:
                    Text("Open at login isn't available for this copy of Subus. Move it to the Applications folder.")
                        .font(.callout).foregroundStyle(.secondary)
                case .enabled, .disabled:
                    EmptyView()
                }
            }

            Section {
                Picker("Language", selection: $language.selection) {
                    ForEach(LanguageSetting.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if language.restartFailed {
                    Text("Couldn't restart Subus. Quit and open it again.").font(.callout).foregroundStyle(.red)
                }
                if language.needsRestart {
                    HStack {
                        Text("Subus restarts to switch the language.").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { language.restart() }
                    }
                }
            }

            Toggle("Show days until next charge in the menu bar",
                   isOn: Binding(get: { model.settings.showMenuBarCounter },
                                 set: { value in model.update { $0.showMenuBarCounter = value } }))

            UpdatesSection(updates: updates)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onChange(of: language.selection) { _, value in model.update { $0.language = value } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
        .onAppear { login.refresh() }
    }
}

/// The version, automatic checks, and a check on demand with its result under it.
struct UpdatesSection: View {
    let updates: UpdateController

    var body: some View {
        Section {
            Toggle("Check for updates automatically",
                   isOn: Binding(get: { updates.automaticallyChecks }, set: { updates.automaticallyChecks = $0 }))
            LabeledContent("Version \(updates.currentVersion) (\(updates.currentBuild))") {
                // A found version installs right from here, without closing Settings.
                if case .available = updates.state {
                    Button("Install and Relaunch") { updates.install() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Check Now") { updates.checkNow() }
                        .disabled(isBusy || !updates.canCheckNow)
                }
            }
            .monospacedDigit()
            if let status {
                Text(verbatim: status).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// "Check Now" is off while an update is under way and when Subus runs from a disk image.
    private var isBusy: Bool {
        switch updates.state {
        case .checking, .downloading, .installing, .needsMove: true
        default: false
        }
    }

    private var status: String? {
        switch updates.state {
        case .checking: String(localized: "Checking for updates…")
        case .upToDate: String(localized: "Subus is up to date.")
        case .available(let version, _): String(localized: "Version \(version) is available")
        case .failed(let message): String(localized: "Couldn't update: \(message)")
        case .needsMove: String(localized: "Move Subus to Applications to get updates.")
        case .downloading(let version, let progress):
            String(localized: "Downloading \(version)") + (progress.map { " · \(Int($0 * 100)) %" } ?? "")
        case .installing: String(localized: "Installing…")
        case .idle: nil
        }
    }
}
