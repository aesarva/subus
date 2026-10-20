import Foundation
import Testing
@testable import SubusCore

struct SettingsStoreTests {
    private let ru = Locale(identifier: "ru_RU")

    @Test func defaultsFromLocale() {
        let s = AppSettings.defaults(locale: ru)
        #expect(s.baseCurrency == "RUB")
        #expect(s.reminderDays == [5, 3, 1])
        #expect(s.reminderHour == 10)
        #expect(s.reminderMinute == 0)
        #expect(s.showMenuBarCounter)
        #expect(s.language == .system)
        #expect(AppSettings.defaults(locale: Locale(identifier: "en")).baseCurrency == "USD")
    }

    @Test func tolerantDecode() {
        let json = #"{"reminderDays":[5,3,1,40,3,-1],"reminderHour":"x","bogus":1,"baseCurrency":"EUR"}"#
        let storage = InMemorySettingsStorage([SettingsStore.key: Data(json.utf8)])
        let s = SettingsStore(storage: storage, locale: ru).load()
        #expect(s.reminderDays == [5, 3, 1])
        #expect(s.reminderHour == 10)
        #expect(s.baseCurrency == "EUR")
    }

    @Test func outOfRangeAndMalformedFieldsFallBack() {
        let json = #"{"baseCurrency":"EURO","reminderHour":24,"reminderMinute":-1,"language":"de","showMenuBarCounter":false,"reminderDays":[]}"#
        let storage = InMemorySettingsStorage([SettingsStore.key: Data(json.utf8)])
        let s = SettingsStore(storage: storage, locale: ru).load()
        #expect(s.baseCurrency == "RUB")
        #expect(s.reminderHour == 10)
        #expect(s.reminderMinute == 0)
        #expect(s.language == .system)
        #expect(!s.showMenuBarCounter)
        #expect(s.reminderDays.isEmpty)
    }

    @Test func lowercaseCurrencyIsUppercased() {
        let storage = InMemorySettingsStorage([SettingsStore.key: Data(#"{"baseCurrency":"eur"}"#.utf8)])
        #expect(SettingsStore(storage: storage, locale: ru).load().baseCurrency == "EUR")
    }

    @Test func garbageBlobGivesDefaults() {
        let storage = InMemorySettingsStorage([SettingsStore.key: Data("{oops".utf8)])
        #expect(SettingsStore(storage: storage, locale: ru).load() == .defaults(locale: ru))
    }

    @Test func missingBlobGivesDefaults() {
        #expect(SettingsStore(storage: InMemorySettingsStorage(), locale: ru).load() == .defaults(locale: ru))
    }

    @Test func roundTrip() {
        let store = SettingsStore(storage: InMemorySettingsStorage(), locale: ru)
        var s = AppSettings.defaults(locale: ru)
        s.baseCurrency = "USD"
        s.reminderDays = [7, 0]
        s.reminderHour = 8
        s.reminderMinute = 30
        s.showMenuBarCounter = false
        s.language = .en
        store.save(s)
        #expect(store.load() == s)
        #expect(AppSettings.normalizedDays([1, 7, 1, 0]) == [7, 1, 0])
    }

    @Test func userDefaultsStorageRoundTrip() throws {
        let suite = "subus.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = UserDefaultsSettingsStorage(defaults)
        #expect(storage.data(forKey: "k") == nil)
        storage.set(Data("v".utf8), forKey: "k")
        #expect(storage.data(forKey: "k") == Data("v".utf8))
    }
}
