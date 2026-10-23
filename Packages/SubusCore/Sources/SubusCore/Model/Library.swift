import Foundation

public struct Library: Equatable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var subscriptions: [Subscription]
    public var categories: [Category]
    public var paymentMethods: [PaymentMethod]

    public init(schemaVersion: Int = Library.currentSchemaVersion, subscriptions: [Subscription] = [],
                categories: [Category] = [], paymentMethods: [PaymentMethod] = []) {
        self.schemaVersion = schemaVersion
        self.subscriptions = subscriptions
        self.categories = categories
        self.paymentMethods = paymentMethods
    }

    public static let empty = Library()

    public static func initial(categoryNames: [String]) -> Library {
        Library(categories: categoryNames.enumerated().map {
            Category(name: $1, colorIndex: $0 % Category.paletteCount)
        })
    }

    /// The id of the category with this name (case-insensitive, trimmed), appending one when there is none.
    public mutating func addCategory(name: String, color: CategoryColor) -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let same = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return same.id }
        var category = Category(name: name, colorIndex: categories.count % Category.paletteCount)
        category.setColor(color)
        categories.append(category)
        return category.id
    }

    /// The id of the payment method with this label (case-insensitive, trimmed), appending one when there is none.
    public mutating func addPaymentMethod(label: String) -> UUID {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if let same = paymentMethods.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) { return same.id }
        let method = PaymentMethod(label: label, colorIndex: paymentMethods.count % Category.paletteCount)
        paymentMethods.append(method)
        return method.id
    }

    public mutating func upsert(_ s: Subscription) {
        if let i = subscriptions.firstIndex(where: { $0.id == s.id }) {
            subscriptions[i] = s
        } else {
            subscriptions.append(s)
        }
    }

    public mutating func remove(subscriptionID: UUID) {
        subscriptions.removeAll { $0.id == subscriptionID }
    }

    public mutating func removeCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        for i in subscriptions.indices where subscriptions[i].categoryID == id { subscriptions[i].categoryID = nil }
    }

    public mutating func removePaymentMethod(_ id: UUID) {
        paymentMethods.removeAll { $0.id == id }
        for i in subscriptions.indices where subscriptions[i].paymentMethodID == id { subscriptions[i].paymentMethodID = nil }
    }

    public func sanitized() -> Library {
        var lib = self
        var seen = Set<UUID>()
        for i in lib.subscriptions.indices where !seen.insert(lib.subscriptions[i].id).inserted {
            lib.subscriptions[i].id = UUID()
            seen.insert(lib.subscriptions[i].id)
        }
        seen = []
        for i in lib.categories.indices where !seen.insert(lib.categories[i].id).inserted {
            lib.categories[i].id = UUID()
            seen.insert(lib.categories[i].id)
        }
        seen = []
        for i in lib.paymentMethods.indices where !seen.insert(lib.paymentMethods[i].id).inserted {
            lib.paymentMethods[i].id = UUID()
            seen.insert(lib.paymentMethods[i].id)
        }
        for i in lib.categories.indices { lib.categories[i].colorIndex = Self.clampColor(lib.categories[i].colorIndex) }
        for i in lib.paymentMethods.indices { lib.paymentMethods[i].colorIndex = Self.clampColor(lib.paymentMethods[i].colorIndex) }

        let categoryIDs = Set(lib.categories.map(\.id)), methodIDs = Set(lib.paymentMethods.map(\.id))
        for i in lib.subscriptions.indices {
            if let c = lib.subscriptions[i].categoryID, !categoryIDs.contains(c) { lib.subscriptions[i].categoryID = nil }
            if let p = lib.subscriptions[i].paymentMethodID, !methodIDs.contains(p) { lib.subscriptions[i].paymentMethodID = nil }
            switch lib.subscriptions[i].logo {
            case .image(let name), .siteIcon(let name):
                if !Logo.isSafeFileName(name) { lib.subscriptions[i].logo = .monogram(colorIndex: nil) }
            case .monogram(let index?):
                lib.subscriptions[i].logo = .monogram(colorIndex: Self.clampColor(index))
            case .monogram(nil):
                break
            }
            if let url = lib.subscriptions[i].websiteURL, !URLNormalizer.isWeb(url) { lib.subscriptions[i].websiteURL = nil }
            if let url = lib.subscriptions[i].manageURL, !URLNormalizer.isWeb(url) { lib.subscriptions[i].manageURL = nil }
            // One entry per date (the last one wins), sorted; an empty history starts at the anchor.
            var byDate: [LocalDate: PriceChange] = [:]
            for change in lib.subscriptions[i].priceHistory { byDate[change.effectiveFrom] = change }
            lib.subscriptions[i].priceHistory = byDate.values.sorted { $0.effectiveFrom < $1.effectiveFrom }
            if lib.subscriptions[i].priceHistory.isEmpty {
                lib.subscriptions[i].priceHistory = [PriceChange(effectiveFrom: lib.subscriptions[i].anchor,
                                                                 price: lib.subscriptions[i].price)]
            }
            lib.subscriptions[i].price = lib.subscriptions[i].priceHistory.last!.price
        }
        return lib
    }

    private static func clampColor(_ i: Int) -> Int {
        ((i % Category.paletteCount) + Category.paletteCount) % Category.paletteCount
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, subscriptions, categories, paymentMethods }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        subscriptions = try c.decodeIfPresent([Subscription].self, forKey: .subscriptions) ?? []
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? []
        paymentMethods = try c.decodeIfPresent([PaymentMethod].self, forKey: .paymentMethods) ?? []
    }
}
