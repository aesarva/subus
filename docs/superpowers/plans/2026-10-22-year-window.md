# Окно «Год»: план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Цель:** главное окно «Год»: сетка недель или месяцев с тоном по числу списаний, правая панель (выбранная клетка / все подписки), фильтры и страница подписки.

**Архитектура:**

- **Вся логика — в SubusCore, через TDD:** фильтр, план года (период, недели, месяцы, ступени, деньги), год одной подписки, список подписок, шкала тона с контрастом и перенос выбора.
- **Приложение** добавляет `App/Year/`: контроллер окна и SwiftUI-экран, который только рисует `YearPlan`.

**Стек:** Swift 6, SwiftUI + AppKit, Swift Testing, XcodeGen; macOS 14+.

**Спецификация:** `docs/superpowers/specs/2026-10-22-year-window-design.md`

## Global Constraints

- **Инструменты.** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` для каждого `swift`/`xcodebuild`/`make`; Makefile его экспортирует.
- **Команды.**
  - Тесты ядра: `make test` или `cd Packages/SubusCore && swift test --filter <Name>`.
  - Сборка: `make build`.
  - Снимки: `make snapshots`.
- **Платформа.** Нижняя версия macOS 14, без новых зависимостей и entitlements.
- **Данные.** `Library.currentSchemaVersion` остаётся `1`. Новое состояние хранится только в `UserDefaults`, ключ `yearMode` со значениями `"weeks"` / `"months"`, по умолчанию `"weeks"`.
- **Календарь.** `Calendar.subus()` везде, в тестах — `msk` из `TestSupport` с нужным `firstWeekday`.
- **Деньги.** `Decimal`, конвертация через `CurrencyConverter(table: model.rates)` в `model.settings.baseCurrency`. Без округления до показа.
- **Строки.**
  - Английский в коде через `String(localized:)`, русская запись вручную в `App/Resources/Localizable.xcstrings` (state `translated`, в файле нет завершающего перевода строки — его не добавлять).
  - Склонения — через plural-варианты xcstrings.
- **Цвет.**
  - Ступени тона — нейтральная шкала из спецификации §4.2, цвет линии — только категория, `accent` (#E8590C) — только «сейчас».
  - Текст на плитках ≥ 4.5:1, графика ≥ 3:1 к фону карточки (#FBFBF9 / #232325).
- **Стиль кода.** Как в окружающем коде: один doc-комментарий на тип или неочевидную функцию, `// MARK:` только где они уже есть.
- **Ревью.** Независимое ревью Codex после Task 4 (ядро) и после Task 8 (приложение): `codex exec -s read-only -o <scratch>/review.md "<prompt>"`. Critical и Important исправляются до следующего шага.
- **Данные пользователя.** Настоящую библиотеку не трогать. Снимки и проверки идут только на `PreviewSupport.demoLibrary` и `MemoryStore`.

## Review Focus

1. **Ошибка чтения данных (`AppModel` подставил `.empty`).** Окно показывает баннер ошибки, а не «Вы здесь». Закреплено в Task 6: снимок `year-unreadable` и чистая функция `YearScreenState.resolve` с тестом `unreadableIsNotEmptyLibrary` (Task 4).
2. **Локаль en_US (неделя с воскресенья).** Неделя относится к месяцу своего 4-го дня (среды), столбцов 13–14, первая неделя содержит today. Закреплено в Task 2: `sundayFirstWeeks`.
3. **Удалили категорию, пока её чип выбран.** Фильтр не превращается в «ничего не найдено». Закреплено в Task 1: `prunedDropsDeletedIDs`.
4. **Окно открыто в полночь или при смене режима.** Выбор переносится по дате начала, при выходе из периода выбирается текущая клетка. Закреплено в Task 4: `selectionCarriesAcrossModes`, `selectionFallsBackToCurrent`.
5. **Базовая валюта не рубли и смешанная история валют.** Суммы в базовой валюте, «+ N без курса», «—» при полном отсутствии курса. Закреплено в Task 2: `usdBaseCurrency`, `partialConversion`, `noRatesShowsDash`.

---

