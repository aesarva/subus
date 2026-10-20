import SubusCore
import SwiftUI

/// Identity of one charge in the strip map; repeats of a subscription are separate keys.
struct ChargeKey: Hashable {
    let subscriptionID: UUID
    let date: LocalDate

    init(_ charge: Charge) {
        subscriptionID = charge.subscriptionID
        date = charge.date
    }
}

/// A charge with everything a row or a station needs to draw it.
struct UpcomingItem: Identifiable {
    let charge: Charge
    let subscription: Subscription
    let days: Int
    /// The category's line colour index; nil rides the rail colour.
    let lineIndex: Int?
    let categoryName: String?
    let paymentLabel: String?

    var id: ChargeKey { ChargeKey(charge) }
}

extension AppModel {
    func upcomingItems(_ charges: [Charge]) -> [UpcomingItem] {
        let today = today
        let byID = Dictionary(library.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return charges.compactMap { charge in
            guard let s = byID[charge.subscriptionID] else { return nil }
            let category = category(s.categoryID)
            return UpcomingItem(charge: charge, subscription: s, days: today.days(until: charge.date),
                                lineIndex: category?.colorIndex, categoryName: category?.name,
                                paymentLabel: paymentMethod(s.paymentMethodID)?.label)
        }
    }
}
