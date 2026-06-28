import Foundation
import SwiftData

/// Deterministic helpers for workout templates (spec F4): building a template
/// from a finished session, starting a new session from a template, and tracking
/// which template (if any) the active workout was started from.
///
/// The active-template link is kept in `UserDefaults` keyed by the active
/// session id so we do not have to add a field to `WorkoutSession`. No AI, no
/// network — everything here is plain data transformation.
enum TemplateSupport {

    /// UserDefaults key holding the template id the active workout was started
    /// from (stored as the template UUID string).
    static let activeTemplateIdKey = "fit.activeWorkout.templateId"
    /// UserDefaults key holding the session id the above template id belongs to,
    /// so a stale value from a previous workout is never applied to a new one.
    static let activeTemplateSessionIdKey = "fit.activeWorkout.templateSessionId"

    // MARK: - Active-template link

    /// Records that `session` was started from `template`.
    static func setActiveTemplate(_ template: WorkoutTemplate, for session: WorkoutSession) {
        UserDefaults.standard.set(template.id.uuidString, forKey: activeTemplateIdKey)
        UserDefaults.standard.set(session.id.uuidString, forKey: activeTemplateSessionIdKey)
    }

    /// The template id linked to `session`, if it was started from a template.
    static func activeTemplateId(for session: WorkoutSession) -> UUID? {
        guard
            let storedSession = UserDefaults.standard.string(forKey: activeTemplateSessionIdKey),
            storedSession == session.id.uuidString,
            let storedTemplate = UserDefaults.standard.string(forKey: activeTemplateIdKey),
            let id = UUID(uuidString: storedTemplate)
        else { return nil }
        return id
    }

