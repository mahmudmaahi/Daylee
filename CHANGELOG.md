# Changelog

All notable changes to DayLee are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). The number after `+` is the build number (Android `versionCode`).

## [1.0.0] - 2026-10-14 (build 1)

First release.

### Added
- **Finance** with cash and online (bank / mobile) wallets, a per-cycle allowance, expenses, income,
  transfers between wallets, savings (set aside / new money / release) and a cycle statement split by cash and online.
- Leftover cash carries over to the next cycle automatically; a helper records the matching online savings.
- **Home dashboard**: left to spend, spent today, daily average, safe-per-day, weather, next prayer, recent activity.
- **Prayer times** calculated offline (several methods, Hanafi / Shafi'i Asr, per-prayer minute offsets),
  per-prayer reminders, and custom reminders (daily, weekly, selected days, monthly, once).
- **Weather** (opt-in, uses your location): temperature, humidity, rain chance, wind.
- **Notifications**: prayer alerts, daily expense reminder, 80 % / 100 % budget alerts.
- Settings: theme, accent colour, font size, density, currency, cycle start day, categories, app lock,
  CSV export, backup & restore, reset.
- In-app version information (Settings → About).

### Fixed
- Replaced the previous finance engine with a ledger-based one: online expenses are no longer deducted twice,
  savings can no longer go negative or exceed the money in a wallet, and wallet totals can no longer drift.
- Scheduled notifications now fire (missing Android receivers and R8 rules).
