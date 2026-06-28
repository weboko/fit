Specification: Personal Sport Progress Logger for iPhone

1. Purpose

Build a personal iPhone app for logging strength training and related sport activity in a way that helps the user later export structured data for external AI analysis.

The app itself must not include AI features. It should be an accurate, low-friction data capture and export tool.

The app should support:

* live workout logging during training
* manual strength set tracking
* subjective effort/context metadata
* Apple Health / Apple Watch import
* local-first storage
* iCloud backup/sync
* later review/journaling
* structured export for external analysis

The app is for one personal user, not a commercial multi-user platform.

⸻

2. Core Product Philosophy

The app should help the user progress in sport, especially:

* increasing controlled strength
* progressing toward a 100 kg bench press
* improving pull-ups
* growing bigger muscles, especially biceps and back
* tracking whether weight/reps/effort are improving over time
* capturing enough metadata for later analysis without turning logging into bureaucracy

The app must be practical during real workouts. The user should be able to log a set quickly while tired, between exercises, with minimal typing.

The app should support imperfect data:

* old workouts may be backfilled with only partial information
* some optional fields may be skipped
* subjective fields may be uncertain
* Apple Health data may be incomplete
* exercise names may be inconsistent
* the user may use English, Ukrainian, Russian, Czech, or mixed names

Missing data is acceptable. The app must not force the user to fill every field.

⸻

3. High-Level Architecture

The app should be Apple-native.

Recommended stack:

* Swift
* SwiftUI
* HealthKit
* SwiftData or Core Data
* CloudKit / iCloud sync
* Files / Share Sheet export
* iPhone-first design

No custom backend.

No account system.

No server-side storage.

No built-in AI.

No subscription/auth/payment for MVP.

The app must work offline in the gym.

⸻

4. Storage Model

Storage preference: local data with iCloud backup/sync.

Requirements:

* primary database lives locally on the iPhone
* data syncs/backups through iCloud/CloudKit
* app remains usable offline
* export works from local data without internet
* data model must support future migrations
* user owns the data
* no custom cloud backend
* no non-Apple server dependency

The implementation may use:

* SwiftData with CloudKit support, or
* Core Data + CloudKit

Choose the option that gives better reliability, migrations, and predictable sync behavior.

⸻

5. Main App Modules

The app should be modular.

Required modules:

1. Workout Logger
    * live workout session
    * set-by-set logging
    * fast kg/reps/effort entry
2. Exercise Library
    * custom exercises
    * aliases
    * categories
    * equipment
    * language-agnostic naming
3. Health Import
    * HealthKit permissions
    * Apple Watch workout import
    * heart rate, duration, calories, etc.
4. Journal / Review
    * post-workout notes
    * corrections
    * free text
    * context
5. Export Module
    * separate, pluggable, replaceable
    * exports structured data
    * AI-agnostic
    * no analysis inside app
6. Settings
    * units
    * iCloud sync status
    * Health permissions
    * export options
    * data management

⸻

6. Workout Logging UX

The app must support live logging during a workout.

The user enters data during the session, not only after the session.

A typical flow:

1. Start workout
2. Select or create exercise
3. Log set:
    * weight
    * reps
    * effort
    * optional form/limiter/pain
4. Repeat sets
5. Switch exercise
6. Finish workout
7. Optionally add journal/review notes
8. Optionally import/link Apple Health workout

Logging should be extremely fast.

The app should have a clear “active workout” screen optimized for gym use.

⸻

7. Set Logging Requirements

7.1 Required per set

Each set should support:

* exercise
* set number
* weight
* reps
* timestamp
* workout session ID
* source: manual / imported / edited / backfilled

For MVP, weight and reps should be required for normal weighted exercises.

For bodyweight exercises, weight may be inferred or set to bodyweight mode.

7.2 Weight entry UX

Weight entry should support:

* quick buttons from recent values
* predictable increments:
    * +1 kg
    * +2.5 kg
    * +5 kg
    * -1 kg
    * -2.5 kg
    * -5 kg
* manual numeric entry
* remembered last weight per exercise
* suggested next weight based on previous set
* kg as default unit

Weight modes:

