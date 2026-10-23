# Security

Subus is a local, sandboxed menu-bar app. Its threat model is deliberately small:

- **Local data only.** Subscriptions, settings and cached rates are plain files in the app's sandbox container (`~/Library/Containers/io.github.aesarva.Subus/Data/Library/Application Support/Subus/`). Nothing is uploaded anywhere.
- **No accounts, no telemetry.** No sign-in, no analytics, no crash reporting, no server of ours.
- **Network scope.** The app talks only to `cbr.ru` for exchange rates, to `github.com` once a day for the update feed of this repository (and for the release DMG when you install an update), and, on an explicit **Fetch icon** click, to the subscription's own site and the HTTPS addresses it points to for its icon (https only, 5 s timeout, at most 3 redirects, responses up to 2 MB). Failures are logged locally and never sent anywhere.
- **Sandbox and entitlements.** App Sandbox with only `network.client`, `files.user-selected.read-write` (files you pick for import, export and logos) and a mach-lookup exception for `io.github.aesarva.Subus-spks` and `io.github.aesarva.Subus-spki`, the services of Sparkle's installer launcher through which a sandboxed app installs its update. Hardened runtime. No privileged helper of ours; when Subus sits where your account cannot write, macOS asks for an administrator password to replace it.
- **Updates.** Sparkle 2 installs an update only if the DMG carries a valid EdDSA signature from the key whose public half is in the app's Info.plist and the new app is signed with the same Developer ID.
- **No payment secrets.** A payment method is a free-text label such as "Visa •• 1234"; Subus has no field for, and never asks for, card numbers or bank credentials.
- **Signing.** Releases are signed with a Developer ID and notarized by Apple. Get them from the official [Releases](https://github.com/aesarva/subus/releases) page.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting for this repository (**Security → Report a vulnerability**). Include the macOS version, the Subus version, and steps to reproduce. You can expect an acknowledgement within a week.
