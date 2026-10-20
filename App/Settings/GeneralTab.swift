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