* external weight, e.g. bench press 80 kg
* bodyweight
* assisted bodyweight, e.g. pull-up with -20 kg assistance
* added bodyweight, e.g. pull-up with +10 kg
* unknown / not entered

The app must handle pull-ups well.

For pull-ups, useful logging modes include:

* bodyweight pull-up
* assisted pull-up
* negative pull-up
* band-assisted pull-up
* machine-assisted pull-up
* weighted pull-up

7.3 Reps entry UX

Reps entry should support:

* quick stepper
* numeric keypad
* last reps suggestion
* common values as quick buttons

7.4 Effort entry

Effort is important and should be entered during workout.

Use a simple 0–5 scale.

Suggested labels:

* 0 = warm-up / very easy
* 1 = easy
* 2 = moderate
* 3 = hard
* 4 = very hard
* 5 = maximal / almost failed

UX should be slider or large segmented buttons.

The user should not need to understand sports science terminology to use this.

7.5 Reps in reserve

Support optional “reps left” / RIR field.

Do not expose it only as “RIR” because the user may not know the term.

Label it as:

“How many more clean reps were left?”

Options:

* unknown
* 3+
* 2
* 1
* 0
* failed

This field is optional.

7.6 Form quality

Optional per set.

Options:

* unknown
* good / controlled
* okay
* shaky
* bad
* not sure

This should be a quick button group, not text.

7.7 Limiter/problem field

Optional per set.

Purpose: distinguish why the set was hard or why progress stopped.

Options:

* none
* muscle failed
* grip failed
* breath/cardio failed
* form broke
* pain/discomfort
* balance/coordination failed
* fear/uncertainty
* equipment issue
* other
* unknown

This is useful for later analysis.

7.8 Pain/discomfort

Optional per set or session.

Severity:

* none
* mild
* moderate
* strong
* stop exercise

Optional location:

* shoulder
* elbow
* wrist
* lower back
* upper back
* hip
* knee
* ankle
* neck
* chest
* other

Pain data is for tracking only, not medical advice.

⸻

8. Workout Session Metadata

Session-level metadata should be entered once per workout, not after every set.

All fields optional.

8.1 First-priority fields

These should be easy to enter and shown first.

Workout goal

Options:

* strength
* hypertrophy / muscle size
* technique
* light / recovery
* mixed
* not sure

Energy before workout

0–5 scale.

Label:

“How ready do you feel to train now?”

Suggested labels:

* 0 = exhausted
* 1 = low
* 2 = below normal
* 3 = normal
* 4 = good
* 5 = excellent

Soreness / fatigue

Options:

* unknown
* none
* mild
* moderate
* strong
* very strong

Pain or injury today

Options:

* no
* yes, but okay to train
* yes, I modified exercises
* yes, I stopped/avoided something
* unknown

Sleep quality

Simple manual field:

* unknown
* terrible
* bad
* okay
* good
* excellent

8.2 Second-priority fields

Useful but lower priority:

* body weight
* stress level
* workout location
* food timing
* caffeine / pre-workout
* motivation/mood
* free-text note
* voice note if easy to implement

Body weight

Support:

* manual entry
* HealthKit import if available
* unknown

Do not depend on smart scale integration for MVP.

Stress level

0–5 or unknown.

Workout location

Options:

* gym
* home
* outdoor
* travel
* other
* unknown

Food timing

The user does not plan detailed nutrition tracking.

Keep it simple:

* unknown
* fasted
* ate recently
* normal
* heavy meal before workout

No calorie/macronutrient tracking in MVP.

Caffeine/pre-workout

Options:

* unknown
* none
* coffee
* pre-workout
* other

⸻

9. Journal / Review Layer

The journal is a separate feature from live logging.

It should support:

* post-workout notes
* corrections
* subjective comments
* “what felt good/bad”
* backfilling old workouts
* editing exercise names
* merging duplicate exercise names
* linking/importing Apple Health workout
* adding missing metadata later

The app should make it clear that some fields are best entered live, especially effort, while journal fields can be added later.

Journal entries should support:

* workout-level free text
* optional exercise-level notes
* optional set-level notes
* timestamp
* edited timestamp

⸻

10. Exercise Library

