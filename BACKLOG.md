# Fit — Product Backlog

Living backlog for the Fit strength-training logger, groomed continuously. Each
item ships as its own pull request, based on the previous (merged) work on
`main`. Checked items are merged.

**Conventions**
- One feature → one branch `claude/feat-<id>-<slug>` → one PR → merge into `main`.
- Keep the app compiling: additive, self-contained changes; reuse `Shared/`
  components and the existing SwiftData models / typed enum accessors.
- No AI in the product, no network, no third-party deps, weights stored in kg.
- Every item must update this file (tick its box, add follow-ups discovered).

---

> **Milestone (2026-06-28):** F24 landed a real macOS compile gate and the first
> ever build **failed** — `main` did not compile (a non-existent
> `Section(_:content:footer:)` initializer + a MainActor-isolation error that 18
> review-only PRs had all missed). Both fixed; `main` is now green. A full
> read-only SPEC audit (see `scratchpad/audit-report.md`) confirmed the app is
> **strongly coherent with SPEC.md**, no-AI/no-network clean, with no other
> crash/compile hazards — only low-severity defects in the optional import path.
> Grooming below folds in that audit. The "Later" tier is no longer blind: every
> PR is compiled by CI before merge.

> **Product-state note (ruthless-PM honesty):** after 8 features this session the
> app is **strongly SPEC-coherent** (per the audit), compile-gated AND test-gated
> on StatsKit / PR detection / CSV parsing / the export contract. The genuinely
> high-ROI, SPEC-aligned, low-risk queue is exhausted of pure data-quality work.
> The remaining substantive feature is the **widget (F14)** — a legitimate
> product evolution (engagement value), now promoted to "Now". After F14, the
> backlog is genuinely empty of clearly-valuable work: prefer pausing for new
> user direction over manufacturing noise (do NOT add UI localization, AI, social,
> or other SPEC non-goals).

## Now (next up) — ROI-ranked
- [ ] **F31 — Full export→import round-trip test** (next up; the FINAL clearly-valuable item)
  Locks the app's literal reason for existing (SPEC §1/§30: capture → export
  cleanly so an external AI can analyze it). F28 locked CSV column *names*; F30
  locked import doesn't-blank; nothing yet verifies **end-to-end data fidelity**.
  Now possible (model-level tests unlocked by F30): build a rich dataset in the
  shared test container (a workout with session metadata, several sets across
  weight modes incl. effort/limiter/pain, an exercise + alias, a body-weight +
  sleep + journal entry), run the REAL `DataExportService` → JSON, import into a
  FRESH context via `DataImportService.importJSON`, and assert every field
  round-trips (ids, enums, kg values, timestamps, notes). High value, low risk
  (no app-code change — pure test). After this the test suite comprehensively
  covers the core (stats, PR, CSV parse, export contract, schema doc, import
  integrity, merge, full round-trip).
- _After F31: the product is **comprehensively complete and test-covered**, and
  the clearly-valuable / SPEC-aligned backlog is genuinely exhausted. The loop
  should then **pause for new user direction** (new features, a redesign, a
  real-device build pass, App Store prep) rather than manufacture noise — do NOT
  add SPEC non-goals (UI localization, AI, social) or low-value busywork._

## In progress
- _(idle — nothing in flight)_

## Later — larger surface (now CI-compiled per PR, no longer blind)
> Every PR is compiled by F24 CI before merge; land these one at a time and watch
> the run. The pbxproj risk is real (new targets in a file-system-synchronized
> Xcode-16 project) so verify CI stays green.
>
> **New-target pbxproj checklist (learned the hard way in F16):** add the sync
> root group, the PBXNativeTarget (+ Sources/Frameworks/Resources phases), the
> config list + 2 XCBuildConfigurations, and register the target in PBXProject
> `targets` + `TargetAttributes`. **Crucially, this project omits product file
> references — but a new target needs an explicit `PBXFileReference` for its
> product AND for any product it references (e.g. a test host's `Fit.app`), or
> resolution fails.** Add the target to the **scheme's `BuildAction`** (not just
> `Testables`/extension list). For extensions, also add the embed/copy phase to
> the host. Validate by watching CI; expect 2–5 iterations.
- _(F14 shipped — see Done. The backlog is now genuinely empty of
  clearly-valuable, SPEC-aligned work.)_

