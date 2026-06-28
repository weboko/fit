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

## In progress
- [ ] **F24 — CI: real macOS compiler check** (PR open)
  GitHub Actions workflow (`.github/workflows/ios-build.yml`) that builds the
  app on a `macos-15` runner for the iOS Simulator with signing disabled.
  **Strategic:** this is the project's first true compile gate. Until now every
  PR was "verified by review, not compiled"; once this is green on `main`, every
  future PR is actually compiled by the runner. This *unblocks* the "needs a real
  Xcode build" tier below — those items become safe to merge once CI is green on
  their branch.

## Now (next up) — compiler-safe, additive
- [ ] **F13 — Heart-rate zones in export + summary**
  Store per-zone seconds on HealthWorkout (optional fields) computed at Health
  import; fill the heart_rate_summary.csv zone columns.
- [ ] **F23 — Exercise-detail accessibility chart summaries**
  Extend F17's chart-summary pattern to the exercise-detail charts (follow-up).

## Later — larger surface (now gated by F24 CI build instead of blind-merge fear)
> Once F24 CI is green on `main`, these are no longer "blind"; the runner
> compiles each PR. Still land them one at a time and watch the CI result before
> merging.
- [ ] **F16 — Unit tests (StatsKit, export/import round-trip, weight conversion)**
  Needs a new XCTest target (pbxproj change) — CI will now compile/run it.
- [ ] **F14 — Home-screen widget (last workout / streak)**
  Needs a new WidgetKit app-extension target (pbxproj change) — CI compiles it.
- [ ] **F12 — Localization of UI strings (en, uk, ru, cs)**
  Large cross-file string externalization + String Catalog.

## Done
<!-- merged items move here with PR links -->
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