Exercises must not be hardcoded.

The app should include optional starter suggestions, but the user must be able to create and edit exercises freely.

10.1 Exercise fields

Each exercise should have:

* canonical name
* aliases
* category
* primary muscle groups
* secondary muscle groups
* equipment
* movement pattern
* default weight mode
* notes
* archived flag

10.2 Language support

The app should support arbitrary names, including mixed languages.

Examples:

* Bench Press
* жим лежачи
* тяга блока
* lat pulldown
* přítahy
* dumbbell curls

The app should not require English exercise names.

10.3 Aliases

An exercise may have multiple aliases.

Example:

Canonical: “Lat Pulldown”

Aliases:

* тяга блока
* vertical pull machine
* спина тренажер

The user should be able to merge exercises later if they accidentally create duplicates.

10.4 Categories

Suggested categories:

* chest
* back
* biceps
* triceps
* shoulders
* legs
* core
* cardio
* mobility
* full body
* other

10.5 Equipment

Suggested equipment:

* barbell
* dumbbell
* machine
* cable
* bodyweight
* assisted machine
* kettlebell
* resistance band
* bench
* other

10.6 Movement pattern

Suggested movement patterns:

* horizontal push
* vertical push
* horizontal pull
* vertical pull
* squat
* hinge
* lunge
* curl
* extension
* carry
* core
* isolation
* other

⸻

11. Apple Health / Apple Watch Integration

The app should import Apple Health data through HealthKit.

This is separate from manual workout logging.

Apple Watch is used for physiological and workout context data, not for detailed strength set logging.

11.1 Required HealthKit permissions

Request permissions only when needed.

Potential read permissions:

* workouts
* heart rate
* active energy burned
* basal energy burned if useful
* total energy if available
* workout duration
* body mass
* sleep analysis
* resting heart rate
* heart rate variability if available
* step count

Write permissions are not required for MVP unless there is a strong reason.

11.2 Imported workout data

For each Apple Health workout, import:

* HealthKit workout UUID
* workout type
* start time
* end time
* duration
* active energy
* total energy if available
* average heart rate if computable
* min heart rate if computable
* max heart rate if computable
* heart rate samples if reasonable
* source device/app
* import timestamp

11.3 Linking manual workout to Apple Health workout

The app should allow linking a manual workout session to an Apple Health workout.

Matching logic:

* suggest Apple Health workouts with overlapping time window
* show start/end/duration/type
* allow user to link manually
* allow unlinking
* avoid duplicate linking

Example:

Manual workout:

* 2026-06-28 18:05–19:10

Apple Health workout:

* Traditional Strength Training 18:03–19:12

The app should suggest linking these.

11.4 Sleep and bodyweight

Sleep/bodyweight import should be optional.

If Apple Health contains bodyweight, import it.

If Apple Health contains sleep data, import basic sleep duration/quality-like data if available.

But the app should also allow manual subjective sleep quality because third-party sleep apps may be more accurate but not easily exportable.

11.5 Health data reliability

Imported Health data should be marked as imported.

The user should be able to see source and timestamp.

Do not silently overwrite manually entered data unless explicitly confirmed.

⸻

12. Export Module

The export module is critical.

It must be:

* separate from the core logger
* pluggable
* removable
* replaceable
* easy to update later
* AI-agnostic
* analysis-free

The app should not analyze the workout using AI.

The app should only export captured data in structured formats so the user can upload it to an external AI system.

12.1 Export goals

Export should allow external AI to answer questions like:

* why strength is stuck
* whether bench press is progressing
* whether pull-ups are improving
* whether back/biceps volume is increasing
* whether effort is too high or too low
* whether sleep/energy/fatigue correlates with performance
* whether pain/limiters appear in specific exercises
* when weight/reps increased
* what exercises were performed consistently
* how training volume changed over time

The app does not answer these questions itself. It only exports the data.

12.2 Export formats

Support at least:

1. CSV export
2. JSON export

Recommended:

* CSV for spreadsheets and simple AI upload
* JSON for complete structured data
* ZIP package containing multiple CSVs + JSON manifest

12.3 CSV export structure

Use multiple CSV files rather than one giant denormalized file.

