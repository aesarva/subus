# Security

Subus is a local, sandboxed menu-bar app. Its threat model is deliberately small:

- **Local data only.** Subscriptions, settings and cached rates are plain files in the app's sandbox container (`~/Library/Containers/io.github.aesarva.Subus/Data/Library/Application Support/Subus/`). Nothing is uploaded anywhere.
- **No accounts, no telemetry.** No sign-in, no analytics, no crash reporting, no server of ours.
- **Network scope.** The app talks only to `cbr.ru` for exchange rates and, on an explicit **Fetch icon** click, to the subscription's own site and the HTTPS addresses it points to for its icon (https only, 5 s timeout, at most 3 redirects, responses up to 2 MB). Failures are logged locally and never sent anywhere.
- **Sandbox and entitlements.** App Sandbox with only `network.client` and `files.user-selected.read-write` (files you pick for import, export and logos). Hardened runtime. No privileged helper, no root access.
- **No payment secrets.** A payment method is a free-text label such as "Visa ·· 1234"; Subus has no field for, and never asks for, card numbers or bank credentials.
- **Current limit.** Releases are not yet signed with a Developer ID or notarized, so the download is only as trustworthy as the copy you obtained. Get it from the official [Releases](https://github.com/aesarva/subus/releases) page.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting for this repository (**Security → Report a vulnerability**). Include the macOS version, the Subus version, and steps to reproduce. You can expect an acknowledgement within a week.
