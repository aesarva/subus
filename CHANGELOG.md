# Changelog

## Unreleased

- While an add, edit or Settings window is open, Subus shows in the Dock and in ⌘Tab, so a half-filled form behind the browser is one click away; it returns to the menu bar alone when the last one closes.
- "New Subscription" opens an empty form again instead of the last one closed.
- The brand accent is now orange (#E8590C): the menu-bar dot, the app icon, today and tomorrow, and the days figure at 0–1. The orange category colour becomes red.

## 0.1.0 — 2026-10-20

- Menu-bar panel with Upcoming, All and Spending tabs; charges grouped as Today & tomorrow, This week, This month and Later.
- Subscription card with the next charges, price history, a "Manage subscription" link and an active switch.
- Add and edit subscriptions in a separate window: price and currency, billing cycle in days, weeks, months or years, trial end, end date, category, payment method label, website, notes.
- Reminders 5, 3 and 1 day before every charge and before every trial ends (configurable, 0–30 days, at 10:00 by default), with a "Manage subscription" action when the subscription has a manage link.
- Totals per month and per year in your base currency at the Central Bank of Russia rate; cached for offline use. Currencies the bank does not list are left out and flagged.
- Spending by category and by payment method, and a list of price increases over the last year.
- Logos: your own image, the site's icon on request, or a monogram.
- Optional days-until-next-charge counter in the menu bar.
- Export to JSON (with logos) and CSV; import with a preview; automatic backup and recovery from a corrupted data file.
- English and Russian, following the system language or chosen in Settings.
- Universal (Apple Silicon + Intel), macOS 14+. Not notarized yet — see README for how to open it.