Recommended files:

* workouts.csv
* sets.csv
* exercises.csv
* exercise_aliases.csv
* health_workouts.csv
* heart_rate_summary.csv
* body_weight.csv
* sleep.csv
* journal_entries.csv
* export_manifest.json

12.4 workouts.csv

Columns:

* workout_id
* start_time
* end_time
* duration_seconds
* title
* workout_goal
* location
* energy_before_0_5
* soreness
* pain_today
* sleep_quality_subjective
* stress_0_5
* food_timing
* caffeine
* body_weight_kg_manual
* body_weight_kg_imported
* apple_health_workout_id
* notes
* created_at
* updated_at

12.5 sets.csv

Columns:

* set_id
* workout_id
* exercise_id
* exercise_name_at_time
* set_index
* timestamp
* weight_mode
* weight_kg
* body_weight_kg
* assistance_kg
* added_weight_kg
* reps
* effort_0_5
* reps_left
* form_quality
* limiter
* pain_severity
* pain_location
* is_warmup
* is_failed
* source
* notes
* created_at
* updated_at

12.6 exercises.csv

Columns:

* exercise_id
* canonical_name
* category
* primary_muscles
* secondary_muscles
* equipment
* movement_pattern
* default_weight_mode
* archived
* notes
* created_at
* updated_at

12.7 exercise_aliases.csv

Columns:

* alias_id
* exercise_id
* alias_name
* language_optional
* created_at

12.8 health_workouts.csv

Columns:

* health_workout_id
* apple_health_uuid
* workout_type
* start_time
* end_time
* duration_seconds
* active_energy_kcal
* total_energy_kcal
* avg_heart_rate_bpm
* min_heart_rate_bpm
* max_heart_rate_bpm
* source_name
* source_device
* imported_at

12.9 heart_rate_summary.csv

Columns:

* workout_id
* health_workout_id
* avg_hr_bpm
* min_hr_bpm
* max_hr_bpm
* hr_samples_count
* zone_1_seconds
* zone_2_seconds
* zone_3_seconds
* zone_4_seconds
* zone_5_seconds

Heart rate zones are optional for MVP.

12.10 body_weight.csv

Columns:

* body_weight_entry_id
* timestamp
* weight_kg
* source
* apple_health_sample_id
* notes

12.11 sleep.csv

Columns:

* sleep_entry_id
* date
* start_time
* end_time
* duration_seconds
* sleep_source
* subjective_sleep_quality
* apple_health_sample_id
* notes

12.12 journal_entries.csv

Columns:

* journal_entry_id
* workout_id
* exercise_id_optional
* set_id_optional
* timestamp
* entry_type
* text
* created_at
* updated_at

12.13 export_manifest.json

Include:

* export_version
* app_version
* exported_at
* date_range_start
* date_range_end
* included_files
* schema_version
* units
* timezone
* notes

12.14 JSON export

JSON should preserve full nested structure.

Example shape:

{
“export_version”: “1.0”,
“schema_version”: “1.0”,
“exported_at”: “…”,
“units”: {
“weight”: “kg”
},
“workouts”: [
{
“workout_id”: “…”,
“start_time”: “…”,
“end_time”: “…”,
“session_metadata”: {},
“sets”: [],
“linked_health_workout”: {},
“journal_entries”: []
}
],
“exercises”: [],
“body_weight_entries”: [],
“sleep_entries”: []
}

12.15 Export filters

The export UI should allow:

* all data
* date range
* last 7 days
* last 30 days
* last 90 days
* this year
* selected workout
* selected exercises
* include/exclude Apple Health data
* include/exclude journal notes

12.16 Export destination

Use iOS Share Sheet.

Allow export to:

* Files
* iCloud Drive
* AirDrop
* email
* any installed app that accepts files

⸻

13. Data Model

Use stable IDs for all entities.

Recommended entities:

WorkoutSession

Fields:

* id
* title
* startTime
* endTime
* createdAt
* updatedAt
* timezone
* goal
* location
* energyBefore
* soreness
* painToday
* sleepQualitySubjective
* stressLevel
* foodTiming
* caffeine
* bodyWeightManualKg
* linkedHealthWorkoutId
* notes
* isBackfilled

