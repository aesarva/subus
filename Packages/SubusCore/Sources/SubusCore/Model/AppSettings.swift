import Foundation

public enum LanguageSetting: String, Codable, CaseIterable, Sendable { case system, ru, en }

public struct AppSettings: Equatable, Codable, Sendable {
    public var baseCurrency: String
    public var reminderDays: [Int]
    public var reminderHour: Int
    public var reminderMinute: Int
    public var showMenuBarCounter: Bool
    public var language: LanguageSetting

    public static let defaultReminderDays = [5, 3, 1]
    public static let defaultReminderHour = 10
    public static let defaultReminderMinute = 0

    /// Locale used for the currency fallback while decoding; set via `JSONDecoder.userInfo`.
    public static let localeUserInfoKey = CodingUserInfoKey(rawValue: "subus.settings.locale")!

    public init(baseCurrency: String, reminderDays: [Int], reminderHour: Int, reminderMinute: Int,
                showMenuBarCounter: Bool, language: LanguageSetting) {
        self.baseCurrency = baseCurrency
        self.reminderDays = Self.normalizedDays(reminderDays)
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.showMenuBarCounter = showMenuBarCounter
        self.language = language
    }

    public static func defaults(locale: Locale) -> AppSettings {
        AppSettings(baseCurrency: (locale.currency?.identifier ?? "USD").uppercased(),
                    reminderDays: defaultReminderDays,
                    reminderHour: defaultReminderHour,
                    reminderMinute: defaultReminderMinute,
                    showMenuBarCounter: true,
                    language: .system)
    }

    public static func normalizedDays(_ days: [Int]) -> [Int] {
        Array(Set(days.filter { (0...30).contains($0) })).sorted(by: >)
    }

    private enum CodingKeys: String, CodingKey {
        case baseCurrency, reminderDays, reminderHour, reminderMinute, showMenuBarCounter, language
    }

    /// Lenient: each field falls back to its default independently.
    public init(from decoder: Decoder) throws {
        let locale = decoder.userInfo[Self.localeUserInfoKey] as? Locale ?? .current
        let fallback = Self.defaults(locale: locale)
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let currency = ((try? c.decodeIfPresent(String.self, forKey: .baseCurrency)) ?? nil)?.uppercased()
        if let currency, currency.utf8.count == 3, currency.utf8.allSatisfy({ (65...90).contains($0) }) {
            baseCurrency = currency
        } else {
            baseCurrency = fallback.baseCurrency
        }

        if let days = (try? c.decodeIfPresent([Int].self, forKey: .reminderDays)) ?? nil {
            reminderDays = Self.normalizedDays(days)
        } else {
            reminderDays = fallback.reminderDays
        }

        let hour = (try? c.decodeIfPresent(Int.self, forKey: .reminderHour)) ?? nil
        reminderHour = hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? fallback.reminderHour
        let minute = (try? c.decodeIfPresent(Int.self, forKey: .reminderMinute)) ?? nil
        reminderMinute = minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? fallback.reminderMinute

        showMenuBarCounter = ((try? c.decodeIfPresent(Bool.self, forKey: .showMenuBarCounter)) ?? nil)
            ?? fallback.showMenuBarCounter
        language = ((try? c.decodeIfPresent(LanguageSetting.self, forKey: .language)) ?? nil) ?? fallback.language
    }
}
