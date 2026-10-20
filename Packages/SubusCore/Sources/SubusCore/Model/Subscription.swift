import Foundation

public enum Logo: Hashable, Codable, Sendable {
    case monogram(colorIndex: Int?)
    case image(fileName: String)
    case siteIcon(fileName: String)

    public static func isSafeFileName(_ name: String) -> Bool {
        name.wholeMatch(of: /[A-Za-z0-9\-]{1,64}\.png/) != nil
    }
}

public struct PriceChange: Hashable, Codable, Sendable {
    public var effectiveFrom: LocalDate
    public var price: Money

    public init(effectiveFrom: LocalDate, price: Money) {
        self.effectiveFrom = effectiveFrom
        self.price = price
    }
}

public struct Subscription: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var logo: Logo
    public var price: Money
    public var cycle: BillingCycle
    public var startDate: LocalDate
    public var endDate: LocalDate?
    public var trialEndDate: LocalDate?
    public var isActive: Bool
    public var categoryID: UUID?
    public var paymentMethodID: UUID?
    public var websiteURL: URL?
    public var manageURL: URL?
    public var priceHistory: [PriceChange]
    public var notificationsEnabled: Bool
    public var notes: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, price: Money, cycle: BillingCycle, startDate: LocalDate,
                trialEndDate: LocalDate? = nil, endDate: LocalDate? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.logo = .monogram(colorIndex: nil)
        self.price = price
        self.cycle = cycle
        self.startDate = startDate
        self.endDate = endDate
        self.trialEndDate = trialEndDate
        self.isActive = true
        self.categoryID = nil
        self.paymentMethodID = nil
        self.websiteURL = nil
        self.manageURL = nil
        self.notificationsEnabled = true
        self.notes = ""
        self.createdAt = createdAt
        self.priceHistory = [PriceChange(effectiveFrom: trialEndDate ?? startDate, price: price)]
    }

    public var anchor: LocalDate { trialEndDate ?? startDate }

    public func isEnded(today: LocalDate) -> Bool {
        guard let endDate else { return false }
        return endDate < today
    }

    public func isLive(today: LocalDate) -> Bool { isActive && !isEnded(today: today) }

    public func price(on date: LocalDate) -> Money {
        priceHistory.last(where: { $0.effectiveFrom <= date })?.price ?? price
    }

    public mutating func changePrice(to newPrice: Money, effectiveFrom: LocalDate) {
        if let i = priceHistory.firstIndex(where: { $0.effectiveFrom == effectiveFrom }) {
            priceHistory[i].price = newPrice
        } else {
            priceHistory.append(PriceChange(effectiveFrom: effectiveFrom, price: newPrice))
        }
        priceHistory.sort { $0.effectiveFrom < $1.effectiveFrom }
        price = priceHistory.last!.price
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, logo, price, cycle, startDate, endDate, trialEndDate, isActive, categoryID,
             paymentMethodID, websiteURL, manageURL, priceHistory, notificationsEnabled, notes, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        logo = try c.decodeIfPresent(Logo.self, forKey: .logo) ?? .monogram(colorIndex: nil)
        price = try c.decode(Money.self, forKey: .price)
        cycle = try c.decode(BillingCycle.self, forKey: .cycle)
        startDate = try c.decode(LocalDate.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(LocalDate.self, forKey: .endDate)
        trialEndDate = try c.decodeIfPresent(LocalDate.self, forKey: .trialEndDate)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        categoryID = try c.decodeIfPresent(UUID.self, forKey: .categoryID)
        paymentMethodID = try c.decodeIfPresent(UUID.self, forKey: .paymentMethodID)
        websiteURL = try c.decodeIfPresent(URL.self, forKey: .websiteURL)
        manageURL = try c.decodeIfPresent(URL.self, forKey: .manageURL)
        priceHistory = try c.decodeIfPresent([PriceChange].self, forKey: .priceHistory) ?? []
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

public struct Category: Identifiable, Hashable, Codable, Sendable {
    public static let paletteCount = 8

    public var id: UUID
    public var name: String
    public var colorIndex: Int

    public init(id: UUID = UUID(), name: String, colorIndex: Int) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }
}

public struct PaymentMethod: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var label: String
    public var colorIndex: Int

    public init(id: UUID = UUID(), label: String, colorIndex: Int) {
        self.id = id
        self.label = label
        self.colorIndex = colorIndex
    }
}