### Task 1: Фильтр года

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/YearFilter.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/YearFilterTests.swift`

**Interfaces:**
- Produces:
  - `public enum CycleKind: Hashable, Sendable, CaseIterable { case monthly, yearly, other; public init(_ cycle: BillingCycle) }`. Правило: `.monthly` — это `BillingCycle(1, .month)`, `.yearly` — `BillingCycle(1, .year)`, остальное — `.other`.
  - `public struct YearFilter: Equatable, Sendable`. Поля и значения по умолчанию — из спецификации §2.2: `categoryIDs: Set<UUID?>`, `paymentMethodIDs: Set<UUID?>`, `cycles: Set<CycleKind>`, `currencies: Set<String>`, `includeTrials = true`, `showInactive = false`, `query = ""`. Плюс `public init()`.
  - `public func matches(_ s: Subscription, today: LocalDate) -> Bool`. Проверяет все поля, кроме `showInactive`; `currencies` смотрит на `s.currentPrice(today:).currency`, пробная — `trialEndDate > today`.
  - `public func pruned(to library: Library) -> YearFilter`
  - `public var activeCount: Int`: число непустых наборов, плюс `includeTrials == false`, плюс `showInactive == true`. Это бейдж меню «Фильтры»; категории (чипы) и поиск в нём не считаются.
  - `public static func isTrial(_ s: Subscription, today: LocalDate) -> Bool`

- [ ] **Step 1: Write the failing tests** в `YearFilterTests.swift` (today = `d("2026-10-21")`):
  - `cycleKinds`: `CycleKind(.monthly) == .monthly`, `CycleKind(.yearly) == .yearly`, `CycleKind(BillingCycle(3, .month)) == .other`, `CycleKind(BillingCycle(12, .month)) == .other`.
  - `emptyFilterMatchesAll`: `YearFilter().matches` истинно для ежемесячной, годовой, пробной и без категории.
  - `categoryAndNoCategory`: `categoryIDs = [work]` пропускает только work; `[nil]` пропускает только без категории; `[work, nil]` — обе.
  - `paymentMethodAndNoCard`: то же для `paymentMethodIDs`.
  - `currencyUsesCurrentPrice`: у подписки `price` в USD, но `priceHistory` = [RUB с `2026-01-01`, USD с `2027-03-01`]; `currencies = ["RUB"]` её пропускает, `["USD"]` — нет.
  - `trialsExcluded`: `trialEndDate = today + 3` и `includeTrials = false` → не проходит. С `trialEndDate = today` проходит.
  - `queryIgnoresCaseAndDiacritics`: `"яндекс"` находит «Яндекс Плюс», `"ICLOUD"` находит «iCloud+», `"ё"`-вариант «Кинопоиск»/`"кинопоиск"` находит.
  - `conditionsCombine`: категория и валюта вместе → только подписка, у которой совпадает и то и другое.
  - `prunedDropsDeletedIDs`: фильтр с `categoryIDs = [deleted, kept, nil]` и `paymentMethodIDs = [deletedCard]` после `pruned(to:)` даёт `[kept, nil]` и `[]`.
  - `activeCountCountsMenuConditions`: пустой — 0; карта, периодичность и `includeTrials = false` — 3; `categoryIDs` и `query` не добавляют.

- [ ] **Step 2: Run** `cd Packages/SubusCore && swift test --filter YearFilterTests`. Expected: FAIL, «cannot find 'YearFilter' in scope».

- [ ] **Step 3: Implement** в `YearFilter.swift` по Interfaces. Поиск — `s.name.localizedStandardContains(query)` после `trimmingCharacters(in: .whitespacesAndNewlines)`; пустой запрос пропускает всех.

- [ ] **Step 4: Run** тот же фильтр. Expected: PASS, затем `make test` — все зелёные.

- [ ] **Step 5: Commit** `feat(core): year filter`.

---

### Task 2: План года

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/YearPlan.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/YearPlanTests.swift`

**Interfaces:**
- Consumes: `YearFilter.matches`, `YearFilter.isTrial` (Task 1); `BillingSchedule.charges(for:in:)`, `CurrencyConverter.convert(_:to:)`.
- Produces (все `public`, `Sendable`, `Equatable`):
  - `struct YearMoney { amount: Money; convertedCount: Int; unconvertedCount: Int }` и `enum Display { case zero, amount(Money), partial(Money, missing: Int), unavailable }`, `var display: Display`:
    - нет списаний → `.zero`;
    - все без курса → `.unavailable`;
    - часть → `.partial`;
    - иначе → `.amount`.
  - `struct YearCharge { charge: Charge; converted: Money?; isTrialFuturePrice: Bool }`
  - `struct MonthKey: Hashable, Comparable { year: Int; month: Int }`
  - `struct YearPeriod { id: LocalDate; start: LocalDate; end: LocalDate; monthKey: MonthKey; isPartial: Bool; charges: [YearCharge]; count: Int; total: YearMoney; level: Int }`
  - `struct YearPlan`:
    - `static func build(library: Library, filter: YearFilter, today: LocalDate, calendar: Calendar, baseCurrency: String, converter: CurrencyConverter) -> YearPlan`;
    - `static func range(today: LocalDate) -> ClosedRange<LocalDate>`;
    - поля `range`, `charges`, `weeks`, `months`, `total: YearMoney`, `excludedSubscriptionIDs: [UUID]`, `trialSubscriptionIDs: [UUID]`, `matchedSubscriptionIDs: [UUID]` (прошли фильтр, в том числе без списаний);
    - `static let weekLevels = [1, 2, 3, 4]`, `static let monthLevels = [1, 4, 7, 10]` (нижние границы ступеней 1…4);
    - `static func level(count: Int, thresholds: [Int]) -> Int`;
    - `func weekColumns() -> [(month: MonthKey, weeks: [YearPeriod])]` (столбцы недельной сетки по порядку).
  - Внутренний помощник `LocalDate.weekday(in calendar: Calendar) -> Int` (1 = воскресенье) через `calendar.component(.weekday, from: date(hour: 12, minute: 0, calendar:))`.

