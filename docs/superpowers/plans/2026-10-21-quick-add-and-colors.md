# Quick-add cards and categories, custom category colours: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user create a category or a card without leaving the subscription form, add a card by picking a saved one from macOS AutoFill, and give a category any colour.

**Architecture:** Three pieces of pure logic go into SubusCore: an optional custom category colour, a contrast fit in OKLCH, and the parsing of card numbers and labels. Each is test-driven. The app swaps `lineIndex: Int?` for `lineColor: CategoryColor?` everywhere a line is drawn. It adds two sheets, New Category and New Card, which both the editor pickers and Settings open.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Swift Testing, XcodeGen; macOS 14+.

**Spec:** `docs/superpowers/specs/2026-10-21-quick-add-and-colors-design.md`

## Global Constraints

- **Toolchain.** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for every `swift`/`xcodebuild`/`make` call; the Makefile exports it.
- **Commands.**
  - Core tests: `make test`, or `cd Packages/SubusCore && swift test --filter <Name>`.
  - App build: `make build`.
  - Snapshots: `make snapshots`.
- **Platform.** macOS 14 floor. No new dependencies. No new entitlements: the sandbox keeps exactly app-sandbox, network.client and files.user-selected.read-write.
- **Data format.** `Library.currentSchemaVersion` stays `1`. The JSON key is `customColor` and its value is `"#RRGGBB"`, upper-case on encode. CSV does not change.
- **Card number privacy.** The full number is never written to disk, logs, error text, SwiftUI bindings or the undo history (spec §3.3).
- **Strings.** Every user-visible string is English in code, `String(localized:)` / `LocalizedStringKey`, and has a Russian entry added by hand to `App/Resources/Localizable.xcstrings` (state `translated`). The exact copy is in Task 5 and Task 6.
- **Colour.** Contrast is WCAG 2.x, minimum 3.0 for lines, measured against the reference grounds `#F6F6F3` (light) and `#1C1C1E` (dark).
- **Code style.** Match the surrounding code: one doc comment per type or non-obvious function, no section banners beyond the existing `// MARK:`.
- **Review.** After Task 3 (Core) and after Task 6 (App), run an independent Codex review: `codex exec -s read-only -o <scratch>/review.md "<prompt>"`. Fix Critical and Important findings before going on.

## Review Focus

1. **A saved card arrives grouped, "4242 4242 4242 4242" or with dashes.** It must parse to last4 `4242`, network Visa. Pinned in Task 3: `cardFieldParsesAutoFillWithSpaces`.
2. **The user types the full number digit by digit, then presses Tab.** The field must not collapse at the 12th digit, and must parse when editing ends. Pinned in Task 3: `cardFieldWaitsWhileTyping` and `cardFieldParsesOnEnd`.
3. **The user picks pure white as a category colour (light theme) or pure black (dark theme).** The line must still be visible at ≥ 3:1. Pinned in Task 2: `whiteDarkensOnLightGround` and `blackLightensOnDarkGround`.
4. **"Add" import of a file whose category has a local namesake with another colour.** The local colour must survive. Pinned in Task 1: `addImportKeepsLocalColor`.
5. **A data file with `"customColor": 42` or `"#GGHHII"`.** The library must still load, with that category on its preset. Pinned in Task 1: `badCustomColorFallsBackToPreset`.

---

