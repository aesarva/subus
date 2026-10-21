---
version: 1
slug: "app-year-yearview-swift"
primary_target: "App/Year/YearView.swift"
related_targets: ["App/Year/YearWindowController.swift","App/Year/SubscriptionPage.swift"]
---

# Surface brief — Subus Year window

## Scope
The main window "Year": a week/month grid of the next 12 months, a side pane (selected cell / all subscriptions), filters, and the subscription page pushed inside the same window. Mode: **Operate**. Opened from the panel footer, the quick menu, ⌘Y and a Dock click.

## Audience and task
The same people as the panel, in a focused moment rather than a glance: "which weeks and months are heavy, and with what; what does each subscription cost me over the year". User asks (2026-10-22): sums by month, every subscription and its charges, details — equal weight; a commit-calendar grid where a cell is a week or a month and its tone is the number of charges in it, five steps, weeks and months with a switch; beautiful, modern, convenient.

## Constraints
macOS 14+, native SwiftUI `.toolbar` (glass on 26 by the system), native controls only. ru + en, tabular figures. Reduce Motion, Increase Contrast respected. Spec: `docs/superpowers/specs/2026-10-22-year-window-design.md`.

## Direction contract

THESIS: The year is a commit calendar: one grid of weeks (or months) whose tone counts the charges in each cell, with the cell's charges one click away. It refuses the category dashboard of bar charts over a gallery of subscription cards.

OWN-WORLD: The world "The Line" from DESIGN.md: SF Pro with tabular figures, category = station ring in its line colour, `#E8590C` only for "now". The grid tone is a neutral five-step ramp (light `#E8E8E4` `#CFCFCA` `#A3A39D` `#5E5E5A` `#1D1D1F`; dark `#2C2C2E` `#48484A` `#6E6E73` `#A1A1A6` `#F2F2F0`) on a card `#FBFBF9` / `#232325` over the window ground; 7 pt cell corners, 6 pt gaps; rings drawn outside the cell through a ground-coloured gap.

STORY: The visitor opens the window and sees the year total, then the grid: dark weeks stand out at once. They click one and read its charges on the right; they switch to months for totals; they open a subscription and see its year, its charges and its price history.

FIRST VIEWPORT (1100 × 720):
- Toolbar: title "Year" with the period, Weeks/Months segmented control, category chips with rings, Filters menu with a count, search.
- Summary: "Charged in the next 12 months", the sum at 28 pt, a caption with count, monthly average, CBR date, trials.
- Left, in a card: the week grid, 13–14 month columns of 1–5 cells, month labels above, legend "fewer charges ■■■■■ more" with thresholds below; this week ringed in orange, the selected cell ringed in ink.
- Right, 320 pt min: Week | All subscriptions; the selected week's title, count and sum, its charge rows (logo, name, ring · date · card, amount and ≈ base).

FORM: Commit-calendar grid, pinned by the user after two composition rounds (rounds rejected: rising line, sidebar + bars, timetable, year ribbon, orbit, overview + gallery). seed: none (unavailable)
- Signature interaction: selecting a cell drives the side pane; arrow keys walk the grid; Return opens the cell's first subscription.
- Motion: none beyond the system push to the subscription page (instant under Reduce Motion).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
