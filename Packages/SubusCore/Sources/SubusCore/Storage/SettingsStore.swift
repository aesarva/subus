import Foundation

public protocol SettingsStorage: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
}

/// `UserDefaults` is documented as thread-safe but is not marked `Sendable`.
public struct UserDefaultsSettingsStorage: SettingsStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    public func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: key) }
}

public final class SettingsStore: Sendable {
    public static let key = "settings.v1"

    private let storage: SettingsStorage
    private let locale: Locale

    public init(storage: SettingsStorage, locale: Locale) {
        self.storage = storage
        self.locale = locale
    }

    public func load() -> AppSettings {
        let decoder = JSONDecoder()
        decoder.userInfo[AppSettings.localeUserInfoKey] = locale
        guard let data = storage.data(forKey: Self.key),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .defaults(locale: locale)
        }
        return settings
    }

    public func save(_ s: AppSettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        storage.set(data, forKey: Self.key)
    }
}
