import Foundation

public enum DraftError: Hashable, Sendable {
    case nameRequired, priceInvalid, priceNotPositive, trialBeforeStart, endBeforeFirstCharge
    case invalidURL(field: URLField)
}

public enum URLField: Hashable, Sendable { case website, manage }

public enum PriceParser {
    private static let symbols: Set<Character> = ["₽", "$", "€", "£", "₸", "₺", "֏", "₾", "¥"]

    /// `locale` разрешает только неоднозначность одного разделителя; "1,199" и "1.199" — всегда группировка.
    public static func parse(_ text: String, locale: Locale) -> Decimal? {
        var chars = Array(text.map { $0.isWhitespace ? " " : $0 })
        stripEdges(&chars)
        let body = String(chars)
        guard !body.isEmpty, body.allSatisfy({ $0 == " " || $0 == "," || $0 == "." || ($0.isASCII && $0.isNumber) })
        else { return nil }

        var digits = body
        if body.contains(" ") {
            guard body.wholeMatch(of: /\d{1,3}(?: \d{3})+(?:[.,]\d+)?/) != nil else { return nil }
            digits = body.replacingOccurrences(of: " ", with: "")
        }
        guard let canonical = canonicalize(digits) else { return nil }
        return Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func stripEdges(_ chars: inout [Character]) {
        func removable(_ c: Character) -> Bool { c == " " || symbols.contains(c) }
        func trimEnds() {
            while let f = chars.first, removable(f) { chars.removeFirst() }
            while let l = chars.last, removable(l) { chars.removeLast() }
        }
        trimEnds()
        if chars.count > 3, chars.prefix(3).allSatisfy({ $0.isASCII && $0.isLetter }) { chars.removeFirst(3) }
        else if chars.count > 3, chars.suffix(3).allSatisfy({ $0.isASCII && $0.isLetter }) { chars.removeLast(3) }
        trimEnds()
    }

    private static func canonicalize(_ s: String) -> String? {
        let commas = s.filter { $0 == "," }.count, dots = s.filter { $0 == "." }.count
        func isDigits(_ p: Substring) -> Bool { !p.isEmpty && p.allSatisfy { $0.isASCII && $0.isNumber } }
        func grouped(_ parts: [Substring]) -> Bool {
            guard let first = parts.first, isDigits(first), first.count <= 3 else { return false }
            return parts.dropFirst().allSatisfy { isDigits($0) && $0.count == 3 }
        }

        if commas > 0, dots > 0 {
            let decimalSep: Character = s.lastIndex(of: ",")! > s.lastIndex(of: ".")! ? "," : "."
            let groupSep: Character = decimalSep == "," ? "." : ","
            let halves = s.split(separator: decimalSep, omittingEmptySubsequences: false)
            guard halves.count == 2, isDigits(halves[1]),
                  grouped(halves[0].split(separator: groupSep, omittingEmptySubsequences: false)) else { return nil }
            return halves[0].replacingOccurrences(of: String(groupSep), with: "") + "." + halves[1]
        }
        guard let sep: Character = commas > 0 ? "," : dots > 0 ? "." : nil else {
            return isDigits(Substring(s)) ? s : nil
        }
        let parts = s.split(separator: sep, omittingEmptySubsequences: false)
        if parts.count > 2 { return grouped(parts) ? parts.joined() : nil }
        let (int, frac) = (parts[0], parts[1])
        guard isDigits(frac), int.isEmpty || isDigits(int) else { return nil }
        if frac.count == 3, !int.isEmpty, int != "0", int.count <= 3 { return String(int) + String(frac) }
        return (int.isEmpty ? "0" : String(int)) + "." + frac
    }
}

public enum URLNormalizer {
    public static func normalize(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let full = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: full), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        return url
    }
}

public struct SubscriptionDraft: Equatable, Sendable {
    public var name = ""
    public var priceText = ""
    public var currency: String
    public var cycle = BillingCycle.monthly
    public var startDate: LocalDate
    public var hasTrial = false
    public var trialEndDate: LocalDate?
    public var hasEndDate = false
    public var endDate: LocalDate?
    public var categoryID: UUID?
    public var paymentMethodID: UUID?
    public var websiteText = ""
    public var manageText = ""
    public var notes = ""
    public var notificationsEnabled = true
    public var logo: Logo = .monogram(colorIndex: nil)
    public var priceEffectiveFrom: LocalDate
    private var originalPriceText: String?
    private var originalPrice: Money?

    public init(currency: String, today: LocalDate) {
        self.currency = currency.uppercased()
        self.startDate = today
        self.priceEffectiveFrom = today
    }

    public init(editing s: Subscription, today: LocalDate, locale: Locale) {
        self.init(currency: s.price.currency, today: today)
        name = s.name
        priceText = "\(s.price.amount)".replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
        cycle = s.cycle
        startDate = s.startDate
        hasTrial = s.trialEndDate != nil
        trialEndDate = s.trialEndDate
        hasEndDate = s.endDate != nil
        endDate = s.endDate
        categoryID = s.categoryID
        paymentMethodID = s.paymentMethodID
        websiteText = s.websiteURL?.absoluteString ?? ""
        manageText = s.manageURL?.absoluteString ?? ""
        notes = s.notes
        notificationsEnabled = s.notificationsEnabled
        logo = s.logo
        originalPriceText = priceText
        originalPrice = s.price
    }

    public func validate(locale: Locale) -> [DraftError] {
        var errors: [DraftError] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.nameRequired) }
        if let price = PriceParser.parse(priceText, locale: locale) {
            if price <= 0 { errors.append(.priceNotPositive) }
        } else {
            errors.append(.priceInvalid)
        }
        if hasTrial, let trial = trialEndDate, trial < startDate { errors.append(.trialBeforeStart) }
        if hasEndDate, let end = endDate, end < (hasTrial ? trialEndDate ?? startDate : startDate) {
            errors.append(.endBeforeFirstCharge)
        }
        if !websiteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           URLNormalizer.normalize(websiteText) == nil { errors.append(.invalidURL(field: .website)) }
        if !manageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           URLNormalizer.normalize(manageText) == nil { errors.append(.invalidURL(field: .manage)) }
        return errors
    }

    /// Предусловие: `validate(locale:)` вернул пустой массив.
    public func apply(to existing: Subscription?, locale: Locale, now: Date) -> Subscription {
        assert(validate(locale: locale).isEmpty, "apply called with an invalid draft")
        var money = Money(PriceParser.parse(priceText, locale: locale) ?? 0, currency)
        if let originalPrice, priceText == originalPriceText, currency == originalPrice.currency { money = originalPrice }
        let trial = hasTrial ? trialEndDate : nil
        let end = hasEndDate ? endDate : nil
        var s = existing ?? Subscription(name: name, price: money, cycle: cycle, startDate: startDate,
                                         trialEndDate: trial, endDate: end, createdAt: now)
        s.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        s.cycle = cycle
        s.startDate = startDate
        s.trialEndDate = trial
        s.endDate = end
        if existing != nil {
            if let first = s.priceHistory.first, s.anchor < first.effectiveFrom {
                s.priceHistory[0].effectiveFrom = s.anchor
            }
            if s.price != money { s.changePrice(to: money, effectiveFrom: priceEffectiveFrom) }
        }
        s.categoryID = categoryID
        s.paymentMethodID = paymentMethodID
        s.websiteURL = URLNormalizer.normalize(websiteText)
        s.manageURL = URLNormalizer.normalize(manageText)
        s.notes = notes
        s.notificationsEnabled = notificationsEnabled
        s.logo = logo
        return s
    }
}