### Task 1: Custom category colour in the model

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Model/SRGBColor.swift`
- Modify: `Packages/SubusCore/Sources/SubusCore/Model/Subscription.swift` (the `Category` struct, around line 146)
- Modify: `Packages/SubusCore/Sources/SubusCore/Model/Library.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/CategoryColorTests.swift`

**Interfaces:**
- Produces:
  - `public struct SRGBColor: Hashable, Codable, Sendable { public var red, green, blue: UInt8; public init(red: UInt8, green: UInt8, blue: UInt8); public init?(hex: String); public var hex: String }`. `hex` is `"#RRGGBB"` in upper case. `init?(hex:)` accepts an optional `#` and either case, and nothing else. `Codable` goes through `hex`.
  - `public enum CategoryColor: Hashable, Sendable { case preset(Int); case custom(SRGBColor) }`
  - `Category.customColor: SRGBColor?`; `Category.color: CategoryColor { get }`, which is `.custom` when set and otherwise `.preset(colorIndex)`; `mutating func setColor(_ color: CategoryColor)`. A preset sets `colorIndex` and clears `customColor`. A custom colour sets `customColor` and leaves `colorIndex` alone.
  - `Category.init(id: UUID = UUID(), name: String, colorIndex: Int, customColor: SRGBColor? = nil)`
  - `Library.addCategory(name: String, color: CategoryColor) -> UUID`. It returns the id of an existing category whose name matches case-insensitively after trimming, and otherwise appends a new one. A new one with a `.custom` colour gets `colorIndex = categories.count % Category.paletteCount`.
  - `Library.addPaymentMethod(label: String) -> UUID`. Same matching on `label`; a new one gets `colorIndex = paymentMethods.count % Category.paletteCount`.

- [ ] **Step 1: Write the failing tests** in `CategoryColorTests.swift`:
  - `rgbHexRoundTrip`: `SRGBColor(hex: "#2a9d8f")?.hex == "#2A9D8F"`; `SRGBColor(hex: "2A9D8F") != nil`; `SRGBColor(hex: "#GGHHII") == nil`, and the same for `"#FFF"` and `""`.
  - `v1CategoryDecodes`: the JSON `{"id":"…","name":"Music","colorIndex":2}` decodes with `customColor == nil` and `color == .preset(2)`.
  - `customColorRoundTrips`: encoding writes `"customColor":"#2A9D8F"`, and decoding gives `color == .custom(SRGBColor(red: 0x2A, green: 0x9D, blue: 0x8F))`.
  - `badCustomColorFallsBackToPreset`: a whole `Library` JSON with one category at `"customColor": 42` and another at `"#GGHHII"` decodes; both have `customColor == nil`, and the subscriptions are intact.
  - `setColorPresetClearsCustom` and `setColorCustomKeepsIndex`.
  - `addCategoryReusesNamesake`: given "Music", `addCategory(name: " music ", color: .preset(5))` returns the existing id and the count is unchanged.
  - `addPaymentMethodReusesNamesake`: same, on the label.
  - `addImportKeepsLocalColor`: the local category "Music" is `.custom(#112233)`, and the imported "Music" (another id) is `.custom(#445566)`. After `Transfer.apply(preview, to: local, mode: .add)`, "Music" is still `#112233`.
  - `replaceImportTakesFileColor`: the same inputs with `.replace` give `#445566`.
  - `jsonExportKeepsCustomColor`: a round trip through `Transfer`'s JSON export and `parseJSON` keeps `customColor`. Use the existing `TransferTests` helpers for the export and parse calls.
- [ ] **Step 2: Run** `cd Packages/SubusCore && swift test --filter CategoryColorTests`. Expected: FAIL to compile (`SRGBColor` is undefined).
- [ ] **Step 3: Implement** `SRGBColor` and the `Category` changes, with a hand-written `init(from:)` that reads `customColor` as `(try? c.decodeIfPresent(SRGBColor.self, forKey: .customColor)) ?? nil`. Add the two `Library` helpers. The `Transfer.apply` merge needs no code change; the tests pin its current behaviour.
- [ ] **Step 4: Run** `make test`. Expected: every suite passes, the 184 existing tests plus the new ones.
- [ ] **Step 5: Commit** `feat(core): optional custom category colour`.

