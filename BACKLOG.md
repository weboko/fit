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
- [x] **F1 — Rest timer** (`feat-f1-rest-timer`)

## Now (next up)
- [ ] **F2 — Personal records (PR) detection & celebration**
  Detect when a saved set beats the prior best (load / reps / est-1RM) for that
  exercise; mark the set, show a badge in history/detail, light haptic on save.
  Deterministic only (StatsKit). Add `isPersonalRecord`-style derivation (no new
  required model fields; compute against history).
- [ ] **F3 — Goal trackers screen (Bench 100 kg, Pull-ups)**
  A dedicated screen surfacing goal exercises: best set, recent working weights,
  est-1RM trend, distance to target (configurable target kg / reps). No coaching.
- [ ] **F4 — Workout templates / routines**
  Save a workout as a reusable template (ordered exercises + target sets); start
  a new workout from a template, pre-creating the exercise list.
- [ ] **F5 — Rest-timer notifications + haptics polish**
  Local notification when the rest timer ends (with permission), haptic on set
  save and PR.

## Next
- [ ] **F6 — Body-weight tracking screen + trend chart**
  Manual body-weight entry UI + chart over time (BodyWeightEntry already exists),
  surfaced in Settings/History; feeds bodyweight-mode set defaults.
- [ ] **F7 — Volume & frequency analytics (per muscle group, deterministic)**
  History "Insights" tab/section: sets & volume per muscle group per week,
  workout frequency, using StatsKit. Charts only, no recommendations.
- [ ] **F8 — Plate calculator**
  Given a target barbell load and a bar weight + available plates, show the plate
  breakdown per side. Pure utility, reachable from set entry.
- [ ] **F9 — "Repeat last workout" / quick start**
  Start a new session pre-populated from the most recent matching workout.
- [ ] **F10 — Superset / circuit grouping**
  Allow grouping exercises within a session as a superset for logging order.

## Later
- [ ] **F11 — CSV/JSON import (restore from a prior export)**
  Round-trip the export format back into the store (merge by id), enabling
  backup/restore and migration.
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
- [ ] **F18 — Rest-day / training calendar heatmap**

## Done
<!-- merged items move here with PR links -->