### Removed by grooming (ruthless-PM rationale)
- **F12 — Localize UI strings (en/uk/ru/cs) — REMOVED as noise.** The SPEC's
  multilingual requirement (§2, §10.2) is about *exercise-name data* being
  arbitrary / mixed-language, which the app already fully supports (free-text
  canonical names + aliases, non-English seed data). The spec never asks for a
  localized UI, and the app is explicitly for **one personal user** (§1, §20) who
  uses it in English. Translating UI chrome into four languages is high effort
  with zero value for that user — it does not serve the spec's purpose and would
  just be busywork. If a real second user ever needs it, revisit then.

## Done
<!-- merged items move here with PR links -->
- [x] **F30 — Unlock model-level SwiftData tests + import-integrity regression** — broke the F16 blocker that made per-test `ModelContainer`s crash the test host (the host app's CloudKit container conflicts with a second one for the same schema). Fix is **one shared in-memory container** for the whole test process: `PersistenceController.isRunningTests` (detects `XCTestConfigurationFilePath`), a `static let testContainer` (in-memory, unseeded), and a single new first line in `makeSharedContainer()` — `if isRunningTests { return testContainer }` — leaving the real CloudKit/local launch path untouched. New `FitTests/ModelTestSupport.swift` (`@MainActor` helper returning a fresh `ModelContext(testContainer)`; tests use unique `UUID()`s and assert only on their own ids since the store is shared/not reset). **Import-integrity regression** (`FitTests/ImportIntegrityTests.swift`, the high-value one — locks the F26 fix): drives the REAL `DataImportService().importJSON(_:into:)`; Test A seeds a `WorkoutSession` (`title="Leg day"`, `notes="felt strong"`), then re-imports the same id with `title`/`notes` **omitted** and asserts both are preserved (not blanked); Test B provides `title="New title"` and asserts it updates; plus the analogous set-notes case. JSON payloads are hand-built dictionaries serialized via `JSONSerialization` using the importer's exact snake_case `CodingKeys` (`workout_id`, `start_time`, `title`, `session_metadata.notes`, `sets[].set_id`). **Merge test included** (`FitTests/ExerciseMergeTests.swift`): the merge mechanics were additively extracted from `ExerciseMergeView.performMerge()` into a pure, testable `enum ExerciseMerge.merge(_:into:context:)` (View behaviour unchanged — it now calls the helper and owns save/dismiss); tests assert sets re-point to the canonical with `exerciseNameAtTime` preserved, the duplicate's name + aliases survive as case-insensitively-deduped aliases on the canonical, and the duplicate `Exercise` is deleted. Additive, no `public`; new test files auto-build via the synchronized `FitTests` group (no pbxproj change). PR #29 (merged).
- [x] **F14 — Home-screen widget (last workout + training streak)** — shipped the app's **first app extension**: a WidgetKit home-screen widget showing the last finished workout (title + relative date), the current weekly training streak ("🔥 5-week streak") and the top set, in `.systemSmall` + `.systemMedium`, with a "No workouts yet" empty state and the iOS-17 `.containerBackground(.fill.tertiary, for: .widget)`. Sidesteps the SwiftData/CloudKit sharing problem via a tiny **App Group `UserDefaults` snapshot** (`group.com.weboko.fit`): the app writes a `WidgetSnapshot` (Codable: lastWorkoutTitle/date, weeklyStreak, topSetSummary; ISO-8601 JSON under one key) on workout-finish (`FinishWorkoutView.finish()`) and on launch (`ContentView.task`), then `WidgetCenter.reloadAllTimelines()`; the widget reads only that snapshot — no shared store. New `FitWidget/` target (FitWidgetBundle/FitWidget/WidgetSnapshot/Info.plist/entitlements), app-side `Fit/Shared/WidgetSnapshotWriter.swift` (deterministic weekly-streak = consecutive ISO weeks back from this week each with ≥1 finished workout; reuses `WorkoutLoggingHelpers.topSets` + `Format.setSummary`). The `WidgetSnapshot` Codable shape is intentionally duplicated in both modules (no shared framework). pbxproj: added the app-extension target with the host's **Embed App Extensions** copy phase (dstSubfolderSpec 13) + explicit `FitWidget.appex` product `PBXFileReference` + an app→widget target dependency so the widget compiles as part of `xcodebuild build -scheme Fit`; App Group entitlement added to both targets. PR #28 (merged).
- [x] **F29 — Export data dictionary (`data_dictionary.md` in the bundle)** — ships a self-describing schema inside the CSV and ZIP export bundles so an external AI can interpret the data unambiguously (SPEC §12, §30). New `Fit/Export/ExportSchema.swift` (`enum ExportSchema.markdown()`, filename `ExportFileName.dataDictionary = "data_dictionary.md"`): an intro (units = kg / seconds / ISO-8601+timezone; only weight+reps are ever required), one `##` section per CSV file with a `column | meaning | type/units/allowed-values` table covering every emitted column (spec + derived: sets `effective_load_kg`/`volume_kg`/`estimated_1rm_kg`/`superset_group`; workouts `timezone`/`is_backfilled`; exercises `is_goal_exercise`/`is_favorite`; health_workouts `linked_workout_id`), a 0–5 effort/energy/stress Scales section (labels read live from `EffortScale`/`EnergyScale`/`StressScale`), and a Derived-columns section with the real formulas (effective load per weight mode, volume = load×reps, Epley 1RM = load×(1+reps/30), reps==1 ⇒ load). Enum allowed-values are read live from the `DisplayableOption` `allCases`/`rawValue`/`displayName` so the doc can't drift. Wired into BOTH `writeCSVBundle` and `writeZip` after the CSVs and before the manifest, and appended to the manifest's `included_files` (JSON-only path left untouched — a markdown dict doesn't fit a lone JSON). New `FitTests/ExportSchemaTests.swift` (context-free, no `ModelContext`): extracts every CSV header the F28 way (`CSVExporter.<file>(emptyDataSet)` + `CSVParser.parse`) and asserts each column appears in the markdown, asserts every raw value of every surfaced enum appears, plus the 0–5 scale labels and derived-column names. No model/column/manifest-schema change. PR #27 (merged).
- [x] **F28 — Export contract tests** — locked the CSV data contract (SPEC §12 "critical", AI-facing). New `FitTests/ExportContractTests.swift` (context-free, no `ModelContext`): for every per-file builder in `CSVExporter` (workouts, sets, exercises, exercise_aliases, health_workouts, heart_rate_summary, body_weight, sleep, journal_entries) it hard-codes the SPEC §12.4–12.13 column list *independently* and asserts `Array(header.prefix(spec.count)) == spec` (parsed via the real `CSVParser`), so any rename/reorder/removal of a spec column fails the test while allowing the documented additive/derived trailing columns (effective_load_kg…superset_group, timezone, is_backfilled). Plus a small populated round-trip (hand-built `ExportDataSet`, relationships `set.workout`/`set.exercise`/`workout.sets`/`exercise.sets` wired explicitly) asserting ids, weight_kg, reps, effort, and comma-containing notes survive export→`parseKeyed`. Spec and exporter headers matched exactly (no drift found). PR #26 (merged).
- [x] **F16 — Unit tests + CI test job** — added a `FitTests` XCTest target to the Xcode-16 file-system-synchronized project and a `macos-15` CI `test` job that runs it on the iPhone 16 simulator. **Build + Test both green.** Six hermetic, **context-free** test files (un-inserted `@Model` objects + plain arrays — no `ModelContext`, no Health/network/UserDefaults): StatsKit volume/bests/Epley-1RM, record-at-the-time PR detection, RFC-4180 CSV parse/parseKeyed, kg↔lb round-trip, CSVExporter→CSVParser round-trip. Took 5 CI iterations to wire the target (see the pbxproj checklist under "Later"). PR #25 (merged).
- [x] **F23 — Data-rich accessibility summaries for `MetricLineChart`** — added an optional `accessibilitySummary: String?` parameter (default `nil`) to `MetricLineChart.init`; when supplied it becomes the chart's `.accessibilityLabel` (still one combined element via `.accessibilityElement(children: .ignore)`), otherwise the generic "Trend chart" label + the in-component fallback summary are kept, so every existing caller stays source-compatible. All three call sites now pass a metric-aware one-liner (count of sessions/entries, value range, latest value, trend up/down/flat, formatted like the chart's own labels with the unit symbol): exercise-detail (Best load / Est. 1RM, required target), body-weight trend, and goal-tracker trend (Est. 1RM / Best reps). Empty/single-point cases handled ("no data yet" / single value). No model/schema/export changes, no new deps. PR #24 (merged).
- [x] **F27 — Remove dead `suggestedWorkouts`** — deleted the unused `HealthImportService.suggestedWorkouts(for:in:)`; `HealthLinkSection` already finds overlaps via `@Query` + `hw.overlaps(session:)` (DRY). PR #23 (merged).
- [x] **F13 — Heart-rate zones in import + export** — added five optional `Int?` `zoneNSeconds` fields to `HealthWorkout` (CloudKit-safe, lightweight migration), computed at Health import by time-weighting HR samples (interval to next sample clamped to [0,60]s, credited to the current sample's zone by `bpm / maxHR`: Z1 .50–.60 … Z5 ≥.90, below .50 = no zone). New `maxHeartRateBpm` setting (default 190, 0/unset = 190) with a Settings → Apple Health stepper (120–220). `CSVExporter.heartRateSummary` now fills `zone_1..5_seconds` (spec §12.9) via `str(_:Int?)`. JSON export/import intentionally untouched (CSV-only feature). PR #22 (merged).
- [x] **F26 — Import integrity (stop blank-overwrite + honest errors)** — fixed the "upsert, never deletes" data-loss bug: the JSON path (`DataImportService.swift`) no longer blanks a populated `notes`/`title` via `?? ""` and the CSV path (`CSVImportService.swift`) now uses the empty-aware `string(_:_:)` helper so a present-but-blank cell preserves the existing value (insert still gets the model's `""` default). `ImportError.unreadable` wording is now format-agnostic (shared by JSON + CSV). Added a per-file malformed-row warning (field count != header count) via `CSVParser.parse`, without changing `parseKeyed`'s contract. PR #21 (merged).
- [x] **F25 — Populate `body_weight_kg_imported` in workouts.csv** — `CSVExporter.workouts` now fills the spec §12.4 column from the nearest same-day Health-imported (`DataSource.healthImport`) `BodyWeightEntry`, formatted like `body_weight_kg_manual`; empty when none (or when body-weight is excluded from the export). Pure exporter change, no model/migration. PR #20 (merged).
- [x] **F24 — CI macOS compiler check** — `.github/workflows/ios-build.yml` builds the app on a `macos-15` runner (iOS Simulator, unsigned) on every PR + push to main. First run revealed `main` did not compile; fixed two errors in the same PR. PR #19 (merged).
- [x] **F1 — Rest timer** — in-app between-sets countdown with ±15s/skip, wired into the active workout. PR #2 (merged).
- [x] **F2 — Personal records** — deterministic PR detection (load/reps/est-1RM), badges in history & exercise detail, on-save haptic + banner. PR #3 (merged).
- [x] **F3 — Goal trackers** — per-goal cards (best/target/distance, trend), UserDefaults targets, reachable from Exercises + Today. PR #4 (merged).
- [x] **F4 — Workout templates** — WorkoutTemplate/TemplateItem models, manage/edit, save-from-workout, start-from-template with pre-filled planned set entry. PR #5 (merged).
- [x] **F5 — Rest alerts + haptics** — local rest-end notification (opt-in), save haptic, Settings "Rest" section (alerts + default duration; closes F19). PR #6 (merged).
- [x] **F6 — Body-weight tracking** — trend chart + manual entry editor, Apple Health badge, feeds bodyweight set default. Settings → Tracking. PR #7 (merged).
- [x] **F7 — Insights analytics** — frequency + per-muscle volume/sets charts over a time range, third History mode. PR #8 (merged).
- [x] **F8 — Plate calculator** — greedy per-side plate math + view, reachable from external-mode set entry. PR #9 (merged).
- [x] **F9 — Repeat last workout** — quick-start from the most recent workout via an auto-managed template, reusing the planned flow. PR #10 (merged).
- [x] **F10 — Supersets** — optional supersetGroup field, set-entry tagging, badges in active workout & history. PR #11 (merged).
- [x] **F11 — JSON import** — upsert-by-id restore of the JSON export (no deletes), fileImporter UI in Data management. PR #12 (merged).
- [x] **F21 — Superset in export** — `superset_group` added to sets.csv + JSON (round-trips with F11 import). PR #13 (merged).
- [x] **F18 — Training calendar heatmap** — GitHub-style training-days heatmap in Insights. PR #14 (merged).
- [x] **F20 — Per-exercise rest** — optional per-exercise rest duration (UserDefaults by id), used by the active timer. PR #15 (merged).
- [x] **F15 — Onboarding flow** — first-run paged explainer (privacy/units/Health/starter exercises), shown once. PR #16 (merged).
- [x] **F17 — Accessibility pass** — VoiceOver labels/traits, combined elements, chart summaries, Dynamic Type guards across shared components + key screens. PR #17 (merged).
- [x] **F22 — CSV import** — RFC-4180 parser + multi-CSV upsert-by-id restore (no deletes), multi-file fileImporter. PR #18 (merged).

## New ideas (groomed in)
- [x] **F19 — Rest-timer Settings control** — default rest duration now in Settings (done as part of F5, PR #6). Per-exercise override deferred (see F20).
- [x] **F22 — CSV import** — done; see Done section (PR #18).
