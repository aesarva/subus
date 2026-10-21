---
name: Subus
description: A menu-bar subscription tracker drawn as a transit strip map; upcoming charges ride one line and today is the station you are at.
colors:
  accent: "#E8590C"
  accent-text-light: "#A84300"
  accent-text-dark: "#FF8A3D"
  tile-magenta: "#AD1457"
  tile-green: "#2E7D32"
  tile-blue: "#005A94"
  tile-red: "#C62828"
  tile-violet: "#7B3A96"
  tile-cyan: "#0A6F99"
  tile-brown: "#7A4E26"
  tile-yellow: "#7D6300"
  bright-magenta: "#F06292"
  bright-green: "#3FA34D"
  bright-blue: "#3D9BE9"
  bright-red: "#EF5350"
  bright-violet: "#B57BD6"
  bright-cyan: "#1EBCEF"
  bright-brown: "#C08A55"
  bright-yellow: "#F2C200"
  rail-light: "#8A8A83"
  rail-dark: "#75757A"
  ground-fallback-light: "#F6F6F3"
  ground-fallback-dark: "#1C1C1E"
  icon-ground-light: "#F4F3EF"
  icon-ground-dark: "#1C1C1E"
  icon-ink-light: "#1D1D1F"
  icon-ink-dark: "#F2F2F0"
  monogram-letter: "#FFFFFF"
typography:
  days-figure:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "44px"
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "-1px"
    fontFeature: "tnum"
  title:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    fontFeature: "tnum"
  body-strong:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    fontFeature: "tnum"
  body:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    fontFeature: "tnum"
  callout:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  action:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 500
  caption:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    fontFeature: "tnum"
  group-head:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.7px"
  month-label:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.6px"
  tag:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.4px"
  station-label:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    fontFeature: "tnum"
  menu-bar-counter:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  tag: "3px"
  card-mark: "1.5px"
  row-highlight: "6px"
  tile-24: "6px"
  tile-40: "10px"
  tile-56: "14px"
  capsule: "9999px"
spacing:
  receded-stroke: "1.5px"
  line-stroke: "3px"
  line-stroke-contrast: "4px"
  leg-stroke: "5px"
  tag-x: "5px"
  row-y: "5px"
  highlight-inset: "6px"
  row-gap: "10px"
  group-head-top: "12px"
  margin: "16px"
  spine-x: "26px"
  text-leading: "44px"
  row-min: "42px"
  overview-height: "60px"
  panel-width: "360px"
components:
  station-ring:
    textColor: "{colors.tile-magenta}"
    rounded: "{rounded.capsule}"
    size: "13px"
  station-ring-lifted:
    rounded: "{rounded.capsule}"
    size: "16px"
  station-ring-receded:
    rounded: "{rounded.capsule}"
    size: "9px"
  interchange-capsule:
    textColor: "{colors.rail-light}"
    rounded: "{rounded.capsule}"
    height: "18px"
  interchange-capsule-lifted:
    rounded: "{rounded.capsule}"
    height: "21px"
  overview-line:
    backgroundColor: "{colors.rail-light}"
    height: "{spacing.overview-height}"
  strip-row:
    typography: "{typography.body-strong}"
    padding: "5px 16px 5px 44px"
    height: "{spacing.row-min}"
  strip-row-lifted:
    rounded: "{rounded.row-highlight}"
  group-head:
    typography: "{typography.group-head}"
    padding: "12px 0 2px 44px"
  trial-tag:
    textColor: "{colors.tile-violet}"
    typography: "{typography.tag}"
    rounded: "{rounded.tag}"
    padding: "1px 5px"
  summary-header:
    typography: "{typography.title}"
    padding: "12px 16px 6px"
  days-figure-soon:
    textColor: "{colors.accent-text-light}"
    typography: "{typography.days-figure}"
  panel-banner:
    typography: "{typography.callout}"
    padding: "8px 16px"
  empty-state:
    typography: "{typography.body-strong}"
    padding: "36px 32px"
  spending-bar-category:
    backgroundColor: "{colors.tile-violet}"
    rounded: "{rounded.capsule}"
    height: "6px"
  spending-bar-payment:
    rounded: "{rounded.capsule}"
    height: "6px"
  monogram-tile:
    backgroundColor: "{colors.tile-blue}"
    textColor: "{colors.monogram-letter}"
    rounded: "{rounded.tile-24}"
    size: "24px"
  card-header-logo:
    rounded: "{rounded.tile-40}"
    size: "40px"
  panel-footer:
    typography: "{typography.action}"
    padding: "9px 16px"
  menu-bar-glyph:
    textColor: "{colors.accent}"
    size: "18px"
  app-icon:
    backgroundColor: "{colors.icon-ground-light}"
    textColor: "{colors.icon-ink-light}"
