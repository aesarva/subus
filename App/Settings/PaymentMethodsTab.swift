import SubusCore
import SwiftUI

struct PaymentMethodsTab: View {
    let model: AppModel
    @State private var error: String?

    var body: some View {
        NamedColorList(
            items: model.library.paymentMethods.map { NamedColorItem(id: $0.id, name: $0.label, colorIndex: $0.colorIndex) },
            addTitle: String(localized: "New payment method"),
            usage: { id in model.library.subscriptions.filter { $0.paymentMethodID == id }.count },
            deleteMessage: { String(localized: "\($0) subscriptions will lose this payment method") },
            error: error,
            onRename: { id, name in edit { l in
                if let i = l.paymentMethods.firstIndex(where: { $0.id == id }) { l.paymentMethods[i].label = name }
            } },
            onRecolor: { id, color in edit { l in
                if let i = l.paymentMethods.firstIndex(where: { $0.id == id }) { l.paymentMethods[i].colorIndex = color }
            } },
            onDelete: { id in edit { $0.removePaymentMethod(id) } },
            onAdd: {
                edit { l in
                    l.paymentMethods.append(PaymentMethod(label: String(localized: "New payment method"),
                                                          colorIndex: l.paymentMethods.count % Category.paletteCount))
                }
            })
    }

    private func edit(_ change: (inout Library) -> Void) {
        var copy = model.library
        change(&copy)
        error = model.replaceLibrary(copy) ? nil : model.saveError
    }
}
