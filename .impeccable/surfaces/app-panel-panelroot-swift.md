---
version: 1
slug: "app-panel-panelroot-swift"
primary_target: "App/Panel/PanelRoot.swift"
related_targets: ["App/StatusItem/StatusItemController.swift"]
---

# Surface brief — Subus menu-bar panel

## Scope
The menu-bar panel (tabs Upcoming / All / Spending, subscription card inside), the status-item glyph and counter. Mode: **Operate**. The editor window and Settings window stay native (standard SwiftUI Form / TabView) and inherit only the palette tokens (category colours, monogram tiles).

## Audience and task
People with a dozen+ subscriptions in mixed ₽/$/€ who glance at the menu bar many times a day and open the panel for seconds: "what's next, when, how much". First read (user, 2026-10-20): **the timeline** — upcoming charges laid out in time. Anti-goals (user): banking fintech, a faceless system list, number overload. Theme follows the system (light + dark).

## Constraints
macOS 14+; Liquid Glass on 26+ via `#available`, fallback on 14–15. Native controls only (segmented control for tabs, standard buttons, search field, toggle). ru + en; amounts in tabular figures. Reduce Motion, Increase Contrast, Reduce Transparency respected. No bundled brand logos (monogram / user image / site icon).

Amended 2026-10-21 after review: the glass comes from the system-rendered `NSPopover` (Liquid Glass on 26, popover vibrancy on 14–15, an opaque popover under Reduce Transparency), not from an `#available` branch in the app; the app makes no glass call of its own.

## Direction contract

THESIS: Upcoming charges ride one transit line and today is the station you're at. It refuses the category default of a stack of rounded cards with brand-coloured logo tiles under a big total.

OWN-WORLD: The panel ground is the system material: glass on 26, `.popover` vibrancy on 14–15, a solid `#F6F6F3` / `#1C1C1E` under Reduce Transparency. Ink is `#1D1D1F` / `#F2F2F0` and the secondary ink is `#62625B` / `#A1A19A`. A category is a metro line colour, from 8 indices.
- Monogram tiles (white letter ≥ 4.5:1): `#B3261E` red, `#2E7D32` green, `#005A94` blue, `#A85600` orange, `#7B3A96` violet, `#0A6F99` cyan, `#7A4E26` brown, `#7D6300` yellow.
- Line strokes must reach ≥ 3:1 against the ground in each theme. Light uses the tile set. Dark uses the bright set: `#FF6B5E`, `#3FA34D`, `#3D9BE9`, `#ED9121`, `#B57BD6`, `#1EBCEF`, `#C08A55`, `#F2C200`.
- The resting rail is `#CFCFC8` / `#48484A`.
- Components: station dots (13 pt ring, 3 pt stroke, line colour), interchange rings for same-day charges, 3 pt rails. Group heads in tracked caps at 11 pt semibold. No cards, boxes or row backgrounds.
- Type: SF Pro, tabular figures everywhere.

STORY: Within a second of opening, the visitor sees how many days remain until the next charge, which service it is, and how the coming weeks are spaced out. They act from there: open a card, follow "Manage subscription ↗", or close the panel reassured.

FIRST VIEWPORT (360 pt wide):
- A native segmented control: Upcoming · All · Spending.
- Header row:
  - Left: the month total ("6 870 ₽ in a month", 17 pt semibold) and under it the year total plus "CBR rate on …" and trial/excluded notes (11 pt secondary).
  - Right: the days-to-next figure, the panel's only large number (~44 pt semibold), with "days until charge" under it.
- 60-day overview line:
  - Week ticks and month labels.
  - A station per charge in its line colour, and the "you are here" ring at the left.
  - Only the leg from today to the next station is drawn in full ink (5 pt); the rest of the rail stays quiet.
  - The next station is labelled.
- Below, the strip map: a vertical spine at x≈26 pt, with tracked group heads (Today & tomorrow / This week / This month / Later).
  - Each row is 42 pt: station dot on the spine, 24 pt monogram/logo tile, name (13 pt semibold) with a "Trial" outline tag, "in 3 days · Fri, 23 Oct" or "· card label" (11 pt secondary), and the amount right-aligned, tight to the margin.
  - A converted running sum closes each group.
- Footer: "+ Add", a count of subscriptions (and inactive ones), Settings.