Relationships:

* sets
* journalEntries
* linkedHealthWorkout

Exercise

Fields:

* id
* canonicalName
* category
* primaryMuscles
* secondaryMuscles
* equipment
* movementPattern
* defaultWeightMode
* notes
* archived
* createdAt
* updatedAt

Relationships:

* aliases
* sets

ExerciseAlias

Fields:

* id
* exerciseId
* aliasName
* languageOptional
* createdAt

WorkoutSet

Fields:

* id
* workoutId
* exerciseId
* exerciseNameAtTime
* setIndex
* timestamp
* weightMode
* weightKg
* bodyWeightKg
* assistanceKg
* addedWeightKg
* reps
* effort
* repsLeft
* formQuality
* limiter
* painSeverity
* painLocation
* isWarmup
* isFailed
* source
* notes
* createdAt
* updatedAt

HealthWorkout

Fields:

* id
* appleHealthUUID
* workoutType
* startTime
* endTime
* durationSeconds
* activeEnergyKcal
* totalEnergyKcal
* avgHeartRateBpm
* minHeartRateBpm
* maxHeartRateBpm
* sourceName
* sourceDevice
* importedAt

BodyWeightEntry

Fields:

* id
* timestamp
* weightKg
* source
* appleHealthSampleId
* notes

SleepEntry

Fields:

* id
* date
* startTime
* endTime
* durationSeconds
* source
* subjectiveSleepQuality
* appleHealthSampleId
* notes

JournalEntry

Fields:

* id
* workoutId
* exerciseIdOptional
* setIdOptional
* timestamp
* entryType
* text
* createdAt
* updatedAt

⸻

14. UI Structure

Suggested tab layout:

1. Today / Active Workout
2. History
3. Exercises
4. Journal
5. Export
6. Settings

Alternatively, use 5 tabs and put Journal inside History.

14.1 Today / Active Workout

Main screen for live use.

Must show:

* current workout timer
* current exercise
* previous sets for current exercise
* quick add set
* quick change exercise
* finish workout

Set entry should be possible with one hand.

14.2 Exercise selection

Exercise picker should support:

* search
* recent exercises
* favorites
* create new exercise quickly
* aliases
* category filtering

Creating a new exercise should be fast.

Minimum new exercise creation:

* name only

Optional later enrichment:

* category
* equipment
* muscles
* movement pattern

14.3 Active set entry

For each exercise, show recent set history.

Example:

Bench Press

Previous:

* 60 × 8
* 70 × 6
* 80 × 4

New set:

* Weight: [ -5 ] [ -2.5 ] 80 kg [ +2.5 ] [ +5 ]
* Reps: [ - ] 6 [ + ]
* Effort: 0 1 2 3 4 5
* Save Set

Optional fields hidden behind “More”:

* reps left
* form
* limiter
* pain
* note

14.4 Finish workout screen

Show summary:

* duration
* exercises
* total sets
* top sets
* optional session questionnaire
* notes
* HealthKit link suggestion

Do not do AI analysis.

14.5 History

History should show workouts by date.

Each workout detail should show:

* session metadata
* exercises
* sets
* linked Health workout
* journal notes
* edit options
* export this workout

14.6 Exercises

Exercise detail should show:

* exercise metadata
* aliases
* recent history
* personal bests computed locally if simple
* all sets
* edit/merge/archive options

Simple non-AI stats are allowed, such as max weight, max reps, and recent history.

14.7 Export

Export screen should allow:

* select date range
* select format
* include/exclude data types
* generate export
* share file

Export module should be isolated in code.

⸻

15. Local Non-AI Stats

The app may include simple deterministic stats.

Allowed:

* total sets
* total reps
* total volume = weight × reps
* best weight for exercise
* best reps for bodyweight exercise
* estimated 1RM if implemented as formula and clearly marked
* history charts
* workout frequency

Not allowed for MVP:

* AI coaching
* AI-generated recommendations
* automatic program generation
* “you should do X” intelligence
* LLM integration

The app is a logger/exporter, not a coach.

⸻

16. Pull-Up Support

Pull-ups are an important user goal.