- [ ] **Step 1: Write the failing tests** (`today = d("2026-10-21")`, `mondayFirst` / `sundayFirst` от `msk`; курсы `RateTable(date: today, rubPerUnit: ["RUB": 1, "USD": 81.6, "EUR": 94.3], fetchedAt: .now)`):
  - `rangeIsTwelveMonths`: `range(today:)` = `2026-10-21...2027-10-20`; для `2028-02-29` — `...2029-02-27`; для `2027-03-01` — `...2028-02-29`.
  - `lastDayIncluded`: годовая подписка с датой `2027-10-20` даёт одно списание, с `2027-10-21` — ни одного.
  - `weeksMondayFirst`:
    - первая неделя `id == d("2026-10-19")`, `start == today`, `isPartial`;
    - неделя с `id` `2026-12-28` → `monthKey` декабрь 2026; `2027-03-29` → апрель 2027; `2026-11-30` → декабрь 2026;
    - число недель 53.
  - `fiftyFourWeeks`: today `2028-01-02`, `mondayFirst` → 54 недели, `weekColumns().count == 14`, у первого и последнего столбца по одной неделе.
  - `sundayFirstWeeks`: `sundayFirst` → первая неделя `id == d("2026-10-18")`; неделя с `id` `2027-03-28` (среда 31.03) → март.
  - `monthsPartial`: 13 месяцев для `2026-10-21`, первый `start == d("2026-10-21")` и `isPartial`, последний `end == d("2027-10-20")` и `isPartial`; для `2026-11-01` — 12, ни один не неполный.
  - `levels`: `level(count:thresholds: weekLevels)` для 0, 1, 3, 4, 7 → 0, 1, 3, 4, 4; `monthLevels` для 0, 1, 3, 4, 6, 7, 9, 10 → 0, 1, 1, 2, 2, 3, 3, 4. Для 50 списаний за неделю — 4.
  - `trialBoundary`: `trialEndDate = today + 3`, ежемесячная: первое списание ровно `2026-10-24`, у всех `isTrialFuturePrice`, подписка в `trialSubscriptionIDs`. С `trialEndDate = today` — флага нет.
  - `endDateInclusive`: `endDate = 2027-01-15`, списание 15-го входит, следующего нет; `endDate = today - 1` → ноль списаний.
  - `inactiveHasNoCharges`: `isActive = false` → ноль списаний, но id в `matchedSubscriptionIDs`.
  - `farFirstCharge`: старт `2027-11-01` → ноль списаний, id в `matchedSubscriptionIDs`.
  - `totalsAddUp`: на демо-подобной библиотеке сумма `weeks.map(\.total.amount)` == сумма `months…` == `total.amount`; `count` совпадает.
  - `usdBaseCurrency`: base `"USD"`, подписка 816 RUB → `converted == Money(10, "USD")`.
  - `partialConversion`: история цен RUB → `"XYZ"` (нет курса) со смены: часть списаний с `converted == nil`, `total.display == .partial(_, missing: N)`, id в `excludedSubscriptionIDs`.
  - `noRatesShowsDash`: `CurrencyConverter(table: nil)`, только USD-подписки → `total.display == .unavailable`; пустая библиотека → `.zero`.
  - `chargesOrdered`: одинаковая дата → по `localizedStandardCompare` имени, затем по `uuidString`.
  - `filterApplies`: `categoryIDs = [work]` → в `charges` только work.

- [ ] **Step 2: Run** `swift test --filter YearPlanTests`. Expected: FAIL, «cannot find 'YearPlan'».

- [ ] **Step 3: Implement** в `YearPlan.swift`:
  - **Недели.**
    - Первая `id` — ближайший к `range.lowerBound` день не позже него, у которого `weekday == calendar.firstWeekday`.
    - Шаг — 7 дней, пока `id <= range.upperBound`.
    - `monthKey` — месяц `id.adding(days: 3)`.
    - `start`/`end` обрезаны по `range`.
  - **Месяцы.** От `MonthKey(today)` до `MonthKey(range.upperBound)`.
  - **Пробные и неактивные.** `charges` строятся только для `s.isLive(today:)` и `filter.matches`. `isTrialFuturePrice = YearFilter.isTrial(s, today:)`.