### Task 2: Line contrast fit

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/LineContrast.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/LineContrastTests.swift`

**Interfaces:**
- Consumes: `SRGBColor` (Task 1).
- Produces:
  - `public enum LineContrast { public static let lightGround = SRGBColor(hex: "#F6F6F3")!; public static let darkGround = SRGBColor(hex: "#1C1C1E")!; public static func ratio(_ a: SRGBColor, _ b: SRGBColor) -> Double; public static func adjusted(_ color: SRGBColor, against ground: SRGBColor, minimum: Double = 3.0) -> SRGBColor }`
  - `internal enum OKLCH { static func from(_ c: SRGBColor) -> (l: Double, c: Double, h: Double); static func rgb(l: Double, c: Double, h: Double) -> SRGBColor? }`. Here `h` is in degrees. `rgb` returns `nil` when the colour is out of the sRGB gamut.

- [ ] **Step 1: Write the failing tests:**
  - `ratioMatchesWCAG`: `ratio(#FFFFFF, #000000)` is 21 ± 0.01; `ratio(#E8590C, #F6F6F3)` is 3.31 ± 0.01.
  - `enoughContrastUnchanged`: `adjusted(#005A94, against: lightGround) == #005A94`.
  - `yellowDarkensOnLightGround`: for `#F2C200` against `lightGround`, `ratio ≥ 3.0`; the result's OKLCH L is below the input's; the hue differs by ≤ 2°.
  - `navyLightensOnDarkGround`: the same for `#1A237E` against `darkGround`; the L is above the input's.
  - `whiteDarkensOnLightGround`: `#FFFFFF` against `lightGround` gives `ratio ≥ 3.0`.
  - `blackLightensOnDarkGround`: `#000000` against `darkGround` gives `ratio ≥ 3.0`.
  - `unreachableMinimumGivesExtreme`: with `minimum: 25`, `#2A9D8F` against `lightGround` is `#000000`, and against `darkGround` is `#FFFFFF`.
  - `fitIsMinimal`: for `#F2C200` against `lightGround`, the result's ratio is < 3.15, so it stops near the threshold.
- [ ] **Step 2: Run** `swift test --filter LineContrastTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
  - Use the standard OKLab matrices (Björn Ottosson) for sRGB ⇄ OKLab, and polar form for OKLCH.
  - `adjusted`:
    1. If the ratio is already ≥ minimum, return the input.
    2. Otherwise the direction is darker when `ground`'s relative luminance is > 0.18, else lighter.
    3. Binary-search L between the input L and the extreme (0 or 1), 24 iterations, for the smallest move that reaches the minimum.
    4. At each L, when `rgb` is out of gamut, multiply chroma by 0.95 until it is in gamut.
    5. Round to `UInt8`.
    6. If even the extreme misses the minimum, return `#000000` or `#FFFFFF`.
  - A greyscale input (chroma ≈ 0) keeps hue 0, and the hue test does not apply to it.
- [ ] **Step 4: Run** `make test`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(core): fit custom line colours to 3:1 in OKLCH`.

### Task 3: Card number, label compose, card field parser

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/CardNumber.swift`, which holds `CardNetwork`, `CardNumber`, `CardFieldState` and `CardFieldParser`
- Modify: `Packages/SubusCore/Sources/SubusCore/Presentation/PaymentLabel.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/CardNumberTests.swift`; extend `PaymentLabelTests.swift`

**Interfaces:**
- Produces:
  - `public enum CardNetwork: String, Sendable, CaseIterable { case visa, mastercard, mir, amex, unionPay, jcb; public func displayName(locale: Locale) -> String }`. The names are "Visa", "Mastercard", "Amex", "UnionPay" and "JCB". Mir is "Мир" when `locale.language.languageCode == .russian` and "Mir" otherwise.
  - `public enum CardNumber { public static func summary(of text: String) -> (last4: String, network: CardNetwork?)?; public static func network(ofDigits digits: String) -> CardNetwork? }`
    - `summary` strips spaces, dashes and NBSP. It requires 12–19 ASCII digits and nothing else.
    - Prefix order: Mir 2200–2204, Mastercard 51–55 and 2221–2720, Visa 4, Amex 34/37, UnionPay 62, JCB 3528–3589.
  - `public struct CardFieldState: Equatable, Sendable { public var text: String; public var last4: String?; public var network: CardNetwork?; public init(text: String = "", last4: String? = nil, network: CardNetwork? = nil) }`
  - `public enum CardFieldParser { public static func mask(_ last4: String) -> String; public static func edited(_ old: CardFieldState, to newText: String) -> CardFieldState; public static func ended(_ state: CardFieldState) -> CardFieldState }`
    - `mask` returns `"•• " + last4`.
    - `edited` applies the first rule that matches:
      1. `summary(newText) != nil` and `newText.count - old.text.count >= 8`: the parsed state, with `text = mask(last4)`.
      2. `newText` matches `^••\s?\d{4}$`: `last4` is those digits. The network is kept only when the digits equal `old.last4`.
      3. Exactly 4 ASCII digits: `last4` is those digits, network `nil`.
      4. Otherwise: `text = newText`, and `last4` and network are `nil`.
    - `ended` returns the parsed state when `summary(state.text) != nil`, and otherwise `state`.
  - `PaymentLabel.compose(bank: String, last4: String?, network: CardNetwork?, locale: Locale = .current) -> String`. It trims `bank`, then follows spec §2.4: "Bank •• 4242", "Bank", "Visa •• 4242", "•• 4242", or "" when there is nothing at all.

- [ ] **Step 1: Write the failing tests:**
  - `networkPrefixes` (parameterised). Each pair:

    | Digits | Network |
    |---|---|
    | `4111111111111111` | `.visa` |
    | `5105105105105100` | `.mastercard` |
    | `2221000000000009` | `.mastercard` |
    | `2720990000000007` | `.mastercard` |
    | `2200000000000004` | `.mir` |
    | `2204000000000001` | `.mir` |
    | `2205000000000000` | `nil` |
    | `340000000000009` | `.amex` |
    | `370000000000002` | `.amex` |
    | `6200000000000005` | `.unionPay` |
    | `3528000000000007` | `.jcb` |
    | `3589000000000003` | `.jcb` |
    | `3590000000000000` | `nil` |
  - `summaryRejects`: 11 digits, 20 digits, `"4111 1111 1111 111a"` and `"•• 4242"` all give `nil`.
  - `cardFieldParsesAutoFillWithSpaces`: `edited(CardFieldState(), to: "4242 4242 4242 4242")` gives text `"•• 4242"`, last4 `"4242"`, network `.visa`.
  - `cardFieldWaitsWhileTyping`: typing `"4"` up to 16 digits, one `edited` call per character, never collapses: `text` stays the raw digits and `last4` stays `nil` until the 4th digit. At exactly 4 digits, `last4` is those digits; past 4 it is `nil` again.
  - `cardFieldParsesOnEnd`: `ended` on the state with 16 typed digits gives the masked state.
  - `maskReadsBack`: `edited(parsed, to: "•• 4242")` keeps `.visa`; `edited(parsed, to: "•• 1111")` gives last4 `"1111"`, network `nil`.
  - `editResets`: `edited(parsed, to: "•• 42")` gives last4 `nil` and network `nil`.
  - `composeForms` (parameterised):

    | bank | last4 | network | Expected |
    |---|---|---|---|
    | `"Т-Банк"` | `"4242"` | `.visa` | `"Т-Банк •• 4242"` |
    | `"Т-Банк"` | `nil` | `nil` | `"Т-Банк"` |
    | `""` | `"4242"` | `.visa` | `"Visa •• 4242"` |
    | `""` | `"4242"` | `.mir` (ru) | `"Мир •• 4242"` |
    | `""` | `"4242"` | `.mir` (en) | `"Mir •• 4242"` |
    | `""` | `"4242"` | `nil` | `"•• 4242"` |
    | `" "` | `nil` | `nil` | `""` |
  - `composeSplits`: `split(compose(bank: "Т-Банк", last4: "4242", network: nil))` gives `("Т-Банк", "•• 4242")`; `split("Visa •• 4242")` gives `("Visa", "•• 4242")`; `split("•• 4242")` gives `("•• 4242", nil)`.
- [ ] **Step 2: Run** `swift test --filter CardNumberTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement** the signatures above in `CardNumber.swift` and `PaymentLabel.swift`.
- [ ] **Step 4: Run** `make test`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(core): card number summary, label compose, card field parser`.
- [ ] **Step 6: Codex review of Tasks 1–3** (`git diff <base>..HEAD -- Packages`), with the prompt naming the spec. Fix Critical and Important findings, then commit `fix(core): …`.

### Task 4: Lines drawn from `CategoryColor`

**Files:**
- Modify:
  - `App/Panel/Components/LinePalette.swift`: `line(_:_:)` and `StationRing`.
  - `App/Panel/Components/UpcomingItem.swift`, `App/Panel/AllTab.swift`, `App/Panel/SpendingTab.swift` (`SpendingBar`, `categoryBars`), `App/Panel/SubscriptionCard.swift` (`ChargeStop`, the details ring).
  - `App/Panel/Components/StripMap.swift` (`StationAnchor`, `StripCanvas.stations`, `TrialTag`), `App/Panel/Components/OverviewLine.swift` (clusters).
  - `App/Debug/PreviewSupport.swift`: give the demo category `work` the colour `.custom(SRGBColor(hex: "#2A9D8F")!)`.
- Modify docs:
  - `DESIGN.md` (Colors: custom category colours and the fit rule).
  - `.impeccable/design.json` (the same rule text).
  - `.impeccable/surfaces/app-panel-panelroot-swift.md` and `.superpowers/impeccable/panel-brief.md`: amendment 20, worded as spec §4.

**Interfaces:**
- Consumes: `CategoryColor`, `Category.color` (Task 1); `LineContrast.adjusted`, `lightGround`, `darkGround` (Task 2).
- Produces:
  - `LinePalette.line(_ color: CategoryColor?, _ scheme: ColorScheme) -> Color`. Presets work as before. A custom colour goes through `LineContrast.adjusted` against the ground for `scheme`, cached in a `[SRGBColor: Color]` dictionary per scheme on the main actor. `nil` gives `rail(scheme)`.
  - Every UI model field `lineIndex: Int?` becomes `lineColor: CategoryColor?`, filled from `category?.color`.
  - `StationRing(lineColor:)`.
  - `TrialTag` uses `.preset(LinePalette.violet)`.
  - The overview's interchange capsule takes the shared colour only when every `lineColor` in the cluster is equal.

- [ ] **Step 1: Replace** `lineIndex` with `lineColor` through the files above. Then `grep -rn "lineIndex" App` must print nothing.
- [ ] **Step 2: Run** `make build`. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Run** `make snapshots`. Expected: 125 snapshots.
  - In `build/snapshots/upcoming-light-en.png` and `upcoming-dark-en.png`, the "Work" category's stations and rows show a teal line, `#2A9D8F` or its fitted variant.
  - Everything else matches the previous run.
- [ ] **Step 4: Update the docs** listed above.
- [ ] **Step 5: Commit** `feat(app): draw category lines from CategoryColor`.

### Task 5: New Category and New Card sheets, used from Settings

**Files:**
- Create:
  - `App/Shared/CategoryColorPicker.swift`: 8 preset swatches plus `ColorPicker(supportsOpacity: false)`, bound to `CategoryColor`.
  - `App/Shared/NewCategorySheet.swift`.
  - `App/Shared/CardNumberField.swift`: an `NSViewRepresentable` over an `NSTextField` subclass.
  - `App/Shared/NewCardSheet.swift`.
- Modify:
  - `App/Settings/NamedColorList.swift`: `NamedColorItem.color: CategoryColor`; `onRecolor: ((UUID, CategoryColor) -> Void)?`; `SwatchButton`'s popover hosts `CategoryColorPicker`; `colorName(_ color: CategoryColor)` gives "Custom color" for `.custom`. `onAdd` is replaced by `addSheet: AnyView`, presented as a `.sheet` by the add button.
  - `App/Settings/CategoriesTab.swift`, `App/Settings/PaymentMethodsTab.swift`: recolour through `Category.setColor`; the add button opens the sheets.
  - `App/Editor/LogoField.swift`: only if it shares `colorName`, keep its own list as it is.
  - `App/Resources/Localizable.xcstrings`.
  - `App/Debug/Snapshots.swift`: four new shots.
  - `Makefile`: `SNAPSHOT_EXPECTED = 141` and the comment "(140 localized + 1)".

**Interfaces:**
- Consumes: `Library.addCategory`, `Library.addPaymentMethod`, `Category.setColor` (Task 1); `LinePalette.line` (Task 4); `CardFieldParser`, `CardFieldState`, `PaymentLabel.compose` (Task 3); `AppModel.editLibrary(_:) -> String?` (existing, `App/Settings/SettingsView.swift:40`).
- Produces:
  - `struct CategoryColorPicker: View { @Binding var color: CategoryColor }`
    - `Color` → `NSColor(color).usingColorSpace(.sRGB)`, with components clamped to 0…1 and rounded to `UInt8`.
    - `SRGBColor` → `Color(.sRGB, red:green:blue:)`.
  - `struct NewCategorySheet: View { init(model: AppModel, onCreated: @escaping (UUID) -> Void) }`
    - Fields: a name field with initial focus; `CategoryColorPicker`, defaulting to `.preset(model.library.categories.count % Category.paletteCount)`; a `StationRing(lineColor:)` preview.
    - Buttons: Cancel and Add. Add is disabled while the trimmed name is empty.
    - Add runs `model.editLibrary { id = $0.addCategory(...) }`. Only on `nil` (success) does it call `onCreated(id)` and dismiss. Otherwise it shows the error in `.red` and stays open.
  - `struct CardNumberField: NSViewRepresentable { @Binding var state: CardFieldState }`
    - The subclass's `becomeFirstResponder` calls `super` and then sets `(currentEditor() as? NSTextView)?.allowsUndo = false`.
    - `controlTextDidChange` feeds `CardFieldParser.edited`. When the result's `text` differs, it sets `stringValue`, sets the field editor's `string`, and calls `undoManager?.removeAllActions(withTarget: fieldEditor)`.
    - `controlTextDidEndEditing` feeds `CardFieldParser.ended`.
    - `dismantleNSView` ends editing and clears the field editor string.
    - `contentType = .creditCardNumber`.
    - The binding only ever holds the parsed state or the text the user is typing. Nothing is logged.
  - `struct NewCardSheet: View { init(model: AppModel, onCreated: @escaping (UUID) -> Void) }`
    - Fields: Card number (`CardNumberField`); a hint under it; and, after editing ends with an unparsed, non-empty text, the error hint in secondary red.
    - Bank or service, and a read-only Label row holding `PaymentLabel.compose(bank:last4:network:)`.
    - Add is enabled when the label is non-empty. It runs `model.editLibrary { id = $0.addPaymentMethod(label:) }` with the same success and error handling as the category sheet.

Copy (en → ru), added to the catalog:

| English | Russian |
|---|---|
| "New Category" (sheet title) | "Новая категория" |
| "New Card" | "Новая карта" |
| "Other color…" | "Другой цвет…" |
| "Custom color" | "Свой цвет" |
| "Card number" | "Номер карты" |
| "Bank or service" | "Банк или сервис" |
| "Label" | "Подпись" |
| "macOS suggests your saved cards. Subus keeps only the last 4 digits." | "macOS предложит сохранённые карты. Subus хранит только последние 4 цифры." |
| "Enter the last 4 digits or choose a card" | "Введите последние 4 цифры или выберите карту" |
| "Add" | "Добавить" (reuse if present) |
| "Cancel" | "Отмена" (reuse if present) |

- [ ] **Step 1: Build the four views and wire Settings.** Keep inline rename as it is.
- [ ] **Step 2: Add snapshot shots** through `renderWindow`, each in both themes and both languages:
  - `sheet-category`: name "Работа", preset 1.
  - `sheet-category-custom`: name "Работа", `.custom(#2A9D8F)`.
  - `sheet-card`: empty.
  - `sheet-card-filled`: state parsed from `"4242 4242 4242 4242"`, bank "Т-Банк".
- [ ] **Step 3: Run** `make build`, then `make snapshots`. Expected: 141 snapshots. Then look at them:
  - `sheet-card-filled-*` shows "•• 4242" and the label "Т-Банк •• 4242";
  - `sheet-category-custom-dark-*` shows a teal ring;
  - the Russian shots carry the Russian copy.
- [ ] **Step 4: Commit** `feat(app): new category and new card sheets with custom colours`.

### Task 6: Create from the subscription form

**Files:**
- Modify: `App/Editor/EditorView.swift` (the pickers at around lines 64–73), `App/Editor/EditorState.swift`
- Modify: `App/Resources/Localizable.xcstrings`, `CHANGELOG.md` (Unreleased)

**Interfaces:**
- Consumes: `NewCategorySheet`, `NewCardSheet` (Task 5).
- Produces:
  - `enum PickerChoice: Hashable { case none, existing(UUID), create }` in `EditorState.swift`.
  - `EditorState.categoryChoice` and `EditorState.paymentChoice`: computed `Binding`-backed properties. Their getters map the draft id to a choice. Their setters write the draft for `.none` and `.existing`, and for `.create` set `creatingCategory = true` or `creatingPayment = true` without touching the draft.
  - `EditorState.creatingCategory: Bool` and `EditorState.creatingPayment: Bool`.

- [ ] **Step 1: Wire the pickers.**
  - Each picker lists None, the existing items, a `Divider()`, and then "New category…" or "New card…" tagged `.create`.
  - `.sheet(isPresented:)` presents the matching sheet.
  - `onCreated` sets `draft.categoryID` or `draft.paymentMethodID`.
  - Copy: "New category…" → "Новая категория…", "New card…" → "Новая карта…".
- [ ] **Step 2: Run** `make build`, then `make run ARGS='-OpenEditorOnLaunch'`. Expected: the app launches with the editor open.
  - Accessibility automation cannot drive the picker menu reliably, so the pickers' menus go on the user's manual checklist.
  - `make snapshots` still gives 141, with `editor-new-*` unchanged apart from the picker values.
- [ ] **Step 3: Update `CHANGELOG.md` Unreleased:**
  - "Create a category or a card right from the subscription form."
  - "Add a card by choosing one of your saved cards (macOS AutoFill); Subus keeps only its last 4 digits."
  - "Any colour for a category; lines stay legible in light and dark."
- [ ] **Step 4: Commit** `feat(app): create categories and cards from the subscription form`.
- [ ] **Step 5: Codex review of Tasks 4–6** (`git diff <base>..HEAD -- App docs DESIGN.md .impeccable CHANGELOG.md Makefile`), with the prompt naming the spec and the privacy rule. Fix Critical and Important findings, then commit `fix(app): …`.
- [ ] **Step 6: Final check.**
  - Run `make test` (all pass), `make build` and `make snapshots` (141).
  - Run `make run` without demo arguments; the user's own data must load unchanged.
  - Hand the user this manual checklist:
    - in the card field, macOS offers saved cards, and after a pick the field shows "•• NNNN";
    - ⌘Z in the card field does not bring back the full number;
    - the "New category…" and "New card…" picker items open their sheets, and Cancel keeps the previous choice;
    - the custom colour picker opens the system panel.