The app must support tracking progression from beginner to advanced.

Pull-up-related exercise types may include:

* dead hang
* scapular pull-up
* negative pull-up
* assisted pull-up
* band-assisted pull-up
* machine-assisted pull-up
* bodyweight pull-up
* weighted pull-up
* chin-up
* neutral grip pull-up

Useful fields:

* reps
* assistance kg
* added weight kg
* bodyweight kg
* effort
* form quality
* limiter, especially grip/muscle/form

Progression should be visible in history, but no AI coaching is needed.

⸻

17. Bench Press Goal Support

Bench press 100 kg is an important user goal.

The app should make bench history easy to inspect.

Useful features:

* mark exercise as goal exercise
* show best set
* show recent working weights
* show volume trend
* show estimated 1RM if implemented
* show attempts near 100 kg
* export bench data clearly

No AI analysis in app.

⸻

18. Back and Biceps Hypertrophy Support

User cares about bigger biceps and back.

The app should support tagging exercises by muscle group.

Useful for export:

* sets per muscle group
* volume per muscle group
* frequency per muscle group
* exercise consistency

The app may display simple deterministic volume summaries, but the main goal is exportable data.

⸻

19. Backfilling Old Data

The app should support entering old workouts.

Backfilled workouts may have incomplete data.

Requirements:

* choose past date
* enter exercises/sets
* skip effort/form/pain
* mark source as backfilled/manual
* allow notes like “approximate”
* allow uncertain values

For old data, the app should not require live-only fields.

⸻

20. Editing and Data Correction

The user must be able to edit:

* workout date/time
* exercise name
* set weight
* reps
* effort
* form
* limiter
* pain
* notes
* linked Apple Health workout

The app should maintain updatedAt timestamps.

Optional: keep edit history later, but not required for MVP.

⸻

21. Exercise Merge

Because exercise names may be inconsistent, the app should support merging exercises.

Example:

* “Lat pulldown”
* “тяга блока”
* “спина тренажер”

Merge flow:

1. Select duplicate exercises
2. Choose canonical exercise
3. Move all sets to canonical exercise
4. Preserve old names as aliases
5. Keep exerciseNameAtTime on historical sets if possible

⸻

22. Units

Default:

* kg
* metric

Support future extension to lbs, but MVP can prioritize kg.

All exports should include unit metadata.

⸻

23. Privacy and Data Ownership

The app stores sensitive personal health and training data.

Requirements:

* no custom backend
* no analytics SDK in MVP
* no ads
* no third-party tracking
* no AI API calls
* data remains local/iCloud
* export is user-initiated
* HealthKit permissions must be transparent

Settings should include:

* export all data
* delete all data
* HealthKit permission status
* iCloud sync status

⸻

24. MVP Scope

Must have

* create workout
* live workout logging
* custom exercises
* set logging with weight/reps/effort
* optional form/limiter/pain
* session questionnaire
* workout history
* edit workouts/sets
* Apple Health import for workouts
* link manual workout to HealthKit workout
* local storage
* iCloud sync/backup
* CSV export
* JSON export
* iOS Share Sheet export

Should have

* exercise aliases
* exercise merge
* bodyweight/pull-up support
* bodyweight import from HealthKit
* sleep import if available
* journal notes
* simple charts/history
* export date filters

Could have later

* voice notes
* Apple Watch companion app
* automatic plate calculator
* workout templates
* rest timer
* advanced charts
* HR zone calculations
* smart scale direct integrations
* custom export schemas
* import from CSV
* program planning
* deterministic progression suggestions
* AI integration only if explicitly added later, but not now

⸻

25. Non-Goals

Do not build these in MVP:

* custom backend
* social features
* trainer marketplace
* built-in AI coach
* AI analysis
* automatic recommendations
* nutrition tracking with calories/macros
* complex meal logging
* public profiles
* subscriptions
* Android app
* web app
* Apple Watch-only app
* medical advice system

⸻

26. Implementation Notes

26.1 Code organization

Recommended modules/packages:

* AppShell
* Persistence
* DomainModels
* WorkoutLogging
* ExerciseLibrary
* HealthImport
* Journal
* Export
* Settings