---

# Design System: Subus

## Overview

**Creative North Star: "The Line"**

Subus draws the next sixty days as a transit strip map. Today is the station you are at, on the left of a short horizontal line. Each upcoming charge is a station in its category's line colour. Below, the same charges hang off a vertical spine, grouped like the stops of a route. The world deliberately avoids the category default: a stack of rounded cards with brand-coloured logo tiles under a big total. There are no cards, boxes or row backgrounds in the panel. Hierarchy comes from scale and weight alone, and one large number answers "how long until the next charge".

The ground belongs to the system. The panel is a plain `NSPopover`: Liquid Glass on macOS 26, popover vibrancy on 14 and 15, and an opaque system popover under Reduce Transparency. Text uses semantic label colours, never hex inks. The only custom colours are the eight line colours, the eight monogram tiles, the rail grey, and one brand orange. Native controls carry everything interactive: the segmented control, search field, menu picker, switch, link buttons and borderless buttons.

Motion is stepped and minimal. When the day changes, the horizon slides one day left in two 90 ms steps with no easing, and it moves instantly under Reduce Motion. A lifted station grows. The other stations and rails recede by thinning; they never fade.

**Key Characteristics:**
- A 360 pt column on a system-material ground, with semantic text colours.
- Eight line colours. A line colour means a category and nothing else.
- One brand orange (#E8590C). It is spent on "now": the menu-bar dot, today and tomorrow, the days figure at 0–1, and steep price rises.
- Full ink (the label colour) on graphics is reserved for the today ring, the leg to the next station, and the next station's label.
- Text never dims. Focus changes only graphics and a faint row highlight.
- Tabular figures on every number.

## Colors

The ground is system material, and colour comes from a metro map: eight line colours, a grey rail, and one orange that means "now".

### Primary
- **Signal Orange** (`accent`): the brand accent, for graphics only. It fills the menu-bar glyph's centre dot, the accent dot inside today's ring on the overview, the accent dot inside a card stop due today or tomorrow, and the app icon's dot. It reaches 3.31:1 on #F6F6F3 and 4.75:1 on #1C1C1E, which passes for graphics but not for text in light.
- **Signal Orange Text** (`accent-text-light` / `accent-text-dark`): the accent wherever it is text. It reaches 5.59:1 on #F6F6F3 in light and 7.26:1 on #1C1C1E in dark. It colours the relative date "today" / "tomorrow" (semibold) in strip rows and card stops, the days figure at 0–1, the menu-bar counter at 0–1 (semibold), and a price rise of 10 % or more (semibold). It is a dynamic `NSColor` that resolves per appearance.

### Secondary: the line set
Each of the eight category indices has a colour pair: a **tile** colour that is also the light-theme line, and a **bright** colour for dark-theme lines. The indices run Magenta, Green, Blue, Red, Violet, Cyan, Brown, Yellow. No index is orange.
- **Tiles** (`tile-*`): the monogram tile ground behind a white letter. Each reaches at least 4.74:1 against white (5.13–7.27:1). The same colours are the line strokes in light, at 4.74–6.72:1 on #F6F6F3.
- **Bright** (`bright-*`): line strokes in dark, at 4.88–10.12:1 on #1C1C1E.
- Strokes come from `LinePalette.line(index, scheme)`: the tile set in light, the bright set in dark. Tiles always use the tile set.
- Violet (index 4) also outlines the Trial tag. The tag's text says "Trial", so the colour only frames it.

### Neutral
- **Rail** (`rail-light` / `rail-dark`): the resting rail, the strip-map spine, week and month ticks, mixed-category interchange capsules, and stations with no category. It reaches 3.21:1 on #F6F6F3 and 3.71:1 on #1C1C1E, so it carries meaning rather than decoration.
- **Ink**: `labelColor`, `secondaryLabelColor` and `tertiaryLabelColor` (SwiftUI `.primary` / `.secondary`), so themes and Increase Contrast adapt natively. Full ink on graphics belongs to the today ring, the leg, the next-station label and the 1 pt halo around a lifted station.
- **Row highlight**: the label colour at 7 % in light and 11 % in dark, in a 6 pt rounded rectangle inset 6 × 1 pt. It is the only fill a row ever gets.
- **Fallback grounds** (`ground-fallback-*`): the solid grounds the snapshot harness renders on, and the reference against which every ratio above is measured. They are not painted in the app; the popover owns its ground.

### Named Rules
**The One Reserved Ink Rule.** Full label colour on graphics appears in only three places: the today ring, the leg from today to the next station (5 pt, or 6 pt under Increase Contrast), and the next station's label. Cluster counts, ticks and month labels are secondary ink.

**The Orange Is the Accent Rule.** No custom orange exists apart from #E8590C and its text variant; no category line is orange. The panel's custom orange means "now": the menu-bar dot, today and tomorrow, the days figure at 0–1, and steep price rises. A new surface does not get the accent orange for emphasis, errors or decoration. Errors (the save-error banner, the editor's field and logo messages) use system red, `NSColor.systemRed`, never the accent or a line colour.

**The Line Means Category Rule.** A line colour on a station, spine, ring or bar always means the subscription's category. A subscription without a category rides the rail grey. Payment methods never take a line colour; their bars are secondary-label grey behind a card-shaped mark. Monogram tiles are the one separate use: a tile's colour is the subscription's own `colorIndex` (or a hash of its name), and two subscriptions may share one.

**The Text Never Dims Rule.** Hover, selection and focus change graphics (station size, stroke width) and the row highlight only. Text and amounts keep full opacity in every state. Even a pressed row button renders its label unchanged.

## Typography

**UI Font:** SF Pro (system), with tabular (monospaced) digits on every amount, date and count.

**Character:** Hierarchy comes from scale alone, using the system's own text sizes (body 13, subheadline 12, caption 11). Only one number is large. Nothing is set below 11 pt.

### Hierarchy
- **Days figure** (600, 44 pt, tracking −1, tabular): the days until the next charge, the panel's only large number. It sits on the right of the header in label colour, or in accent text at 0–1, with an 11 pt secondary caption under it.
- **Title** (600, 17 pt, tabular): the month total ("RUB 6,381 / month") and the card's subscription name. The total scales down to 80 % before it truncates.
- **Body strong** (600, 13 pt, tabular): row names, which take up to 2 lines and then tail-truncate, and amounts, which never truncate or compress.
- **Body** (400, 13 pt, tabular): spending-bar names, card fact values and card stop dates.
- **Callout** (400, 12 pt): banner messages, empty-state messages, card fact labels, the footer count and the quiet "no charges" line.
- **Action** (500, 12 pt): footer, card action bar, link buttons ("Manage subscription ↗") and banner actions.
- **Caption** (400, 11 pt, tabular, secondary): row meta ("in 3 days · Fri, Oct 23 · Revolut •• 0815"), header notes, group sums, shares and "/ month".
- **Group head** (600, 11 pt, tracking 0.7, uppercase, secondary): strip-map groups, Spending sections, card sections and the Inactive head.
- **Month label** (600, 11 pt, tracking 0.6, uppercase via the formatter, secondary): the overview's month names.
- **Tag** (600, 11 pt, tracking 0.4, uppercase): Trial, Ended and Inactive.
- **Station label** (600, 11 pt, primary): "23 · ChatGPT Plus +1" above the next station.
- **Menu-bar counter** (system font size, tabular): " 3d" in label colour, or semibold accent text at 0–1.

### Named Rules
**The One Large Number Rule.** The 44 pt days figure is the only display-size number. Totals stay at 17 pt or less.

## Layout

The panel is a fixed 360 pt column. Its height is the content height, capped at the screen's visible height minus 80 pt. A custom `CappedColumn` layout pins every child except one scrolling part. On Upcoming, the segmented control, banners, header and overview line are pinned, the strip map scrolls, and the footer is pinned. On the card, the back bar is pinned, the body scrolls, and the action bar is pinned. The popover's `contentSize` follows the hosting controller's preferred size.

- **Margins:** 16 pt left and right on every block. The overview line is inset by the same 16 pt.
- **Strip map geometry:** the spine is at x = 26 pt and row text starts at 44 pt. Inside the overview, today's ring sits 10 pt in, so with the 16 pt inset it lines up with the spine. Rows are at least 42 pt tall, with 5 pt vertical padding and a 10 pt gap between the 24 pt tile and the text, and they grow to fit. Group heads have 12 pt above and 2 pt below. Group sums are right-aligned, 16 pt from the edge.
- **Overview geometry:** 60 pt tall. The rail sits at y = 25, from x = 10 to 8 pt short of the right edge. A charge sits at x = days × (rail width / 60). Stations closer than 14 pt merge into an interchange. No station sits nearer today's ring than a 12 pt visible leg. Week ticks are 4 pt and month ticks 8 pt, drawn 8 pt below the rail. Month labels sit 18 pt below the rail.
- **Header:** 12 pt top, 6 pt bottom, 12 pt between the totals column and the days figure, bottom-aligned. The notes block grows downward in a fixed order: year total, CBR rate date, trials at their future price, excluded subscriptions.
- **Spending rows:** 6 pt vertical padding, a 9 pt gap between the marker and the name, and a 6 pt share line indented to the name.
- **Card stops:** at least 34 pt tall, on a short spine at the same x = 26.
- **Rhythm:** 2/3 pt within a text stack, 5–6 pt between a row and its line, 8–10 pt between elements, 12–16 pt above section heads.
- **Copy:** English and Russian wrap inside the column and never widen it. The meta line gives way in a fixed order: first the payment label truncates (to no shorter than 48 pt, else it is dropped), then the weekday goes. The relative date never truncates.

## Elevation & Depth

The panel is flat. Depth belongs to the system popover: its material (glass or vibrancy), its system shadow and its arrow. The panel draws no shadow of its own.

- **macOS 26:** Liquid Glass is the system's own `NSPopover` rendering. There is no custom `glassEffect`.
- **macOS 14–15:** the popover's vibrancy.
- **Reduce Transparency:** the system's opaque popover.
- The popover window is made key on open, so glass and native controls render active.
- Stations and capsules knock the rail out with a clear blend, so the rail stops at a ring's edge without a painted ground behind it. This keeps them correct on any material.
- The only fills are the row highlight and the share-line track: the rail colour at 28 %, or 45 % under Increase Contrast.

### Named Rules
**The System Owns the Ground Rule.** One container owns the background: the `NSPopover`. Views paint no panel background, card surface or row fill. The fallback hexes exist only for snapshots and contrast checks.

## Shapes

The geometry is circles and lines: hollow station rings, round-capped rails, and capsule interchanges and share lines.

- **Strokes:** 3 pt at rest, 4 pt under Increase Contrast. Receded strokes are 1.5 pt (2 pt under Increase Contrast). The leg is the line stroke + 2 pt.
- **Station sizes:** 13 pt at rest, 9 pt receded, 16 pt lifted. A lifted station adds a 1 pt label-colour halo 2 pt outside.
- **Corners:** small and continuous. Tags are 3 pt, the row highlight 6 pt, and the payment card mark 1.5 pt (10 × 7 pt). Logo tiles use 25 % of their side (24 → 6, 40 → 10, 56 → 14).
- **Outlines:** tags are 1 pt outlines, never filled. Nothing in the panel has a border or box.

## Components

### Station Ring
A hollow circle in the category's line colour, 13 pt with a 3 pt stroke. It marks a charge on the overview and on the strip spine, and marks a category in All rows, card facts and Spending bars. On the canvases it clears what is under it. States: rest, receded (9 pt, 1.5 pt stroke, still opaque) and lifted (16 pt, plus a 1 pt ink halo). It is hidden from VoiceOver.

### Interchange Capsule
Charges closer than 14 pt on the overview merge into a capsule. It is 18 pt tall (21 pt lifted, with an ink halo) and spans the merged stations. Its stroke is the shared line colour when every charge in it has the same category, otherwise the rail colour. The count is centred inside in 11 pt semibold secondary ink. A capsule keeps its size when it recedes; only the stroke thins. Hovering reveals every charge in a tooltip and in the station label.

### Overview Line
A 60-day rail in rail grey with week and month ticks, month labels, and today's ring at the left: a 15 pt outer ring in full ink. When something is due today, that ring is the station: it carries an accent dot and there is no leg. Otherwise the leg runs from today to the next station in full ink. Only the next station is labelled ("23 · Name +N"), and the label is clamped inside the rail ends. Hovering a station lifts it and its strip rows. On a day change the horizon slides in two 90 ms steps. VoiceOver reads it as one element: "Next 60 days: N charges; next in N days: name, amount".

### Strip Row
One button per charge:
- left to right: a station on the spine, a 24 pt logo or monogram tile, the name (13 semibold, with a Trial tag inline or wrapped below it), and the amount (13 semibold tabular) tight to the right margin;
- under the name, one caption line: relative date · date · payment label;
- "today" and "tomorrow" are semibold accent text;
- a lifted row gets the highlight only;
- the VoiceOver label is "name, in N days, date, amount, category[, trial]".

All rows are the same row without the spine. Their meta is the category's station ring and name, plus a status ("Ended …" / "Inactive"), and the price sits over "/ cycle".

### Group Head
Tracked uppercase caption, semibold, secondary, aligned to the row text at 44 pt: Today & tomorrow · This week · This month · Later. A converted sum ("≈ RUB 1,632", "+ N not converted") closes a group in secondary caption. It appears only when it adds information: more than one charge, or a conversion.

### Summary Header with Notes
On the left, the 17 pt month total. Under it, the notes block in 11 pt secondary: year total, "CBR rate on …", "includes N trials at their future price", "excluding N subscriptions (no rate)". When every subscription is excluded, the total reads "—", never 0. On the right is the 44 pt days figure with its caption; it is omitted on Spending.

### Panel Banner
A one-line notice under the tabs:
- **Layout:** a 12 pt semibold SF Symbol in the banner's tint, a 12 pt message, one link-style action, and a divider inset 16 pt.
- **Order:** save error, then data recovered, then notifications off. At most two show.
- **Dismiss:** only "notifications off" has a dismiss ×, which hides it for the session.
- **Tints as built:** save error uses system red (`systemRed`), recovery uses system orange, notifications off uses secondary.

### Empty State: "You Are Here"
A centred calm state with 32 × 36 pt padding: a 13 pt semibold title, a 12 pt secondary message, and one large prominent native button. With no symbol, it carries the world's own mark: today's ring in ink on a short bare rail (64 × 20 pt), with no station after it. Search and filter misses use an SF Symbol instead. "All subscriptions are paused" links to All.

### Spending Bar
- **Row:** a marker, the name (13 regular), the monthly amount (13 semibold tabular) and the share (11 secondary tabular, at least 34 pt wide), over a 6 pt capsule share line on a faint rail track. A sliver is never shorter than 6 pt.
- **Category:** a station ring and a share line in the category's line colour.
- **Payment method:** a 10 × 7 pt card-shaped outline and a share line in secondary-label grey, because line colours belong to categories.
- **Payment section:** hidden when no live subscription has a payment method.
- **Price increases:** listed below as strip-style rows: "old → new", and "+N %" in semibold accent text at 10 % or more, secondary otherwise.

### Subscription Card
Pushed inside the panel, never a separate surface:
- **Back bar:** "‹ Back", or Esc.
- **Header:** a 40 pt tile, the 17 pt semibold name with a Trial, Ended or Inactive outline tag, today's price per cycle, "≈ … / month" for other cycles, "→ <amount> from <date>" in 11 pt secondary when a later price is scheduled, and "Manage subscription ↗" as a link.
- **Sections:** "Next charges" shows up to three stops on a short spine in the category colour; a stop due today or tomorrow gets an accent dot and accent text. "Details" is a grid with the category as a station ring and name. "Price history" shows only when there is more than one entry.
- **Action bar:** pinned. A small Active switch, Edit, and "Delete…" in system red, which opens a confirmation dialog.

### Menu-bar Glyph and Counter
An 18 × 18 pt renewal ring:
- **Ring and arrow:** a radius-6 open arc and an arrow head at the top right, both 2 pt round-capped strokes in `labelColor`.
- **Dot:** a filled 5.2 pt centre dot in #E8590C.
- **Drawing:** non-template, so the dot stays orange on light and dark menu bars.
- **Counter:** " Nd" after the glyph, in tabular digits. It is label colour normally, and semibold accent text at 0–1 days. With no future charge, or with the setting off, only the glyph shows.
- **Accessibility label:** "Subus, next charge in N days: name".

### App Icon
An Icon Composer `.icon` with no glass and no translucency, and a neutral shadow at 50 %:
- **Light:** a #F4F3EF ground with the renewal ring and arrow in #1D1D1F (88/1024 stroke).
- **Dark:** a #1C1C1E ground with the ring in #F2F2F0.
- **Dot:** a #E8590C centre dot (r 114.4/1024) in both.

The dark Dock/Finder rendition is unverified; no capture of it exists.

### Native Windows (Editor, Settings)
These stay standard SwiftUI `Form` / `TabView` in system appearance and inherit only palette tokens:
- the editor's 56 pt logo preview with the eight tile swatches (18 pt circles, 2 pt primary ring when selected); its drop-target ring is a 3 pt `controlAccentColor` border;
- the category swatches in Settings (line colours);
- monogram tiles.

Payment methods in Settings show no colour swatch. None of the panel's line drawing, tracked heads or row grammar appears in these windows.

## Do's and Don'ts

### Do:
- **Do** get every stroke colour from `LinePalette.line(index, scheme)`: the tile set in light, the bright set in dark, and the rail for no category.
- **Do** keep strokes at 3 pt and move them to 4 pt under Increase Contrast. Let receded graphics thin to 1.5 / 2 pt rather than fade.
- **Do** use `accentText` for any accent text and `accent` (#E8590C) for accent graphics.
- **Do** pair every colour state with words: "today" / "tomorrow", "Trial", "+33 %", the category name.
- **Do** use tabular digits on every number, and keep amounts uncompressed and tight to the right margin.
- **Do** let the `NSPopover` own the ground and use semantic label colours for text.
- **Do** keep the editor and Settings native, inheriting only tiles and line swatches.
- **Do** step the horizon in two 90 ms unseasoned steps, and make it instant under Reduce Motion.

### Don't:
- **Don't** put cards, boxes, borders or row backgrounds in the panel. The 7 % / 11 % row highlight is the only fill.
- **Don't** lower the opacity of text or amounts on hover, selection or press.
- **Don't** give a payment method, an error, a state or a decoration a line colour.
- **Don't** add another custom orange, or spend the accent outside "now" and steep price rises.
- **Don't** put full label-colour ink on graphics other than the today ring, the leg, the next-station label and the lifted halo.
- **Don't** add a second large number. The 44 pt days figure is alone.
- **Don't** set text below 11 pt.
- **Don't** bundle third-party brand logos. Use a monogram tile, the user's image or the site's icon.
