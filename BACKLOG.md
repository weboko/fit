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
- [x] **F7 — Volume & frequency analytics (per muscle group, deterministic)** (`feat-f7-insights`)
  History "Insights" tab/section: sets & volume per muscle group per week,
  workout frequency, using StatsKit. Charts only, no recommendations.

## Now (next up)
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
- [x] **F1 — Rest timer** — in-app between-sets countdown with ±15s/skip, wired into the active workout. PR #2 (merged).
- [x] **F2 — Personal records** — deterministic PR detection (load/reps/est-1RM), badges in history & exercise detail, on-save haptic + banner. PR #3 (merged).
- [x] **F3 — Goal trackers** — per-goal cards (best/target/distance, trend), UserDefaults targets, reachable from Exercises + Today. PR #4 (merged).
- [x] **F4 — Workout templates** — WorkoutTemplate/TemplateItem models, manage/edit, save-from-workout, start-from-template with pre-filled planned set entry. PR #5 (merged).
- [x] **F5 — Rest alerts + haptics** — local rest-end notification (opt-in), save haptic, Settings "Rest" section (alerts + default duration; closes F19). PR #6 (merged).
- [x] **F6 — Body-weight tracking** — trend chart + manual entry editor, Apple Health badge, feeds bodyweight set default. Settings → Tracking. PR #7 (merged).

## New ideas (groomed in)
- [x] **F19 — Rest-timer Settings control** — default rest duration now in Settings (done as part of F5, PR #6). Per-exercise override deferred (see F20).
- [ ] **F20 — Per-exercise default rest override**
  Optional per-exercise rest duration; the active workout reads it when present,
  falling back to the global default. (Follow-up split out of F19.)
