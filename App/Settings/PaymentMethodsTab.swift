import SubusCore
import SwiftUI

struct PaymentMethodsTab: View {
    let model: AppModel
    @State private var error: String?

    var body: some View {
        NamedColorList(
            items: model.library.paymentMethods.map { NamedColorItem(id: $0.id, name: $0.label, color: .preset($0.colorIndex)) },
            addTitle: String(localized: "New payment method"),
            usage: { id in model.library.subscriptions.filter { $0.paymentMethodID == id }.count },
            deleteMessage: { String(localized: "\($0) subscriptions will lose this payment method") },
            error: error,
            onRename: { id, name in edit { l in
                if let i = l.paymentMethods.firstIndex(where: { $0.id == id }) { l.paymentMethods[i].label = name }
            } },
            onRecolor: nil,
            onDelete: { id in _ = edit { $0.removePaymentMethod(id) } },
            addSheet: AnyView(NewCardSheet(model: model) { _ in }))
    }

    private func edit(_ change: (inout Library) -> Void) -> Bool {
        error = model.editLibrary(change)
        return error == nil
    }
}
