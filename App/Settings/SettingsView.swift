import SubusCore
import SwiftUI

struct SettingsView: View {
    static let width: CGFloat = 540

    let model: AppModel
    let notifier: UserNotifier
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            NotificationsTab(model: model, notifier: notifier)
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(SettingsTab.notifications)
            CategoriesTab(model: model)
                .tabItem { Label("Categories", systemImage: "tag") }
                .tag(SettingsTab.categories)
            PaymentMethodsTab(model: model)
                .tabItem { Label("Payment Methods", systemImage: "creditcard") }
                .tag(SettingsTab.paymentMethods)
            DataTab(model: model)
                .tabItem { Label("Data", systemImage: "externaldrive") }
                .tag(SettingsTab.data)
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension AppModel {
    /// Writes one settings change; every change replans the reminders.
    func update(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        updateSettings(copy)
    }
}
