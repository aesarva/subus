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
- Signature interaction: hovering a station on the overview, or moving the selection with the arrow keys, lifts its row in the strip map and dims the others to 45%. When the day changes, the "you are here" ring steps forward.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Unresolved
- The exact panel height cap and the scroll behaviour on long lists. This is set at build time, but the first viewport must hold as above.
- The All and Spending tabs inherit the world: spine-less rows for All, and line-colour bars for Spending. They are composed at build time.
- The empty state, and how the overview line renders with zero or one charges.
