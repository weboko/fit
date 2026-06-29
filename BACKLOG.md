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

## In progress
- _(idle — queue drained of clearly high-ROI, SPEC-aligned, low-risk work.)_

## Now (next up) — ROI-ranked
- _(queue otherwise drained of clearly high-ROI, SPEC-aligned, low-risk work —
  see the grooming note below.)_

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
- [ ] **F14 — Home-screen widget (last workout / streak)** — _optional, NOT a
  SPEC goal; low priority._ A widget is an engagement nicety for what the spec
  defines as a low-friction capture + export tool (§1, §30); it needs a WidgetKit
  extension target + App Group + a shared snapshot (the SwiftData/CloudKit store
  isn't trivially shared). Only worth doing if genuinely wanted later; the ROI for
  a single personal user is marginal versus the pbxproj/data-sharing cost.

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
- [x] **F28 — Export contract tests** — locked the CSV data contract (SPEC §12 "critical", AI-facing). New `FitTests/ExportContractTests.swift` (context-free, no `ModelContext`): for every per-file builder in `CSVExporter` (workouts, sets, exercises, exercise_aliases, health_workouts, heart_rate_summary, body_weight, sleep, journal_entries) it hard-codes the SPEC §12.4–12.13 column list *independently* and asserts `Array(header.prefix(spec.count)) == spec` (parsed via the real `CSVParser`), so any rename/reorder/removal of a spec column fails the test while allowing the documented additive/derived trailing columns (effective_load_kg…superset_group, timezone, is_backfilled). Plus a small populated round-trip (hand-built `ExportDataSet`, relationships `set.workout`/`set.exercise`/`workout.sets`/`exercise.sets` wired explicitly) asserting ids, weight_kg, reps, effort, and comma-containing notes survive export→`parseKeyed`. Spec and exporter headers matched exactly (no drift found). PR #__ (pending).
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