- [ ] **Step 4: Run** фильтр, затем `make test`. Expected: всё PASS.

- [ ] **Step 5: Commit** `feat(core): year plan — weeks, months, levels, money`.

---

### Task 3: Год одной подписки и список «Все подписки»

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/SubscriptionYear.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/SubscriptionYearTests.swift`

**Interfaces:**
- Consumes: `YearMoney`, `YearCharge`, `YearPlan.range(today:)` (Task 2); `YearFilter` (Task 1).
- Produces:
  - `public struct SubscriptionYear: Equatable, Sendable`:
    - `static func build(_ s: Subscription, today: LocalDate, baseCurrency: String, converter: CurrencyConverter) -> SubscriptionYear`;
    - поля `charges`, `total: YearMoney`, `next: Charge?` (через `BillingSchedule.nextCharge(for:onOrAfter: today)`, только для live), `firstAtNewPrice: Set<LocalDate>`.
  - `public struct PriceStep: Equatable, Sendable { from: Money; to: Money; on: LocalDate; percent: Decimal? }` и `public static func priceSteps(_ s: Subscription) -> [PriceStep]` в `SubscriptionYear`. Поле `percent` равно `nil`, если валюты разные или `from.amount <= 0`; иначе `(to − from) / from × 100`.
  - `public enum YearSort: String, CaseIterable, Sendable { case total, nextDate, name }`
  - `public struct YearSubscriptionRow: Equatable, Sendable, Identifiable { id: UUID; subscription: Subscription; year: SubscriptionYear; isLive: Bool }`
  - `public static func subscriptionRows(library: Library, filter: YearFilter, today: LocalDate, baseCurrency: String, converter: CurrencyConverter, sort: YearSort) -> [YearSubscriptionRow]` в `YearPlan` (extension в этом файле).

- [ ] **Step 1: Write the failing tests:**
  - `monthlyYear`: ежемесячная 399 ₽ с 12-го → 12 списаний, `total.amount == rub(4788)`, `next?.date == d("2026-11-12")`.
  - `nextBeyondRange`: годовая с первым списанием `2027-11-01` → `charges.isEmpty`, `next?.date == d("2027-11-01")`.
  - `inactiveNoNext`: `isActive = false` → `charges.isEmpty`, `next == nil`.
  - `firstAtNewPrice`: `changePrice(to: rub(399), effectiveFrom: d("2027-01-05"))` у подписки с 12-го → `firstAtNewPrice == [d("2027-01-12")]`.
  - `priceStepsPercent`: 299 → 399 ₽ даёт `percent` ≈ 33.44; 10 USD → 900 RUB даёт `nil`; 0 → 5 даёт `nil`.
  - `rowsInactiveOnlyWhenShown`: неактивная и завершённая есть в строках только при `showInactive = true`.
  - `sortTotalDashLast`: строки по `.total` — по убыванию суммы, а `.unavailable` в конце; при равенстве — по имени, затем id.
  - `sortNextDateNilLast` и `sortName` (`localizedStandardCompare`: «iCloud+» перед «JetBrains», «Яндекс» после латиницы).

- [ ] **Step 2: Run** `swift test --filter SubscriptionYearTests`. Expected: FAIL.
- [ ] **Step 3: Implement** по Interfaces.
- [ ] **Step 4: Run** фильтр и `make test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(core): subscription year and the all-subscriptions list`.

---

### Task 4: Шкала тона, перенос выбора, состояние экрана; ревью ядра

**Files:**
- Create: `Packages/SubusCore/Sources/SubusCore/Presentation/YearStyle.swift`
- Test: `Packages/SubusCore/Tests/SubusCoreTests/YearStyleTests.swift`

**Interfaces:**
- Consumes: `YearPlan`, `YearPeriod`, `MonthKey` (Task 2); `LineContrast.ratio` (существующий).
- Produces:
  - `public enum YearRamp { public static func tone(level: Int, dark: Bool, increasedContrast: Bool) -> SRGBColor; public static func text(level: Int, dark: Bool, increasedContrast: Bool) -> SRGBColor; public static let cardLight = SRGBColor(hex: "#FBFBF9")!, cardDark = SRGBColor(hex: "#232325")! }`. Значения — таблицы §4.2 спецификации дословно.
  - `public enum YearMode: String, Sendable { case weeks, months }`
  - `public enum YearSelection { public static func carry(_ selected: LocalDate?, from: YearMode, to: YearMode, plan: YearPlan, today: LocalDate) -> LocalDate; public static func current(in plan: YearPlan, mode: YearMode, today: LocalDate) -> LocalDate }`. Возвращает `id` клетки.
    - Недели → месяцы: месяц, содержащий выбранную дату.
    - Месяцы → недели: неделя, содержащая `today`, если месяц текущий, иначе первая неделя этого `monthKey`.
    - Тот же режим: клетка с этим `id`, если она есть, иначе `current`.
  - `public enum YearScreenState: Equatable { case unreadable, noSubscriptions, nothingMatches, noChargesThisYear, grid; public static func resolve(plan: YearPlan, library: Library, isUnreadable: Bool) -> YearScreenState }`. Порядок проверок тот же, что в перечислении.

- [ ] **Step 1: Write the failing tests:**
  - `rampMatchesSpec`: `tone(level: 2, dark: false, increasedContrast: false).hex == "#A3A39D"`, `tone(4, dark: true, ic: true).hex == "#FFFFFF"`, `text(2, dark: true, ic: true).hex == "#000000"`.
  - `rampTextContrast`: все 20 пар `LineContrast.ratio(tone, text) >= 4.5`.
  - `ringsContrast`: `ratio(#E8590C, cardLight) >= 3` и `ratio(#E8590C, cardDark) >= 3`.
  - `selectionCarriesAcrossModes`:
    - выбранная неделя `id` `2027-02-08` → месяц `2027-02-01`;
    - месяц `2027-02-01` → неделя `2027-02-01` (первая с `monthKey` февраль);
    - текущий месяц → неделя с today.
  - `selectionFallsBackToCurrent`: выбранная `id` `2026-10-12` (вне плана) → `current` = неделя с today.
  - `unreadableIsNotEmptyLibrary`: `resolve(plan:library: .empty, isUnreadable: true) == .unreadable`; без флага — `.noSubscriptions`.
  - `screenStates`:
    - фильтр отсёк всех → `.nothingMatches`;
    - подписка только неактивная → `.noChargesThisYear`;
    - обычная библиотека → `.grid`.

- [ ] **Step 2: Run** `swift test --filter YearStyleTests`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `make test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(core): year ramp, selection carry, screen state`.
- [ ] **Step 6: Codex review of the core:** `codex exec -s read-only -o <scratch>/year-core-review.md "Review git diff <base>..HEAD -- Packages against docs/superpowers/specs/2026-10-22-year-window-design.md §2, §4.2, §5: …"`. Исправить Critical и Important тестом RED→GREEN, отдельным коммитом `fix(core): …`.

---

### Task 5: Окно и точки входа

**Files:**
- Create: `App/Year/YearWindowController.swift`, `App/Year/YearView.swift` (каркас: панель инструментов, сводка, место под сетку и правую панель), `App/Year/YearToolbar.swift`
- Modify:
  - `App/AppDelegate.swift`: свойство `year`, `@objc func openYear()`, `applicationShouldHandleReopen`;
  - `App/Panel/Components/PanelFooter.swift`: кнопка «Год»;
  - `App/Panel/PanelRoot.swift` и `App/Panel/PanelController.swift`: проброс `onYear`;
  - `App/StatusItem/QuickMenu.swift` и `App/StatusItem/StatusItemController.swift`: пункт «Год»;
  - `App/Services/MainMenu.swift`: меню «Window» с «Year» ⌘Y.
- Surface brief: `.impeccable/surfaces/` для `App/Year/YearView.swift`.

**Interfaces:**
- Consumes: всё ядро (Tasks 1–4).
- Produces:
  - `@MainActor final class YearWindowController: NSObject, NSWindowDelegate { init(model: AppModel, closePanel: @escaping () -> Void, onEdit: @escaping (UUID) -> Void, onAdd: @escaping () -> Void); func show(); var isOpen: Bool }`
  - `@MainActor @Observable final class YearState { var mode: YearMode; var filter: YearFilter; var selection: LocalDate?; var pane: YearPane; var sort: YearSort; var path: [UUID]; var localeTick: Int }`, где `enum YearPane { case period, all }`. `mode` читается и пишется в `UserDefaults` по ключу `yearMode`.
  - `struct YearView: View { init(model: AppModel, state: YearState, onEdit: (UUID) -> Void, onAdd: () -> Void) }`

- [ ] **Step 1: Write the direction contract.** Шесть блоков и FINISH по `.claude/skills/impeccable/reference/new-work.md` §5 записываются через `impeccable surface-brief write App/Year/YearView.swift <body-file>`.
  - **THESIS:** год как сетка коммитов, тон — число списаний; отказ от дашборда «столбцы + карточки».
  - **OWN-WORLD:** мир «Линия», нейтральная шкала §4.2, кольца категорий, оранжевый — только «сейчас».
  - **FIRST VIEWPORT:** сводка, сетка недель слева, правая панель.
  - **FORM:** `seed: none (unavailable)`, потому что направление закрепил пользователь.

  Прочитать brief ещё раз и проверить, что все блоки на месте.
- [ ] **Step 2: Implement** `YearWindowController` по образцу `SettingsWindowController`:
  - `NSWindow(contentViewController: NSHostingController(rootView: YearView(...)))`;
  - `styleMask` `[.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]`;
  - `title` — `String(localized: "Year")`;
  - `contentMinSize` 960 × 600, начальный размер 1100 × 720;
  - `setFrameAutosaveName("YearWindow")`, `identifier = DockPresence.identifier`, `isReleasedWhenClosed = false`;
  - `show()` закрывает панель, затем `NSApp.activate()` и `makeKeyAndOrderFront`.

  Наблюдает `NSLocale.currentLocaleDidChangeNotification` и увеличивает `state.localeTick`. План пересчитывается: `YearView` берёт `model.library`, `model.today`, `model.rates`, `model.settings` и `state.localeTick` через Observation.
- [ ] **Step 3: Точки входа.**
  - `PanelFooter`: кнопка `Image(systemName: "calendar")` с подписью «Year» (`.help("Year (⌘Y)")`) после «Add».
  - `QuickMenu`: «Year» с ключом `y`.
  - `MainMenu`: меню «Window» с «Year» ⌘Y (`target` — делегат).
  - `AppDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:)`: если нет видимых окон, `openYear()`, вернуть `false`.
  - DEBUG-аргумент `-OpenYearOnLaunch` по образцу `-OpenEditorOnLaunch`.
- [ ] **Step 4: Каркас `YearView`.**
  - `.toolbar`: заголовок с периодом (`Formatters.shortDate`), `Picker` «Weeks»/«Months» (`.segmented`), чипы (Task 6), меню «Filters» (Task 6), `.searchable(text: $state.filter.query)`.
  - Сводка:
    - «Charged in the next 12 months» (ru «Спишется за 12 месяцев»);
    - сумма 28 pt semibold tabular через `YearMoney.display`;
    - caption «N charges · ≈ X a month · CBR rate on <date>» и, при пробных, «including N trials at their future price» — те же строки, что у панели.
- [ ] **Step 5: Build** `make build` — без ошибок и предупреждений. Запуск `make run ARGS=-OpenYearOnLaunch` (на демо-данных: добавить `-SeedDemoData` только при пустой библиотеке). Проверить, что окно открылось из подвала панели, быстрого меню, по ⌘Y и кликом по Dock, а иконка Dock видна, пока окно открыто.
- [ ] **Step 6: Commit** `feat(app): Year window and its entry points`.

---

### Task 6: Сетка, правая панель, фильтры, состояния

**Files:**
- Create: `App/Year/YearGrid.swift`, `App/Year/YearSidePane.swift`, `App/Year/YearFilterControls.swift`
- Modify: `App/Year/YearView.swift`, `App/Debug/Snapshots.swift`, `Makefile` (`SNAPSHOT_EXPECTED`)

**Interfaces:**
- Consumes: `YearPlan.weekColumns()`, `months`, `YearRamp`, `YearSelection`, `YearScreenState`, `subscriptionRows`, `YearFilter.activeCount`; `StationRing`, `LogoView`, `PanelBanner`, `PanelEmptyState`, `Formatters`.
- Produces: `struct YearGrid: View { plan: YearPlan; mode: YearMode; selection: Binding<LocalDate?>; today: LocalDate }`, `struct YearSidePane: View`.

- [ ] **Step 1: Сетка недель.**
  - Столбцы из `weekColumns()`, подпись месяца сверху (`Formatters.monthAbbreviation`, а для января другого года — с « ’27»).
  - Клетка — `RoundedRectangle(cornerRadius: 7)`, заливка `YearRamp.tone`. Сторона 36–56 pt по ширине: `GeometryReader`, сторона = `min(56, max(36, (width − gaps) / columns))`.
  - Кольца снаружи через `overlay` с отступом:
    - «сейчас» — зазор 1.5 и кольцо 2.5 `Brand.accent`;
    - выбор — зазор 2 и кольцо 2 `.primary`;
    - обе — кольцо `.primary` 1.5 за оранжевым через зазор 1.5.
  - При Increase Contrast у клетки контур 1 pt `separatorColor`.
- [ ] **Step 2: Сетка месяцев.** 4 столбца плиток 14 pt. Внутри:
  - подпись месяца, у неполных «from 21» / «to 20» (ru «с 21» / «до 20»);
  - число 26 pt semibold;
  - plural «charges» (ru «списание / списания / списаний»);
  - сумма через `display`.

  Цвет текста — `YearRamp.text`.
- [ ] **Step 3: Управление и подсказки.**
  - Клик ставит выбор.
  - `.focusable()` + `.onKeyPress(.leftArrow/.rightArrow/.upArrow/.downArrow)` двигают по сетке; Return открывает первую подписку клетки (`state.path.append`).
  - `.help` у клетки: «Feb 8–14 · 2 charges · 8,233 ₽» (+ « · N without a rate»).
  - VoiceOver:
    - клетка — `accessibilityElement` с подписью «Week Feb 8–14: 2 charges, 8,233 ₽»;
    - сетка — `accessibilityLabel("Year by weeks")`;
    - текущая отмечается «this week».
- [ ] **Step 4: Легенда** под сеткой: «fewer charges», пять образцов `tone(0…4)`, «more», справа пороги «0 · 1 · 2 · 3 · 4+» или «1–3 · 4–6 · 7–9 · 10+».
- [ ] **Step 5: Правая панель.**
  - Сверху `Picker` «Week»/«Month» и «All subscriptions».
  - Клетка: заголовок 20 pt («Feb 8–14» / «February 2027»), «N charges · sum», строки (logo 28, name, «ring · date, weekday · card», amount и «≈ base»), «once a year» у годовых, `TrialTag` у пробных.
  - Пустая клетка: «No charges this week» / «No charges this month» и ниже ближайшее после неё.
  - «All subscriptions»: строки из `subscriptionRows`, меню сортировки, теги «Inactive»/«Ended».
  - Клик по строке → `state.path.append(id)`.
- [ ] **Step 6: Чипы и меню фильтров** (`YearFilterControls.swift`).
  - Чипы — `Toggle` с `.toggleStyle(.button)` и `StationRing` внутри, плюс «All» и «No category». Раскладка — `ViewThatFits`: все чипы → первые + `Menu("More")` → один `Menu("Categories")`.
  - Меню «Filters» с бейджем `activeCount`: карты, периодичность, валюты, «Trials at future price», «Show inactive», «Reset filters».
  - При каждом изменении `model.library` вызывать `state.filter = state.filter.pruned(to:)`.
- [ ] **Step 7: Состояния** по `YearScreenState.resolve(plan:library:isUnreadable: model.isUnreadable)`. Для этого добавить в `AppModel` `var isUnreadable: Bool { unreadableMessage != nil }`.
  - Баннеры как в `PanelRoot.banners` (вынести построение баннеров ошибки и восстановления в общую функцию `DataBanners.make(model:)` в `App/Shared/DataBanners.swift`; панель переходит на неё).
  - `.noSubscriptions` — `PanelEmptyState` «You are here» с «Add Subscription».
  - `.nothingMatches` — «Nothing found» с «Reset filters».
  - `.noChargesThisYear` — пустая сетка, строка «No charges in the next 12 months», `state.pane = .all`.
- [ ] **Step 8: Снимки.** В `Snapshots.swift` функция `yearShot(_ name:, library:, configure:)` по образцу `sheetShot`, окно шириной 1100 и высотой 720. Снимки:
  - `year-weeks`;
  - `year-months`;
  - `year-empty-week` (выбрана неделя без списаний);
  - `year-all`;
  - `year-nothing-found`;
  - `year-no-subscriptions`;
  - `year-unreadable`.

  Это 7 × 4 = 28 файлов, `SNAPSHOT_EXPECTED = 169`.
- [ ] **Step 9: Run** `make snapshots`. Expected: «169 snapshots». Открыть `year-weeks-light-ru`, `year-weeks-dark-en`, `year-months-light-ru`, `year-unreadable-light-en` и проверить, что сетка, кольца, легенда и правая панель не обрезаны и не налезают друг на друга.
- [ ] **Step 10: Commit** `feat(app): Year grid, side pane, filters and states`.

---

### Task 7: Страница подписки

**Files:**
- Create: `App/Year/SubscriptionPage.swift`
- Modify: `App/Year/YearView.swift` (`NavigationStack(path: $state.path)` и `.navigationDestination(for: UUID.self)`), `App/Debug/Snapshots.swift`, `Makefile`

**Interfaces:**
- Consumes: `SubscriptionYear.build`, `SubscriptionYear.priceSteps`, `YearGrid` (в режиме одной подписки), `LogoView`, `StationRing`, `TrialTag`, `Formatters`.
- Produces: `struct SubscriptionPage: View { init(model: AppModel, id: UUID, onEdit: (UUID) -> Void) }`

- [ ] **Step 1: Шапка** по спецификации §3.5:
  - логотип 56, название 22 semibold, теги;
  - «$28.90 a month» (`Formatters.perCycle`) и «≈ X a month» для других циклов;
  - «→ 399 ₽ from Jan 12» (`nextPriceChange`);
  - справа «Edit» (`onEdit(id)`) и «Manage subscription ↗» (`NSWorkspace.open(manageURL)`).
- [ ] **Step 2: «In the next 12 months».**
  - Сумма и число.
  - Сетка недель одной подписки: `YearGrid` с параметром `highlight: CategoryColor?`, клетки ступени 0, станция `StationRing` с заливкой фоном карточки и ореолом 1 pt.
  - Клик по клетке подсвечивает строку списка.
- [ ] **Step 3: «Charges», «Price history», «Details».**
  - Charges: «next» у `next`, «new price» у `firstAtNewPrice`.
  - Price history: `priceSteps`; проценты только при `percent != nil`; рост от 10 % — `Brand.accentText` semibold.
  - Details:
    - категория с кольцом, карта, цикл, первое списание, конец пробного периода, окончание;
    - сайт ссылкой;
    - заметки `Text(…).textSelection(.enabled)`.
- [ ] **Step 4: Неактивная и завершённая.** Вместо сетки «No charges in the next year». Подписку удалили, пока страница открыта (её `id` нет в `model.library`) → `state.path.removeAll()`.
- [ ] **Step 5: Назад.** Esc и ⌘[ через `.keyboardShortcut` у кнопки «‹ Year» в `ToolbarItem(placement: .navigation)`. При возврате выбор и прокрутка не меняются: состояние живёт в `YearState`. При Reduce Motion — `withAnimation(nil)`.
- [ ] **Step 6: Снимки:**
  - `year-sub-monthly` («Яндекс Плюс» с историей цен);
  - `year-sub-yearly` («1Password»);
  - `year-sub-inactive` («Notion»).

  12 файлов, `SNAPSHOT_EXPECTED = 181`. Run `make snapshots`. Expected: «181 snapshots». Открыть по одному каждого вида и проверить.
- [ ] **Step 7: Commit** `feat(app): subscription page in the Year window`.

---

### Task 8: Строки, документы, ревью и finish

**Files:**
- Modify: `App/Resources/Localizable.xcstrings`, `PRODUCT.md`, `README.md`, `README.ru.md`, `CHANGELOG.md`, `DESIGN.md` и `.impeccable/design.json` (через documenter)

- [ ] **Step 1: Русские строки.**
  - Каждая новая строка из Tasks 5–7 получает ru-перевод (state `translated`). Склонения «charge/charges» — plural (`one`/`few`/`many`/`other`).
  - Проверка: `plutil -lint App/Resources/Localizable.xcstrings`.
  - `make snapshots` и просмотр `year-*-ru` — нет английских строк.
- [ ] **Step 2: PRODUCT.md.**
  - Платформа: «No main window» → главное окно «Year» (сетка недель и месяцев, фильтры, страница подписки); Dock и ⌘Tab, пока открыто это окно, редактор или настройки.
  - В Capabilities — строка про окно «Год».
- [ ] **Step 3: README (en/ru) и CHANGELOG.**
  - Раздел про окно «Год» и снимок `docs/images/year-weeks-light-<lang>.png`, скопированный из `build/snapshots`.
  - Запись в `Unreleased`.
- [ ] **Step 4: Codex review of the app:** `codex exec -s read-only -o <scratch>/year-app-review.md "Review git diff <base>..HEAD -- App against the spec §3–4: …"`. Critical и Important исправить, где можно — тестом в ядре, коммит `fix(app): …`.
- [ ] **Step 5: impeccable finish.**
  - Снимки `year-weeks`, `year-months`, `year-sub-monthly` (light/dark) скопировать в `.impeccable/review/`.
  - Запустить `impeccable-finish-reviewer`. Передать ему:
    - запрос пользователя и подтверждённые ответы;
    - путь артефакта `App/Year/YearView.swift`;
    - снимки и direction contract;
    - эскизы `count-weeks.html` и `count-months.html` как критический ориентир;
    - `craft-floor.md`;
    - строку «native macOS, detector не запускался».
  - Действовать по disposition: `fix` — одна пачка правок и повторные снимки.
- [ ] **Step 6: Documenter.** `impeccable-documenter` дописывает в DESIGN.md раздел «Year window»: отступления §4.1, шкала §4.2, компоненты Year Grid / Side Pane / Subscription Page. Обновляет `.impeccable/design.json`. Проверить, что токены шкалы есть в обоих файлах.
- [ ] **Step 7: Run** `make test`, `make build`, `make snapshots`. Expected: всё зелёное, «181 snapshots».
- [ ] **Step 8: Commit** `docs: Year window in PRODUCT, README, DESIGN`.
