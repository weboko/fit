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
- [x] **F20 — Per-exercise default rest override** (`feat-f20-per-exercise-rest`)
  Optional per-exercise rest duration; the active workout reads it when present,
  falling back to the global default.

## Now (next up)

## Later
- [ ] **F12 — Localization of UI strings (en, uk, ru, cs)**
  Externalize strings; provide initial translations for the user's languages.
- [ ] **F13 — Heart-rate zones in export + summary**
  Compute per-zone seconds from imported HR samples; fill the zone columns.
- [ ] **F14 — Home-screen widget (last workout / streak)**
  WidgetKit extension showing streak and last session summary.
- [ ] **F15 — Onboarding flow**
  First-run explainer (privacy, Health, units) + optional starter exercises.
- [ ] **F16 — Unit tests (StatsKit, export round-trip, weight conversion)**
  XCTest target covering the deterministic logic and export column contract.
- [ ] **F17 — Accessibility pass (Dynamic Type, VoiceOver labels, contrast)**

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

## New ideas (groomed in)
- [x] **F19 — Rest-timer Settings control** — default rest duration now in Settings (done as part of F5, PR #6). Per-exercise override deferred (see F20).
- [ ] **F22 — CSV import**
  Import the multi-CSV export back into the store (complements F11's JSON import).
