import Foundation
import Testing
@testable import SubusCore

private let ru = Locale(identifier: "ru_RU")
private let en = Locale(identifier: "en_US")

private func validDraft() -> SubscriptionDraft {
    var draft = SubscriptionDraft(currency: "RUB", today: d("2026-10-20"))
    draft.name = "Netflix"
    draft.priceText = "100"
    return draft
}

@Suite struct DraftTests {
    @Test func parsesLocaleVariants() {
        #expect(PriceParser.parse("9,99", locale: ru) == Decimal(string: "9.99"))
        #expect(PriceParser.parse("9.99", locale: ru) == Decimal(string: "9.99"))
        #expect(PriceParser.parse("1\u{00A0}199,50", locale: ru) == Decimal(string: "1199.5"))
        #expect(PriceParser.parse("1 199", locale: ru) == 1199)
        #expect(PriceParser.parse("1\u{202F}199", locale: ru) == 1199)
        #expect(PriceParser.parse("₽ 300", locale: ru) == 300)
        #expect(PriceParser.parse("300 rub", locale: ru) == 300)
        #expect(PriceParser.parse("USD 9.99", locale: en) == Decimal(string: "9.99"))
        #expect(PriceParser.parse("1,199.50", locale: en) == Decimal(string: "1199.5"))
        #expect(PriceParser.parse("1.199,50", locale: ru) == Decimal(string: "1199.5"))
        #expect(PriceParser.parse("1,199", locale: en) == 1199)
        #expect(PriceParser.parse("1.199", locale: ru) == 1199)
        #expect(PriceParser.parse("12.5", locale: en) == Decimal(string: "12.5"))
        #expect(PriceParser.parse("1,234,567", locale: en) == 1234567)
    }

    @Test func rejectsGarbage() {
        for text in ["abc", "", "  ", "1 2 3abc", "-5", "1.2.3", "5.", "1,2,3", "1e3", "$"] {
            #expect(PriceParser.parse(text, locale: en) == nil, "\(text)")
        }
    }

    @Test func validation() {
        var draft = validDraft()
        #expect(draft.validate(locale: en) == [])

        draft.name = "   "
        #expect(draft.validate(locale: en) == [.nameRequired])
        draft.name = "Netflix"

        draft.priceText = "0"
        #expect(draft.validate(locale: en) == [.priceNotPositive])
        draft.priceText = "x"
        #expect(draft.validate(locale: en) == [.priceInvalid])
        draft.priceText = "100"

        draft.hasTrial = true
        draft.trialEndDate = d("2026-10-01")
        #expect(draft.validate(locale: en) == [.trialBeforeStart])
        draft.trialEndDate = d("2026-11-01")
        #expect(draft.validate(locale: en) == [])

        draft.hasEndDate = true
        draft.endDate = d("2026-10-25")
        #expect(draft.validate(locale: en) == [.endBeforeFirstCharge])
        draft.hasTrial = false
        #expect(draft.validate(locale: en) == [])

        draft.websiteText = "ht tp://"
        draft.manageText = "ftp://x.com"
        #expect(draft.validate(locale: en) == [.invalidURL(field: .website), .invalidURL(field: .manage)])
    }

    @Test func inactiveTrialAndEndDatesAreIgnored() {
        var draft = validDraft()
        draft.trialEndDate = d("2020-01-01")
        draft.endDate = d("2020-01-01")
        #expect(draft.validate(locale: en) == [])
    }

    @Test func errorOrder() {
        var draft = validDraft()
        draft.name = ""
        draft.priceText = "x"
        draft.websiteText = "a b"
        #expect(draft.validate(locale: en) == [.nameRequired, .priceInvalid, .invalidURL(field: .website)])
    }

    @Test func urlNormalization() {
        #expect(URLNormalizer.normalize("netflix.com/account") == URL(string: "https://netflix.com/account"))
        #expect(URLNormalizer.normalize("  http://a.com ") == URL(string: "http://a.com"))
        #expect(URLNormalizer.normalize("  ") == nil)
        #expect(URLNormalizer.normalize("ftp://x.com") == nil)
        #expect(URLNormalizer.normalize("https://") == nil)
        #expect(URLNormalizer.normalize("a b.com") == nil)
    }