    /// The template `session` was started from, fetched from the store.
    static func activeTemplate(for session: WorkoutSession, in context: ModelContext) -> WorkoutTemplate? {
        guard let id = activeTemplateId(for: session) else { return nil }
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// Clears any active-template link (used on finish/discard).
    static func clearActiveTemplate() {
        UserDefaults.standard.removeObject(forKey: activeTemplateIdKey)
        UserDefaults.standard.removeObject(forKey: activeTemplateSessionIdKey)
    }

    // MARK: - Start from a template

    /// Creates, inserts and saves a fresh active session for `template`, records
    /// the active-template link, and returns the new session. The planned
    /// exercises are surfaced by the active screen; no empty sets are created.
    @discardableResult
    static func startSession(from template: WorkoutTemplate,
                             in context: ModelContext,
                             startTime: Date = Date()) -> WorkoutSession {
        let session = WorkoutSession(title: template.displayName, startTime: startTime)
        context.insert(session)
        try? context.save()
        setActiveTemplate(template, for: session)
        return session
    }

    /// Which planned items of `template` still have no logged set in `session`,
    /// matched by exercise id (falling back to the name snapshot). Used to decide
    /// whether to show the "Planned" section and which rows remain to log.
    static func remainingItems(of template: WorkoutTemplate, in session: WorkoutSession) -> [TemplateItem] {
        let loggedExerciseIds = Set(session.exercisesInOrder.map(\.id))
        let loggedNames = Set(session.orderedSets.map { $0.exerciseNameAtTime.lowercased() }
            .filter { !$0.isEmpty })
        return template.orderedItems.filter { item in
            if let ex = item.exercise, loggedExerciseIds.contains(ex.id) { return false }
            let name = item.exerciseNameAtTime.lowercased()
            if !name.isEmpty, loggedNames.contains(name) { return false }
            return true
        }
    }

    // MARK: - Build a template from a finished session

    /// Builds (but does not insert) a `WorkoutTemplate` plus its `TemplateItem`s
    /// from `session`: one item per distinct exercise in logging order, with
    /// `targetSets` = that exercise's working-set count and reps/weight/mode
    /// taken from a representative top working set.
    ///
    /// The caller is responsible for inserting the returned template and its
    /// items into a `ModelContext` and saving.
    static func makeTemplate(from session: WorkoutSession) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: defaultTemplateName(for: session))
        let items = makeItems(from: session)
        for item in items { item.template = template }
        template.items = items
        return template
    }

    /// Builds (but does not insert or parent) one `TemplateItem` per distinct
    /// exercise in `session`, in logging order, deriving targets from each
    /// exercise's working sets. Shared by `makeTemplate(from:)` and the F9
    /// quick-start flow so target derivation stays in one place.
    static func makeItems(from session: WorkoutSession) -> [TemplateItem] {
        var items: [TemplateItem] = []

        for (offset, exercise) in session.exercisesInOrder.enumerated() {
            let exerciseSets = session.orderedSets.filter { $0.exercise?.id == exercise.id }
            let workingSets = exerciseSets.filter { !$0.isWarmup }
            let targetSets = max(1, workingSets.count)

            // A representative set: best working set by load, else best by reps,
            // else the last working/any set so we still capture reps/mode.
            let representative = StatsKit.bestSetByWeight(workingSets)
                ?? StatsKit.bestRepsSet(workingSets)
                ?? workingSets.last
                ?? exerciseSets.last

            // Normalise an unknown mode to external so the editor picker always
            // has a matching option (the editor only offers concrete modes).
            let rawMode = representative?.weightMode ?? exercise.defaultWeightMode
            let mode: WeightMode = rawMode == .unknown ? .external : rawMode

            let item = TemplateItem(
                order: offset,
                targetSets: targetSets,
                targetReps: representative?.reps,
                targetWeightKg: representativeTargetWeightKg(representative),
                weightMode: mode,
                exercise: exercise,
                exerciseNameAtTime: exercise.canonicalName
            )
            items.append(item)
        }

        return items
    }

    /// The target weight to store for a representative set, in the field that
    /// matches its weight mode (mirrors how loads are stored on `WorkoutSet`).
    private static func representativeTargetWeightKg(_ set: WorkoutSet?) -> Double? {
        guard let set else { return nil }
        switch set.weightMode {
        case .external, .unknown: return set.weightKg
        case .addedBodyweight: return set.addedWeightKg
        case .assistedBodyweight: return set.assistanceKg
        case .bodyweight: return nil
        }
    }

    /// A sensible default name for a template built from a session: its title if
    /// present, otherwise the session's day.
    static func defaultTemplateName(for session: WorkoutSession) -> String {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return session.startTime.formatted(.dateTime.weekday().month().day())
    }

    // MARK: - Repeat last workout (F9)

    /// Display name for the single auto-managed quick-start template.
    static let quickStartTemplateName = "↻ Quick start"

    /// The most recent finished session (endTime != nil), or nil if there are
    /// none. Sorted by start time descending; a small fetch limit keeps it cheap.
    static func mostRecentFinishedSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endTime != nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Starts a fresh session pre-populated from the most recent finished
    /// workout, reusing the F4 planned-template flow. Returns the new active
    /// session, or nil if there is no finished workout to repeat.
    ///
    /// The exercises/targets are mirrored onto a SINGLE reusable "quick start"
    /// template (remembered in `AppSettingsKeys.quickStartTemplateId`) which is
    /// refreshed in place each time, so repeated taps never clutter the template
    /// list. Once the template is updated we hand off to `startSession(from:in:)`
    /// exactly like any other template start, so the active screen's planned card
    /// and active-template link work with zero `ActiveWorkoutView` changes.
    @discardableResult
    static func repeatLastWorkout(in context: ModelContext) -> WorkoutSession? {
        guard let last = mostRecentFinishedSession(in: context) else { return nil }

        let template = quickStartTemplate(in: context)
        template.name = quickStartTemplateName

        // Replace any previous items so the template mirrors the latest workout.
        for old in (template.items ?? []) {
            context.delete(old)
        }
        let items = makeItems(from: last)
        for item in items { item.template = template }
        template.items = items
        template.touch()

        try? context.save()
        return startSession(from: template, in: context)
    }

    /// Looks up the stored quick-start template, or creates and remembers a new
    /// one if there is no stored id or it no longer exists in the store.
    private static func quickStartTemplate(in context: ModelContext) -> WorkoutTemplate {
        if let stored = UserDefaults.standard.string(forKey: AppSettingsKeys.quickStartTemplateId),
           let id = UUID(uuidString: stored) {
            let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })
            if let existing = (try? context.fetch(descriptor))?.first {
                return existing
            }
        }
        let template = WorkoutTemplate(name: quickStartTemplateName)
        context.insert(template)
        UserDefaults.standard.set(template.id.uuidString, forKey: AppSettingsKeys.quickStartTemplateId)
        return template
    }
}
