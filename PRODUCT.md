# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS 14+ app (SwiftUI + AppKit). Lives only in the menu bar (`LSUIElement`): a status item with an optional "days until next charge" counter, a panel opened by left click (tabs: Upcoming, All, Spending; a subscription card inside), a quick menu on right click, a main window «Year» (a grid of weeks or months, filters, a subscription page) opened from the panel footer, the quick menu, ⌘Y or a Dock click while the app is in the Dock (relaunching from Finder/Launchpad also shows it), a separate window for adding and editing a subscription, and a native Settings window. A Dock icon and a ⌘Tab entry appear while the Year window, an editor or Settings is open. Liquid Glass on macOS 26+, with a fallback on 14–15.

## Users

People with many subscriptions — the author first, then a public GitHub/DMG audience, Russian- and English-speaking. They:

- have lost count: a dozen or more services (software, AI tools, streaming, music, cloud storage), with no clear idea of the monthly total;
- get caught off guard by charges: a trial they forgot to cancel, a service they no longer use, not enough money on the card on the charge day;
- pay in several currencies and with several cards: some services in ₽, some in $ or €, sometimes from foreign cards, so totalling it up by hand is hard;
- do not want to hand their data to anyone: bank-linked or cloud subscription trackers need account access or a sign-up.

## Product Purpose

Know what will be charged, how much and when, and get a reminder early enough to act: 5, 3 and 1 day before every charge (configurable) and before every trial ends. Success: adding a subscription takes about 30 seconds; the monthly and yearly total in the user's base currency is always one click away; no charge or trial end comes as a surprise.

## Positioning

A subscription tracker that lives next to the clock, not on the phone. The days until the next charge are visible in the menu bar at a glance. It is fully local and private: no account, no server, no bank access, data stays on the Mac, and the code is open (GPL-3.0). Mixed ₽/$/€ subscriptions are totalled correctly at the official Central Bank of Russia rate, which most trackers handle poorly or not at all. Trials are first-class, with their own reminders saying "cancel now if you don't need it" before the first paid charge.

## Operating Context

The menu bar is glanced at in passing many times a day, and the panel is opened for a few seconds to check what is coming up. Subscriptions are added or edited rarely, in a focused moment, often with the service's website or a receipt email open alongside. Reminders arrive as system notifications while the user is doing something else; their job is to prompt one action: open the manage/cancel page, or ignore it. The app is used with light and dark menu bars, in Russian and English, and offline (cached exchange rates).

## Capabilities and Constraints

- Subscription: name, logo (own image, the site's icon fetched on request, or a monogram), price and currency, billing cycle (N days, weeks, months or years), first charge date, optional trial end date, optional end date, active/inactive, category, payment method (a free-text label, never card numbers), website, manage/cancel link, price history, per-subscription notification switch, notes.
- Upcoming charges are grouped as Today & tomorrow / This week / This month / Later (up to 30 days; each subscription once, at its nearest charge). Monthly and yearly totals are shown in the base currency. Spending is broken down by category and by payment method. Price increases from the last year are listed.
- Year window: the next 12 months from today as a commit-calendar grid of weeks or months, each cell toned by the number of charges; filters by category, card and status; a side pane with the charges of the chosen period; a page per subscription.
- Notifications: 5/3/1 days before by default (0–30, configurable), at 10:00 by default. Charge and trial-end reminders have different wording. There is a "Manage subscription" action.
- Currency: CBR daily rates, cached; offline the cached rate is used. A currency CBR does not list is left out of totals and flagged, never silently miscounted.
- Data: a local JSON file with automatic backup and recovery from corruption. JSON export/import (with logos) and CSV export/import.
- Network: only cbr.ru for rates, and — on an explicit "Fetch icon" click — the subscription's site and the HTTPS addresses it points to for its icon.
- Sandboxed, hardened runtime. Distributed as a DMG first; Developer ID signing and notarization are pending (account in progress). The App Store is possible later.
- Free in v1; no StoreKit.
- Localization: English (source) and Russian, following the system language, with an in-app override.
- Out of v1: iCloud sync, widgets, global hotkey, a catalogue of popular services (candidate for v1.1), manual payment log, shared subscriptions.

## Brand Commitments

- Name: **Subus** (final; derived from "subscriptions", no further brand meaning attached).
- Repository: https://github.com/aesarva/subus. Bundle ID `io.github.aesarva.Subus`.
- Sibling apps by the same author: Ochre (system metrics) and Lidless (keep-awake). Subus shares their conventions (native menu-bar utility, ru/en, DMG distribution) but not their visual identity.

## Evidence on Hand

No users, testimonials, screenshots or metrics yet. No brand assets (logo, icon) exist yet. Third-party service logos must not be bundled; logos come only from the user or from the service's own site at the user's request.

## Product Principles

- Nothing comes as a surprise: every charge and every trial end is announced early enough to act on.
- Private by construction: no account, no server, the network is touched only for exchange rates and an icon the user asked for.
- Honest numbers: totals never hide what they could not convert or what is still a trial; money is exact.
- At a glance first: the menu bar and the first panel answer "what's next and how much" without a click deeper.
- Native first: it should feel like part of macOS, with the brand carried by detail.

## Accessibility & Inclusion

Standard macOS expectations: VoiceOver labels for every row and control, full keyboard operation of the panel and form, Dynamic Type-independent but legible sizes, colour never the only carrier of meaning (accent states also carry text), Reduce Motion and Increase Contrast respected.
