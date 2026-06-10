# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS menu-bar (agent, no Dock icon — `LSUIElement = YES`) subscriptions tracker. SwiftUI + SwiftData, zero external dependencies. Requires macOS 26+ / Xcode 26+. The local directory is `subscriptions-watcher`, but the GitHub repo is `pro-verstka/subscriptions-tracker` — the in-app updater and release tooling use the latter.

## Commands

```bash
./scripts/build.sh                     # Release build → build/SubscriptionsTracker.app
open build/SubscriptionsTracker.app    # run it
```

`build.sh` builds unsigned via `xcodebuild`, then re-signs: with a "SubscriptionsTracker Developer" cert if present in the keychain, otherwise ad-hoc. In Xcode: open `SubscriptionsTracker.xcodeproj`, scheme **SubscriptionsTracker**, ⌘R.

There is no test target and no linter configured.

## Releasing

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds, packages (zip + dmg via `scripts/package-release.sh`), generates notes (`scripts/generate-release-notes.sh`), and publishes a GitHub release. CI **fails if the tag doesn't match the app version** — bump `MARKETING_VERSION` (appears twice in `project.pbxproj`) before tagging.

The zip asset name `SubscriptionsTracker-macos.zip` is load-bearing: `UpdateService` finds the update asset in the latest GitHub release by that exact name.

## Architecture

Three process-wide singletons wire everything together:

- **`AppModelContainer.shared`** (Persistence/) — the single SwiftData `ModelContainer`. Creating a second container against the same store URL throws, so both the SwiftUI scene and non-UI code (`NotificationScheduler`, `SubscriptionStore`) must go through this one instance.
- **`AppSettings.shared`** (Logic/) — `ObservableObject` over `UserDefaults` (notifications toggle, sort order, currency grouping).
- **`UpdateService.shared`** (Logic/) — self-update state machine (`UpdateState`), published to the UI.

**Data model.** `Subscription` (`@Model`) stores its billing period as a raw string (`periodRaw`) for SwiftData schema stability; typed access goes through the computed `period: BillingPeriod`. Money arithmetic is `Decimal` only (`TotalsCalculator`, `BillingPeriod.monthlyFactor`). Renewal dates are computed, not stored: `nextRenewal` rolls the stored date forward via `Calendar` steps (`RenewalDate.nextOccurrence`).

**Notifications.** `NotificationScheduler.reschedule` is reset-and-rebuild: it removes *all* pending requests and re-adds one per subscription. `MenuContentView` triggers it via `onChange` of a `schedulingFingerprint` string derived from the fields that affect scheduling. It copies `@Model` fields into a `Snapshot` struct before crossing async boundaries (`@Model` is not `Sendable`).

**Self-update.** `UpdateService` polls the GitHub releases API (on launch + ~daily), downloads the zip, unzips with `ditto`, strips quarantine, then writes a temp bash script that waits for the app's PID to exit, replaces the bundle in place, and relaunches. This is why **App Sandbox is intentionally disabled** — the entitlements file is deliberately empty (see the comment in `SubscriptionsTracker.entitlements`). Don't add sandbox entitlements.

**Menu-bar window quirks** (see comments in `MenuContentView`): the `MenuBarExtra` uses `.window` style, which closes on focus loss — so the add/edit form is rendered inline in the same window instead of a `.sheet`. The list area has a fixed height (`listHeight = 420`) because dynamic sizing made the auto-sized window collapse.

## Conventions

- Doc comments and inline comments are written in **Russian**; UI strings, identifiers, and log/error messages are in English. Follow this in new code.
- No external dependencies — keep it that way (it's an advertised feature).