The Export module should depend on domain models but workout logging should not depend on export implementation.

26.2 Export module interface

Design export with an interface like:

* ExportRequest
* ExportOptions
* ExportFormat
* ExportResult
* ExportService

Conceptually:

ExportService.export(request: ExportRequest) -> ExportResult

ExportRequest contains:

* date range
* format
* includeHealthData
* includeJournal
* includeBodyWeight
* includeSleep
* selectedExercises
* selectedWorkouts

ExportResult contains:

* file URLs
* generatedAt
* format
* errors/warnings

26.3 Health import service

HealthImportService should:

* request permissions
* fetch workouts
* fetch workout heart rate samples
* summarize heart rate
* fetch body mass samples
* fetch sleep samples
* link Health workouts to manual workouts
* avoid duplicates

26.4 Persistence

Use migrations from the start.

All enums should be stored as stable string values, not fragile integer positions.

Examples:

* effort_0_5 can be integer
* form_quality should be string enum
* limiter should be string enum
* weight_mode should be string enum

26.5 Timezones

Store timestamps with timezone awareness.

Export should include timezone.

Workout dates should display in local timezone.

⸻

27. Example User Flow

New workout

1. User opens app.
2. Taps “Start Workout.”
3. Chooses “Bench Press” from recent exercises.
4. Enters 60 kg × 8, effort 2.
5. Saves set.
6. Next set defaults to 60 kg and 8 reps.
7. User taps +10 kg, changes reps to 6, effort 3.
8. Saves set.
9. User switches to pull-ups.
10. Logs assisted pull-up: assistance 20 kg, 5 reps, effort 4.
11. Finishes workout.
12. Adds session note: “Bench felt strong. Pull-ups hard, grip okay.”
13. App suggests linking Apple Health strength workout from same time.
14. User links it.
15. Later, user exports last 90 days as ZIP with CSV + JSON.
16. User uploads export to external AI for analysis.

⸻

28. Acceptance Criteria

Workout logging

* User can start and finish a workout.
* User can create/select exercises.
* User can log sets with weight, reps, and effort.
* User can log optional form, limiter, and pain.
* User can edit logged sets.
* User can backfill old workouts.

Exercise library

* User can create custom exercises.
* User can use non-English names.
* User can add aliases.
* User can merge duplicate exercises.
* User can archive exercises.

Health import

* App requests HealthKit permission.
* App imports Apple Health workouts.
* App imports basic workout metadata.
* App summarizes heart rate where available.
* App suggests matching Health workout for manual workout.
* User can link/unlink Health workout.

Storage

* Data persists locally.
* App works offline.
* iCloud sync/backup works if user has iCloud enabled.
* App does not require custom login.

Export

* User can export CSV.
* User can export JSON.
* User can export date ranges.
* Export includes workouts, sets, exercises, aliases, health data, bodyweight, sleep, and journal where selected.
* Export works without internet.
* Export uses iOS Share Sheet.
* Export module is isolated from core logging.

Privacy

* No custom backend.
* No third-party tracking.
* No AI API calls.
* No automatic data sharing.
* User controls export.

⸻

29. Build Order

Recommended implementation sequence:

1. Create project skeleton.
2. Define domain models.
3. Implement local persistence.
4. Implement exercise library.
5. Implement active workout logging.
6. Implement set entry UX.
7. Implement workout history and editing.
8. Implement session questionnaire.
9. Implement journal notes.
10. Implement HealthKit permission/import.
11. Implement Health workout linking.
12. Implement CSV export.
13. Implement JSON export.
14. Implement iCloud sync/backup.
15. Polish UX for fast gym use.
16. Add exercise merge/aliases if not already done.
17. Add simple deterministic charts/stats.
18. Test with backfilled historical data.
19. Test export quality by uploading exported files to an external AI manually.

⸻

30. Final Product Definition

Build a private, local-first iPhone strength training logger with iCloud sync, Apple Health import, fast live set logging, flexible custom exercises, optional effort/form/pain metadata, a separate journal/review layer, and a pluggable structured export module.

The app is not a coach and not an AI product.

Its job is to capture high-quality personal training data with low friction and export it cleanly so an external AI can analyze it later.