FORM: Transit strip map, candidate 3 of 7 on my ordered list (1 tear-off calendar, 2 library due-date card, 3 transit strip map, 4 almanac tide table, 5 periodical subscription catalogue, 6 musical score, 7 utility bill). seed:4a4fc13cd77bba82.
- Raises:
  - One reserved ink for the active leg (from orienteering).
  - Chrome deleted (from Metro tiles).
  - Focus lifts one station and dims the rest (from streaming wall).
  - Sums tight to the margin (from J-card).
  - Hierarchy by scale alone (from type specimen).
  - Stepped 2×90 ms marker motion, no easing, instant under Reduce Motion (from manual tab board).
- Signature interaction: hovering a station on the overview, or moving the selection with the arrow keys, lifts its row in the strip map (enlarged station ring + row highlight). Only the rails and stations of the other rows recede; text and amounts never lose opacity. When the day changes, the horizon slides: today stays at the left edge and the stations step one day left in two 90 ms steps.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Amendments after Codex design review (stage A, 2026-10-20)

These bind the UI tasks together with the direction contract. Where they differ from the approved sketch, they win: the sketch's light station colours and quiet-rail greys are superseded by the tokens below.

1. **Header notes.** Under the totals sits a notes block that grows in height. It holds, in this order: the year total, "CBR rate on …", "includes N trials at their future price", and "excluding N subscriptions (no rate)".
   - No rate cache: the total covers only base-currency subscriptions, with the excluding note.
   - Everything excluded: show "—" instead of a total, plus the note. Never an unexplained 0.
2. **No text dimming, ever.** Selection or hover changes only graphics and the row highlight. Text and amounts keep full opacity.
3. **Rails are meaningful and must reach ≥ 3:1 against the ground.**
   - Resting rail and ticks: light `#8A8A83`, dark `#75757A`.
   - Stations always use the per-theme line set: light = tile set, dark = bright set.
   - Under Increase Contrast, rails and strokes go from 3 pt to 4 pt and the focus ring is the system one.
4. **One container owns the background: `NSPopover`.**
   - It is system-rendered: Liquid Glass on 26, popover vibrancy on 14–15. Reduce Transparency is handled by the system, which gives an opaque popover.
   - Text uses semantic system colours (`labelColor`, `secondaryLabelColor`, `tertiaryLabelColor`), not hex ink, so Increase Contrast and the themes adapt natively. The hex inks above are the sketch reference only.
   - The only custom colours are the line set, the tile set and the rail.
5. **Size.**
   - Content width is fixed at 360 pt.
   - Height is the content height, capped at the screen's visible height − 80 pt.
   - The segmented control, header and overview are pinned. The strip map scrolls. The footer is pinned with no overlap.
   - `NSPopover.contentSize` follows the hosting view's fitting size.
6. **Rows.**
   - The amount never truncates or compresses.
   - The name takes up to 2 lines, then tail-truncates.
   - The Trial tag is its own element and wraps below the name if needed.
   - Rows are at least 42 pt and grow to fit.
   - The relative date ("in N days · date") is always present. The payment-method label is appended after it.
   - Full name is in the card and in VoiceOver.
7. **Overview geometry.**
   - x = daysFromToday × (railWidth / 60). Today is fixed at the left edge.
   - Stations closer than 14 pt merge into one cluster ring showing a count. Hover or arrow keys reveal the cluster's charges in a tooltip.
   - Only the next station is labelled. The label clamps inside the rail ends.
   - Repeats of the same subscription are separate stations.
8. **VoiceOver.**
   - Each strip row is one button. Label: "name, in N days, date, amount, category[, trial]". Action: open card.
   - Stations and the spine are hidden from VoiceOver.
   - The overview is one element: "Next 60 days: N charges; next in N days: name, amount".
9. **Keyboard.**
   - Tab and Shift-Tab cycle segmented control → search (All tab) → list → footer.
   - ↑ and ↓ move the list selection and auto-scroll to it. Enter opens the card. Esc goes back from the card, otherwise closes the panel.
   - ⌘N adds, ⌘, opens Settings. Focus returns to the originating row after leaving a card.
   - The popover's content view becomes first responder on open.
10. **Colour semantics.**
    - Station and spine colour = the category's colour. No category = the rail colour.
    - Monogram tile colour = the subscription's own `colorIndex`, or the hash of its name. This is a separate rule, and two subscriptions may share a colour.
    - Category, trial, "next" and selection are always also carried by text, a tag or shape.
