import AppKit
import SubusCore
import SwiftUI

struct EditorView: View {
    @Bindable var state: EditorState
    var onCancel: () -> Void = {}

    @FocusState private var focus: EditorState.Field?
    @Environment(\.colorScheme) private var scheme

    static let width: CGFloat = 520
    private var errorColor: Color { LinePalette.line(0, scheme) }
    private let calendar = Calendar.subus()

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LogoField(state: state)
                    TextField("Name", text: $state.draft.name, prompt: Text(verbatim: "Netflix"))
                        .focused($focus, equals: .name)
                        .invalid(messages(.name))
                    errorRows(.name)
                }
                Section {
                    LabeledContent("Price") {
                        HStack(spacing: 8) {
                            TextField("Price", text: $state.draft.priceText, prompt: Text(verbatim: "0"))
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .focused($focus, equals: .price)
                                .invalid(messages(.price))
                            currencyPicker
                        }
                    }
                    errorRows(.price)
                    if state.priceChanged {
                        DatePicker("Effective from", selection: dateBinding(\.priceEffectiveFrom), in: Self.dateRange,
                                   displayedComponents: .date)
                    }
                    billingRow
                }
                Section {
                    DatePicker(state.draft.hasTrial ? "Start date" : "First charge",
                               selection: dateBinding(\.startDate), in: Self.dateRange, displayedComponents: .date)
                    Toggle("Free trial", isOn: Binding(get: { state.draft.hasTrial }, set: state.setTrial))
                    if state.draft.hasTrial {
                        DatePicker("Trial ends", selection: dateBinding(\.trialEndDate, default: state.draft.startDate.adding(days: 7)),
                                   in: Self.dateRange, displayedComponents: .date)
                            .focused($focus, equals: .trialEnd)
                            .invalid(messages(.trialEnd))
                        errorRows(.trialEnd)
                    }
                    Toggle("Ends on a date", isOn: Binding(get: { state.draft.hasEndDate }, set: state.setEndDate))
                    if state.draft.hasEndDate {
                        DatePicker("Ends", selection: dateBinding(\.endDate, default: state.draft.startDate),
                                   in: Self.dateRange, displayedComponents: .date)
                            .focused($focus, equals: .endDate)
                            .invalid(messages(.endDate))
                        errorRows(.endDate)
                    }
                }
                Section {
                    Picker("Category", selection: $state.draft.categoryID) {
                        Text("None").tag(UUID?.none)
                        ForEach(state.model.library.categories) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    Picker("Payment method", selection: $state.draft.paymentMethodID) {
                        Text("None").tag(UUID?.none)
                        ForEach(state.model.library.paymentMethods) { Text($0.label).tag(UUID?.some($0.id)) }
                    }
                }
                Section {
                    LabeledContent("Website") {
                        HStack(spacing: 8) {
                            TextField("Website", text: $state.draft.websiteText, prompt: Text(verbatim: "example.com"))
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .focused($focus, equals: .website)
                                .invalid(messages(.website))
                            fetchButton
                        }
                    }
                    errorRows(.website)
                    if state.fetchFailed {
                        Text("Couldn't load the icon").font(.caption).foregroundStyle(errorColor)
                    }
                    TextField("Manage or cancel link", text: $state.draft.manageText, prompt: Text(verbatim: "example.com/account"))
                        .focused($focus, equals: .manage)
                        .invalid(messages(.manage))
                    errorRows(.manage)
                }
                Section {
                    TextEditor(text: $state.draft.notes)
                        .font(.body)
                        .frame(minHeight: 64)
                        .scrollContentBackground(.hidden)
                        .focused($focus, equals: .notes)
                        .overlay(alignment: .topLeading) {
                            if state.draft.notes.isEmpty {
                                Text("Notes")
                                    .foregroundStyle(Color(nsColor: .placeholderTextColor))
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel(Text("Notes"))
                    Toggle("Remind me", isOn: $state.draft.notificationsEnabled)
                }
            }
            .formStyle(.grouped)
            bottomBar
        }
        .frame(width: Self.width)
        .background {
            Button("") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    // MARK: Pieces

    private var bottomBar: some View {
        HStack {
            if let message = state.saveMessage {
                Text(message).font(.callout).foregroundStyle(errorColor)
            }
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            // Return saves everywhere except in the Notes editor, where it starts a new line.
            if focus == .notes {
                Button("Save") { save() }
            } else {
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var billingRow: some View {
        LabeledContent("Billing") {
            HStack(spacing: 8) {
                Text("every")
                TextField("Every", value: $state.draft.cycle.count, format: .number.grouping(.never))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 44)
                Stepper("Every", value: $state.draft.cycle.count, in: 1...BillingCycle.maxCount)
                    .labelsHidden()
                Picker("Billing period", selection: $state.draft.cycle.unit) {
                    ForEach(BillingCycle.Unit.allCases, id: \.self) { unit in
                        Text(Self.unitName(unit, count: state.draft.cycle.count)).tag(unit)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    /// "month" / "months" (ru: месяц, месяца, месяцев) for the number next to it.
    private static func unitName(_ unit: BillingCycle.Unit, count n: Int) -> String {
        let category: String
        if Bundle.main.preferredLocalizations.first == "ru" {
            let (m10, m100) = (n % 10, n % 100)
            category = m10 == 1 && m100 != 11 ? "one" : (2...4).contains(m10) && !(12...14).contains(m100) ? "few" : "many"
        } else {
            category = n == 1 ? "one" : "many"
        }
        return Bundle.main.localizedString(forKey: "billing.unit.\(unit.rawValue).\(category)", value: nil, table: nil)
    }

    private var currencyPicker: some View {
        let (popular, others) = Self.currencies(including: state.draft.currency)
        return Picker("Currency", selection: $state.draft.currency) {
            ForEach(popular, id: \.self) { Text(Self.currencyLabel($0)).tag($0) }
            Divider()
            ForEach(others, id: \.self) { Text(Self.currencyLabel($0)).tag($0) }
        }
        .labelsHidden()
        .frame(width: 200)
    }

    private var fetchButton: some View {
        Button {
            state.fetchIcon()
        } label: {
            HStack(spacing: 6) {
                if state.fetching { ProgressView().controlSize(.small) }
                Text("Fetch icon")
            }
        }
        .disabled(state.siteURL == nil || state.fetching)
    }

    // MARK: Validation text

    private func messages(_ field: EditorState.Field) -> [String] {
        state.errors.filter { EditorState.field(of: $0) == field }.map(Self.message)
    }

    @ViewBuilder private func errorRows(_ field: EditorState.Field) -> some View {
        ForEach(messages(field), id: \.self) { message in
            Text(message).font(.caption).foregroundStyle(errorColor)
        }
    }

    private static func message(_ error: DraftError) -> String {
        switch error {
        case .nameRequired: String(localized: "Enter a name")
        case .priceInvalid: String(localized: "Enter the price as a number")
        case .priceNotPositive: String(localized: "The price must be more than zero")
        case .trialBeforeStart: String(localized: "The trial can't end before it starts")
        case .endBeforeFirstCharge: String(localized: "The end date can't be before the first charge")
        case .invalidURL: String(localized: "Enter a valid web address")
        }
    }

    private func save() {
        // Commits a count still being typed.
        NSApp.keyWindow?.makeFirstResponder(nil)
        if !state.save(), let field = state.firstErrorField { focus = field }
    }

    // MARK: Dates

    private static let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.subus()
        return LocalDate.min.date(hour: 12, minute: 0, calendar: calendar)...LocalDate.max.date(hour: 12, minute: 0, calendar: calendar)
    }()

    private func dateBinding(_ keyPath: WritableKeyPath<SubscriptionDraft, LocalDate>) -> Binding<Date> {
        Binding(get: { state.draft[keyPath: keyPath].date(hour: 12, minute: 0, calendar: calendar) },
                set: { state.draft[keyPath: keyPath] = LocalDate.today(now: $0, calendar: calendar) })
    }

    private func dateBinding(_ keyPath: WritableKeyPath<SubscriptionDraft, LocalDate?>, default fallback: LocalDate) -> Binding<Date> {
        Binding(get: { (state.draft[keyPath: keyPath] ?? fallback).date(hour: 12, minute: 0, calendar: calendar) },
                set: { state.draft[keyPath: keyPath] = LocalDate.today(now: $0, calendar: calendar) })
    }

    // MARK: Currencies

    private static let popularCurrencies = ["RUB", "USD", "EUR", "GBP", "KZT", "TRY", "AMD", "GEL", "UAH", "BYN", "CNY"]
    private static let otherCurrencies = Set(Locale.commonISOCurrencyCodes).subtracting(popularCurrencies).sorted()

    private static func currencies(including current: String) -> (popular: [String], others: [String]) {
        guard !popularCurrencies.contains(current), !otherCurrencies.contains(current) else {
            return (popularCurrencies, otherCurrencies)
        }
        return (popularCurrencies, (otherCurrencies + [current]).sorted())
    }

    private static func currencyName(_ code: String) -> String { Locale.current.localizedString(forCurrencyCode: code) ?? code }

    private static func currencyLabel(_ code: String) -> String { "\(code) — \(currencyName(code))" }
}

private extension View {
    /// Reads the field's error aloud with the field.
    func invalid(_ messages: [String]) -> some View {
        accessibilityHint(Text(verbatim: messages.joined(separator: ". ")))
    }
}
