# Fit — Personal Sport Progress Logger

A private, local-first iPhone app for logging strength training with low friction
and exporting clean, structured data for analysis by an **external** AI. The app
itself contains **no AI, no backend, no accounts, no tracking** — it is a fast,
accurate capture-and-export tool.

> Built to support concrete goals: a 100 kg bench press, better pull-ups, and
> bigger back/biceps — by capturing weight, reps, effort and context over time.

## Status

This repository contains the complete SwiftUI + SwiftData source for the MVP.
It was authored in a Linux environment (no Xcode toolchain available here), so it
has **not been compiled**; open it in Xcode 16+ to build and run. It was reviewed
for cross-module consistency, SwiftData/CloudKit correctness, and compilation
hazards before commit.

## Requirements

- **Xcode 16 or newer** (the project uses Xcode-16 file-system-synchronized
  groups, so new files under `Fit/` are picked up automatically — no
  `project.pbxproj` surgery needed).
- **iOS 17+** target (SwiftData + CloudKit + Swift Charts).
- A **real iPhone** to exercise HealthKit (the Simulator has no Health data; the
  app guards for this and still runs).
- An **Apple Developer team** for signing, because the app declares HealthKit and
  CloudKit entitlements.

## Build & run

1. Open `Fit.xcodeproj` in Xcode.
2. Select the **Fit** target → *Signing & Capabilities* → set your **Team**.
   - The bundle id is `com.weboko.fit` and the iCloud container is
     `iCloud.com.weboko.fit`. Change both to match your team if needed
     (`Fit/Fit.entitlements` + the `PRODUCT_BUNDLE_IDENTIFIER` build setting).
   - Capabilities already declared: **HealthKit**, **iCloud → CloudKit**,
     background push (for CloudKit sync). HealthKit usage strings are set via
     `INFOPLIST_KEY_NSHealthShareUsageDescription`.
3. Build & run on your device.

If you have no paid team / CloudKit set up, the app still works: the persistence
layer tries a CloudKit-mirrored store first and **falls back to a local-only
store** automatically (see `PersistenceController`). Everything works offline.

## Architecture

Apple-native, modular, no third-party dependencies.

```
Fit/
  AppShell/          @main app + 5-tab root (Today, History, Exercises, Export, Settings)
  DomainModels/      SwiftData @Model types + all option enums (stable string raw values)
  Persistence/       ModelContainer (CloudKit + local fallback), seed data, preview data
  Shared/            formatting/units, design tokens, deterministic StatsKit,
    Components/       reusable UI: weight/reps entry, 0–5 scale, option chips,
                      exercise picker, charts, cards
  WorkoutLogging/    live active-workout screen + fast set entry + finish/questionnaire
  ExerciseLibrary/   searchable library, detail + stats/charts, edit, aliases, merge
  HealthImport/      read-only HealthKit service + permission UI + workout linking
  HistoryJournal/    history by date, workout/set edit, backfill, journal timeline
  Export/            isolated CSV/JSON/ZIP engine + export UI + single-workout share
  Settings/          units, iCloud status, health, data management, about/privacy
```

Dependency direction: feature modules depend on `DomainModels` + `Shared`; the
**Export** engine depends only on the domain models and never the other way
round (it is pluggable/replaceable). `WorkoutLogging` and `HistoryJournal` embed
two small cross-module views — `HealthLinkSection(session:)` (HealthImport) and
`WorkoutShareButton(session:)` (Export) — by their published view APIs only.

### Storage

- **SwiftData** with **CloudKit** mirroring (`ModelConfiguration(cloudKitDatabase:)`).
  Chosen over Core Data for tighter SwiftUI integration and simpler migrations.
- CloudKit-safe modeling throughout: every stored attribute has a default, every
  relationship is optional, no `.unique` constraints.
- All option fields are stored as **stable lowercase string raw values** (never
  integer positions) via typed accessors, so the schema and exports stay stable.
- Timestamps are timezone-aware; the session's IANA timezone is captured.

### Effort / context capture

- Effort is a friendly **0–5** scale (per set). Energy and stress are 0–5 (per
  session). "Reps in reserve" is asked as *"How many more clean reps were left?"*
  rather than the jargon "RIR".
- Optional per-set: form quality, limiter (what stopped the set), pain
  severity + location, warm-up/failed flags, notes.
- Optional per-session: goal, energy, soreness, pain today, sleep, plus
  second-priority fields (bodyweight, stress, location, food timing, caffeine).
- Nothing is required beyond weight + reps for normal weighted sets; bodyweight
  and pull-up modes (bodyweight / assisted −kg / weighted +kg) are first-class.

## Export

The export module is deliberately isolated and AI-agnostic. It produces:

- **CSV** — one file per entity with the spec's exact column names:
  `workouts.csv`, `sets.csv`, `exercises.csv`, `exercise_aliases.csv`,
  `health_workouts.csv`, `heart_rate_summary.csv`, `body_weight.csv`,
  `sleep.csv`, `journal_entries.csv`, plus `export_manifest.json`.
  (A few derived columns — effective load, volume, est. 1RM — are appended as
  extras; the required columns keep their exact spec names.)
- **JSON** — a single nested document (`fit_export.json`) preserving the full
  structure (workouts → session metadata, sets, linked health workout, journal).
- **ZIP** — bundles the CSV set, manifest and JSON into one archive (zipped with
  `NSFileCoordinator`, no third-party dependency).

Scopes: all data, last 7 / 30 / 90 days, this year, custom range, selected
workouts, or selected exercises; with include/exclude toggles for Health,
journal, body weight and sleep. Output goes through the iOS **Share Sheet**
(Files, iCloud Drive, AirDrop, Mail, etc.). Everything runs offline.

All weights are stored and exported in **kilograms**; the chosen display unit
(kg/lb in Settings) only affects what you see and type.

## Privacy

No custom backend. No analytics SDK. No ads. No third-party tracking. No AI/LLM
API calls. Data lives on the device and in your private iCloud. HealthKit access
is **read-only** and requested only when needed. Export is always user-initiated.

## Apple Health

The app imports (read-only) Apple Health / Apple Watch workouts, heart-rate
summaries, body mass and sleep, and lets you link a manual session to an
overlapping Health workout. Imported records are marked as such and never
silently overwrite manually entered data.

## Not included (by design, per spec)

No AI coaching/recommendations, no nutrition/macro tracking, no social features,
no subscriptions, no Android/web/Watch-only app, no custom export schemas yet.
These are explicit non-goals for the MVP.