11. **Empty and edge states.**
    - No subscriptions: the empty state with a "Add your first subscription" button. The overview is hidden.
    - Subscriptions exist but no charge in 60 days: a calm line "No charges in the next 60 days — next: name, date" (the real nearest charge). The overview shows today only.
    - All inactive: "All subscriptions are paused" plus a link to All.
    - One charge: the leg is drawn to it.
    - Today and tomorrow: the accent from the status-item rule.
    - Status item:
      - Shows "Nd" even beyond the horizon, and trials count.
      - No text when there is no future charge or the setting is off.
      - 0–1 days: semibold text plus a dot. The accessibility label is "Subus, next charge in N days: name".
12. **Banners.**
    - They sit under the segmented control, in priority order: save error > data recovered or corrupt > notifications off.
    - At most 2 are visible. Each has one action.
    - None are dismissable except "notifications off", which can be dismissed for the session.
13. **Group sums.** Each group closes with "≈ total for this group", converted to the base currency. If any charge in the group is unconvertible, add "+ N not converted".
14. **Footer.** "+ Add" · "Total 12 · inactive 2" (inactive includes ended) · Settings (gear with tooltip and accessibility label "Settings").
15. **Secondary tabs and card (states the UI tasks must render and snapshot).**
    - All: no search results; category filter with no results; Inactive section collapsed and expanded.
    - Spending: no payment methods; no price increases; a single category.
    - Card:
      - no manageURL (button hidden);
      - fewer than 3 future charges, or none ("No upcoming charges");
      - price history of 1 entry (section hidden);
      - delete confirmation;
      - failure to toggle Active (saveError banner).
16. **Text.** Use system text styles: body 13, subheadline 12, caption 11. Group heads are caption semibold with tracking. Nothing below 11 pt. macOS has no Dynamic Type, so rows must grow with content rather than clip.

17. **Menu-bar glyph (user decision, 2026-10-20, option A).** This replaces the rail/ring/dot glyph.
    - A renewal ring: an open circle of radius 6 pt with a 2 pt round-capped stroke, plus an arrow head at the top-right. The ring and arrow use the menu-bar label colour, drawn non-template with a dynamic `labelColor`, so they read black on a light menu bar and white on a dark one.
    - A filled centre dot, Ø 5.2 pt, in the accent red `#E5352B`.
    - The glyph is 18×18 pt, using the SVG geometry of option A in `.impeccable/mocks/icon/glyphs.html`.
    - Counter text uses the label colour. When the next charge is 0–1 days away, the counter turns accent red and semibold.
    - The accessibility label is unchanged.
    - The accent red `#E5352B` is the brand accent from now on: the status item, the "today/tomorrow" accent in the panel, and the app icon direction.

18. **Accent exclusivity (user decision, 2026-10-20, after the finish review).** Red is reserved for the brand accent: the menu-bar dot, today/tomorrow, the days figure at 0–1, and price-increase % text. Category palette index 0 changes from red to magenta: tile/light line `#AD1457`, dark line `#F06292`. Payment methods no longer use line colours. Their bars are neutral (secondary label colour) and their marker is card-shaped, so line colour means category only. Mixed-category clusters on the overview are interchange capsules in the rail colour. Full ink is reserved for the today ring, the leg and the next-station emphasis.
19. **Orange accent (user decision, 2026-10-21).** The brand accent changes from red to orange: graphics `#E8590C` (3.31:1 on `#F6F6F3`, 4.75:1 on `#1C1C1E`), text `#A84300` in light (5.59:1) and `#FF8A3D` in dark (7.26:1). It keeps every role amendment 18 gave the red: the menu-bar dot, the app icon's dot, today/tomorrow, the days figure at 0–1, and price-increase % text. Orange is now reserved for the accent, so category index 3 changes from orange to red: tile/light line `#C62828` (5.62:1 under a white letter, 5.19:1 on `#F6F6F3`), dark line `#EF5350` (4.88:1 on `#1C1C1E`). Index 0 stays magenta.

## Unresolved
- The exact panel height cap and the scroll behaviour on long lists. This is set at build time, but the first viewport must hold as above.
- The All and Spending tabs inherit the world: spine-less rows for All, and line-colour bars for Spending. They are composed at build time.
- The empty state, and how the overview line renders with zero or one charges.
