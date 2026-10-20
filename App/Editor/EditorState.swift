import AppKit
import Observation
import OSLog
import SubusCore

/// The editor's working copy: the draft, the logo not yet written to disk, and the save flow.
@MainActor @Observable
final class EditorState {
    enum Field: Hashable { case name, price, trialEnd, endDate, website, manage, notes }

    struct PendingLogo {
        let fileName: String
        let data: Data
    }

    var draft: SubscriptionDraft
    private(set) var attempted = false
    private(set) var pendingLogo: PendingLogo?
    private(set) var fetching = false
    private(set) var fetchFailed = false
    private(set) var imageFailed = false
    private(set) var saveMessage: String?

    /// The record as it was when the editor opened: the baseline of the merge on save.
    let existing: Subscription?
    let model: AppModel
    let locale: Locale
    @ObservationIgnored var onSaved: () -> Void = {}

    @ObservationIgnored private let id: UUID
    @ObservationIgnored private var logoToken = 0
    @ObservationIgnored private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "logos")

    init(model: AppModel, editing existing: Subscription?, locale: Locale = .current) {
        self.model = model
        self.existing = existing
        self.locale = locale
        id = existing?.id ?? UUID()
        draft = existing.map { SubscriptionDraft(editing: $0, today: model.today, locale: locale) }
            ?? SubscriptionDraft(currency: model.settings.baseCurrency, today: model.today)
    }

    // MARK: Validation

    var errors: [DraftError] { attempted ? draft.validate(locale: locale) : [] }

    static func field(of error: DraftError) -> Field {
        switch error {
        case .nameRequired: .name
        case .priceInvalid, .priceNotPositive: .price
        case .trialBeforeStart: .trialEnd
        case .endBeforeFirstCharge: .endDate
        case .invalidURL(.website): .website
        case .invalidURL(.manage): .manage
        }
    }

    var firstErrorField: Field? { errors.first.map(Self.field(of:)) }

    /// The price differs from what is stored, so a new price-history entry needs its date.
    var priceChanged: Bool {
        guard let existing, let amount = PriceParser.parse(draft.priceText, locale: locale) else { return false }
        return Money(amount, draft.currency) != existing.price
    }

    // MARK: Draft defaults

    func setTrial(_ on: Bool) {
        draft.hasTrial = on
        if on, draft.trialEndDate == nil { draft.trialEndDate = draft.startDate.adding(days: 7) }
    }

    func setEndDate(_ on: Bool) {
        draft.hasEndDate = on
        if on, draft.endDate == nil {
            let anchor = draft.hasTrial ? draft.trialEndDate ?? draft.startDate : draft.startDate
            draft.endDate = BillingSchedule.chargeDate(anchor: anchor, cycle: draft.cycle, index: 1)
        }
    }

    // MARK: Logo

    var monogramIndex: Int {
        if case .monogram(let index?) = draft.logo { return index }
        return Monogram.colorIndex(for: draft.name, paletteCount: LinePalette.count)
    }

    var isMonogram: Bool {
        if case .monogram = draft.logo { return true }
        return false
    }

    var pendingImage: NSImage? {
        guard let pendingLogo else { return nil }
        return NSImage(data: pendingLogo.data)
    }

    /// A stand-in for `LogoView`, which draws a subscription's logo.
    var previewSubscription: Subscription {
        var s = Subscription(name: draft.name, price: Money(1, draft.currency), cycle: draft.cycle, startDate: draft.startDate)
        s.logo = draft.logo
        return s
    }

    var siteURL: URL? {
        guard let url = URLNormalizer.normalize(draft.websiteText),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = "https"
        return parts.url
    }

    func selectMonogram(_ index: Int) {
        draft.logo = .monogram(colorIndex: index)
        dropPending()
    }

    func resetLogo() {
        draft.logo = .monogram(colorIndex: nil)
        dropPending()
    }

    private func dropPending() {
        logoToken += 1
        pendingLogo = nil
        fetching = false
        fetchFailed = false
        imageFailed = false
    }

    func fetchIcon() {
        guard !fetching, let site = siteURL else { return }
        logoToken += 1
        let token = logoToken
        fetching = true
        fetchFailed = false
        imageFailed = false
        Task {
            do {
                let png = try await SiteIconFetcher(http: URLSessionHTTPClient()).fetch(site: site)
                guard token == logoToken else { return }
                fetching = false
                adopt(png, siteIcon: true)
            } catch {
                guard token == logoToken else { return }
                log.error("Icon fetch failed: \(error.localizedDescription, privacy: .public)")
                fetching = false
                fetchFailed = true
            }
        }
    }

    func loadImage(from url: URL) {
        logoToken += 1
        let token = logoToken
        fetching = false
        fetchFailed = false
        imageFailed = false
        Task {
            do {
                let png = try await Self.readImage(url)
                guard token == logoToken else { return }
                adopt(png, siteIcon: false)
            } catch {
                guard token == logoToken else { return }
                log.error("Image load failed: \(error.localizedDescription, privacy: .public)")
                imageFailed = true
            }
        }
    }

    private nonisolated static let maxFileBytes = 30 * 1024 * 1024

    private nonisolated static func readImage(_ url: URL) async throws -> Data {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try await Task.detached {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maxFileBytes else { throw ImageNormalizer.Failure.tooLarge }
            return try ImageNormalizer.pngThumbnail(from: Data(contentsOf: url))
        }.value
    }

    private func adopt(_ png: Data, siteIcon: Bool) {
        let name = "\(id.uuidString.lowercased())-\(UUID().uuidString.prefix(8).lowercased()).png"
        pendingLogo = PendingLogo(fileName: name, data: png)
        draft.logo = siteIcon ? .siteIcon(fileName: name) : .image(fileName: name)
    }

    // MARK: Save

    /// Returns true when the subscription was saved. Validation failures are shown under the fields.
    @discardableResult
    func save() -> Bool {
        attempted = true
        saveMessage = nil
        guard draft.validate(locale: locale).isEmpty else { return false }

        var current: Subscription?
        if let existing {
            guard let found = model.library.subscriptions.first(where: { $0.id == existing.id }) else {
                saveMessage = String(localized: "This subscription was deleted.")
                return false
            }
            current = found
        }
        let directory = model.logosDirectory
        if pendingLogo != nil, directory == nil {
            saveMessage = String(localized: "Couldn't save the logo")
            return false
        }

        // Only the fields edited here replace the stored record's, so a change made meanwhile (an import) survives.
        var subscription = draft.apply(to: existing, locale: locale, now: Date())
        if let existing, let current { subscription = current.merging(edited: subscription, baseline: existing) }
        subscription.id = id

        var written: URL?
        if let pendingLogo, let directory {
            let url = directory.appendingPathComponent(pendingLogo.fileName)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try pendingLogo.data.write(to: url, options: .atomic)
                written = url
            } catch {
                log.error("Logo write failed: \(error.localizedDescription, privacy: .public)")
                saveMessage = String(localized: "Couldn't save the logo")
                return false
            }
        }
        guard model.save(subscription) else {
            if let written { try? FileManager.default.removeItem(at: written) }
            saveMessage = model.saveError
            return false
        }
        onSaved()
        return true
    }
}
