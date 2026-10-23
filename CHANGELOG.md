# Changelog

## 1.0.0 — 2026-10-24

- Subus updates itself: once a day it checks GitHub for a new version, shows it in the panel with a badge on the menu-bar icon, and installs it with one click on "Install and Relaunch" (Sparkle 2; every update is checked against the release signature and the Developer ID). Automatic checks can be turned off in Settings → General, next to "Check Now".
- Signed with a Developer ID and notarized by Apple: Subus opens without a Gatekeeper workaround.
- Settings is a standard macOS Settings window with the tabs in its toolbar.
- A "Year" window (⌘Y, panel footer, quick menu, Dock click): the next 12 months as a commit-calendar grid of weeks or months toned by the number of charges, with filters, a side pane and a page per subscription.
- Upcoming covers the next 30 days and shows each subscription once, at its nearest charge; reminders still plan 60 days ahead.
- Create a category or a card right from the subscription form.
- Add a card by choosing one of your saved cards (macOS AutoFill); Subus keeps only its last 4 digits.
- Any colour for a category; lines stay legible in light and dark.
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
- Universal (Apple Silicon + Intel), macOS 14+. Not published; first public release is 1.0.0.
