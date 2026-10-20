import Foundation
import SubusCore

enum PreviewSupport {
    static func demoLibrary(today: LocalDate) -> Library {
        var library = Library.initial(categoryNames: AppModel.defaultCategoryNames())
        let software = library.categories[0].id, entertainment = library.categories[1].id
        let music = library.categories[2].id, cloud = library.categories[3].id, work = library.categories[4].id
        let bankMethod = PaymentMethod(label: "Т-Банк •• 4242", colorIndex: 0), bank = bankMethod.id
        let revolutMethod = PaymentMethod(label: "Revolut •• 0815", colorIndex: 3), revolut = revolutMethod.id
        library.paymentMethods = [bankMethod, revolutMethod]

        func next(in days: Int, monthsBack: Int) -> LocalDate { today.adding(days: days).adding(months: -monthsBack) }
        func make(_ name: String, _ amount: Decimal, _ currency: String, start: LocalDate, cycle: BillingCycle = .monthly,
                  category: UUID, method: UUID, manage: String? = nil) -> Subscription {
            var s = Subscription(name: name, price: Money(amount, currency), cycle: cycle, startDate: start)
            s.categoryID = category
            s.paymentMethodID = method
            s.manageURL = manage.flatMap(URL.init(string:))
            return s
        }

        var chatGPT = Subscription(name: "ChatGPT Plus", price: Money(20, "USD"), cycle: .monthly,
                                   startDate: today.adding(days: -11), trialEndDate: today.adding(days: 3))
        chatGPT.categoryID = software
        chatGPT.paymentMethodID = revolut
        chatGPT.manageURL = URL(string: "https://chatgpt.com/#settings/Subscription")

        let spotify = make("Spotify", 169, "RUB", start: next(in: 5, monthsBack: 8), category: music, method: bank,
                           manage: "https://www.spotify.com/account/subscription/")
        let iCloud = make("iCloud+", 149, "RUB", start: next(in: 9, monthsBack: 14), category: cloud, method: bank)
        let netflix = make("Netflix", Decimal(string: "11.99")!, "EUR", start: next(in: 13, monthsBack: 20),
                           category: entertainment, method: revolut, manage: "https://www.netflix.com/youraccount")
        let jetBrains = make("JetBrains", Decimal(string: "28.90")!, "USD", start: next(in: 17, monthsBack: 5),
                             category: work, method: revolut)

        var yandex = make("Яндекс Плюс", 299, "RUB", start: today.adding(days: 22).adding(months: -18),
                          category: entertainment, method: bank, manage: "https://plus.yandex.ru/my")
        yandex.changePrice(to: Money(399, "RUB"), effectiveFrom: today.adding(days: -70))

        let youTube = make("YouTube Premium", 299, "RUB", start: next(in: 26, monthsBack: 11), category: entertainment, method: bank)

        var notion = make("Notion", 10, "USD", start: next(in: 11, monthsBack: 7), category: work, method: revolut)
        notion.isActive = false

        var kinopoisk = make("Кинопоиск", 299, "RUB", start: today.adding(days: -20).adding(months: -9),
                             category: entertainment, method: bank)
        kinopoisk.endDate = today.adding(days: -20)

        let onePassword = make("1Password", Decimal(string: "35.88")!, "USD", start: next(in: 41, monthsBack: 24),
                               cycle: .yearly, category: software, method: revolut)

        library.subscriptions = [chatGPT, spotify, iCloud, netflix, jetBrains, yandex, youTube, notion, kinopoisk, onePassword]
        return library
    }
}