    @Test func applyNewAndEdit() {
        var draft = validDraft()
        draft.name = "  Netflix "
        draft.websiteText = "netflix.com"
        let now = Date(timeIntervalSince1970: 1_000)
        let created = draft.apply(to: nil, locale: en, now: now)
        #expect(created.name == "Netflix")
        #expect(created.priceHistory.count == 1)
        #expect(created.createdAt == now)
        #expect(created.websiteURL == URL(string: "https://netflix.com"))

        var renamed = SubscriptionDraft(editing: created, today: d("2026-10-20"), locale: en)
        renamed.name = "Netflix HD"
        let edited = renamed.apply(to: created, locale: en, now: Date())
        #expect(edited.id == created.id)
        #expect(edited.createdAt == now)
        #expect(edited.priceHistory == created.priceHistory)

        var repriced = SubscriptionDraft(editing: created, today: d("2026-10-20"), locale: en)
        repriced.priceText = "150"
        repriced.priceEffectiveFrom = d("2026-11-01")
        let changed = repriced.apply(to: created, locale: en, now: Date())
        #expect(changed.price(on: d("2026-10-31")) == Money(100, "RUB"))
        #expect(changed.price == Money(150, "RUB"))

        var recurrenced = SubscriptionDraft(editing: created, today: d("2026-10-20"), locale: en)
        recurrenced.currency = "usd"
        recurrenced.priceEffectiveFrom = d("2026-12-01")
        #expect(recurrenced.apply(to: created, locale: en, now: Date()).price == Money(100, "USD"))
    }

    @Test func applyClearsDisabledDates() {
        var s = Subscription(name: "A", price: rub(10), cycle: .monthly, startDate: d("2026-01-01"),
                             trialEndDate: d("2026-02-01"), endDate: d("2026-12-01"))
        s.isActive = false
        var draft = SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: en)
        #expect(draft.hasTrial && draft.hasEndDate)
        draft.hasTrial = false
        draft.hasEndDate = false
        let result = draft.apply(to: s, locale: en, now: Date())
        #expect(result.trialEndDate == nil && result.endDate == nil)
        #expect(result.isActive == false)
    }

    @Test(arguments: [ru, en])
    func editingRoundTrip(locale: Locale) {
        var s = Subscription(name: "Spotify", price: rub(Decimal(string: "169.5")!), cycle: .monthly,
                             startDate: d("2026-01-15"), trialEndDate: d("2026-02-15"), endDate: d("2027-01-01"),
                             createdAt: Date(timeIntervalSince1970: 5))
        s.websiteURL = URL(string: "https://spotify.com/")
        s.manageURL = URL(string: "https://spotify.com/account?x=1")
        s.notes = "family"
        s.categoryID = UUID()
        s.paymentMethodID = UUID()
        s.notificationsEnabled = false
        s.logo = .monogram(colorIndex: 3)
        let draft = SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: locale)
        #expect(draft.apply(to: s, locale: locale, now: Date()) == s)

        let plain = Subscription(name: "X", price: usd(1199), cycle: .yearly, startDate: d("2026-01-01"))
        let plainDraft = SubscriptionDraft(editing: plain, today: d("2026-10-20"), locale: locale)
        #expect(plainDraft.priceText == "1199")
        #expect(plainDraft.apply(to: plain, locale: locale, now: Date()) == plain)
    }

    @Test func editingUsesLocaleSeparator() {
        let s = Subscription(name: "X", price: rub(Decimal(string: "169.5")!), cycle: .monthly, startDate: d("2026-01-01"))
        #expect(SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: ru).priceText == "169,5")
        #expect(SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: en).priceText == "169.5")
    }

    @Test func anchorMovedEarlierKeepsOriginalPrice() {
        var s = Subscription(name: "A", price: rub(100), cycle: .monthly, startDate: d("2026-10-01"),
                             trialEndDate: d("2026-10-15"))
        s.changePrice(to: rub(150), effectiveFrom: d("2026-12-15"))
        var draft = SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: en)
        draft.hasTrial = false
        let result = draft.apply(to: s, locale: en, now: Date())
        #expect(result.price(on: d("2026-10-01")) == rub(100))
        #expect(result.price(on: d("2026-12-15")) == rub(150))
    }

    @Test func startDateMovedEarlier() {
        var s = Subscription(name: "A", price: rub(100), cycle: .monthly, startDate: d("2026-10-15"))
        s.changePrice(to: rub(150), effectiveFrom: d("2026-12-15"))
        var draft = SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: en)
        draft.startDate = d("2026-10-01")
        let result = draft.apply(to: s, locale: en, now: Date())
        #expect(result.price(on: d("2026-10-01")) == rub(100))
        #expect(result.price(on: d("2026-12-15")) == rub(150))
    }

    @Test func threeFractionDigitsAreTreatedAsGrouping() {
        #expect(PriceParser.parse("1,199", locale: ru) == 1199)
    }

    @Test func clearingOptionalFields() {
        var s = Subscription(name: "A", price: rub(10), cycle: .monthly, startDate: d("2026-01-01"))
        s.websiteURL = URL(string: "https://a.com")
        s.manageURL = URL(string: "https://a.com/m")
        s.notes = "n"
        var draft = SubscriptionDraft(editing: s, today: d("2026-10-20"), locale: en)
        draft.websiteText = ""
        draft.manageText = "  "
        draft.notes = ""
        let result = draft.apply(to: s, locale: en, now: Date())
        #expect(result.websiteURL == nil && result.manageURL == nil && result.notes == "")
    }
}
