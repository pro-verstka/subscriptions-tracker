# Subscriptions Tracker

Subscriptions in your macOS menu bar. A vibecoded app that tracks your subscriptions,
renewal dates and total monthly spend — right from the menu bar, no Dock icon.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![No dependencies](https://img.shields.io/badge/dependencies-none-green)

## Features

- Lives in the menu bar, no Dock icon (agent app)
- Add / edit / delete subscriptions: name, amount, currency (`$ / € / ₽`), period
  (week / month / year), renewal date, reminder N days ahead
- Monthly totals grouped by currency (no conversion)
- Colored renewal progress bars — the closer the charge, the redder
- Local renewal notifications (toggleable)
- Import / export subscriptions as JSON
- Automatic update checks with one-click install from GitHub releases
- Built on SwiftUI + SwiftData, no external dependencies

## Releases

The release build is unsigned and not notarized, so macOS Gatekeeper may show a warning on first launch.

If macOS says the app is damaged, remove the quarantine attribute after unpacking the release:

```bash
xattr -rd com.apple.quarantine /Applications/SubscriptionsTracker.app
```

## Custom build

Requires macOS 26+ and Xcode 26+.

```bash
./scripts/build.sh
```

The app bundle will be at `build/SubscriptionsTracker.app`.

```bash
open build/SubscriptionsTracker.app
```

In Xcode, open `SubscriptionsTracker.xcodeproj`, pick the **SubscriptionsTracker** scheme and Run (⌘R).

## Updates

The app checks GitHub releases for a newer version on launch (and roughly once a day),
and you can also check manually in **Settings → Updates → Check for Updates**. When a newer
version is available, one click downloads the release `.zip`, replaces the app in place and
relaunches it. Auto-checking can be turned off in Settings.

To make in-place self-update possible, **App Sandbox is disabled** (the sandbox forbids
replacing the app bundle and unrestricted network access). Settings and subscriptions are
stored locally on the Mac.

## Notifications

Local notifications fire N days before a renewal (per subscription). The **Renewal
notifications** toggle in Settings enables/disables them entirely. The system asks for
permission on first enable.

## Project layout

```
SubscriptionsTracker/
├── SubscriptionsTrackerApp.swift   # @main, MenuBarExtra / Settings / About scenes
├── Models/                         # Subscription (@Model), BillingPeriod
├── Persistence/                    # shared SwiftData ModelContainer
├── Logic/                          # totals, renewal dates, notifications, settings, import/export
├── Views/                          # menu, form, row, settings, About
└── Assets.xcassets/                # app icon
scripts/                            # build.sh, package-release.sh, generate-release-notes.sh
```

Data is stored locally via **SwiftData**. Releases are published automatically by the
GitHub Actions workflow on `v*` tags (`.github/workflows/release.yml`).
