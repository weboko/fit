import SwiftUI
import SwiftData

/// Edit a workout session's date/time, title and subjective metadata.
///
/// This does not touch the individual sets (those are edited from the detail
/// screen via `SetEditView`). On save the session is `touch()`ed.
struct WorkoutEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var title: String
    @State private var startTime: Date
    @State private var hasEnd: Bool
    @State private var endTime: Date

    // First-priority metadata.
    @State private var goal: WorkoutGoal?
    @State private var location: WorkoutLocation?
    @State private var energyBefore: Int?
    @State private var soreness: Soreness?
    @State private var painToday: PainToday?
    @State private var sleepQuality: SleepQuality?

    // Second-priority metadata.
    @State private var stressLevel: Int?
    @State private var foodTiming: FoodTiming?
    @State private var caffeine: Caffeine?
    @State private var bodyWeightManualKg: Double?

    init(session: WorkoutSession) {
        self.session = session
        _title = State(initialValue: session.title)
        _startTime = State(initialValue: session.startTime)
        _hasEnd = State(initialValue: session.endTime != nil)
        _endTime = State(initialValue: session.endTime ?? session.startTime.addingTimeInterval(60 * 60))
        _goal = State(initialValue: session.goal)
        _location = State(initialValue: session.location)
        _energyBefore = State(initialValue: session.energyBefore)
        _soreness = State(initialValue: session.soreness)
        _painToday = State(initialValue: session.painToday)
        _sleepQuality = State(initialValue: session.sleepQualitySubjective)
        _stressLevel = State(initialValue: session.stressLevel)
        _foodTiming = State(initialValue: session.foodTiming)
        _caffeine = State(initialValue: session.caffeine)
        _bodyWeightManualKg = State(initialValue: session.bodyWeightManualKg)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Title (optional)", text: $title)
                    DatePicker("Start", selection: $startTime)
                    Toggle("Has end time", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("End", selection: $endTime, in: startTime...)
                    }
                }

                Section("Session") {
                    OptionMenuPicker(title: "Goal", selection: $goal)
                    OptionMenuPicker(title: "Location", selection: $location)
                }

                Section("Readiness") {
                    ScaleSelector(
                        title: EnergyScale.question,
                        range: EnergyScale.range,
                        value: $energyBefore,
                        labelProvider: EnergyScale.label(for:)
                    )
                    OptionChipGroup<Soreness>("Soreness", selection: $soreness)
                    OptionChipGroup<PainToday>("Pain today", selection: $painToday)
                    OptionChipGroup<SleepQuality>("Sleep quality", selection: $sleepQuality)
                }

                Section("Context") {
                    ScaleSelector(
                        title: StressScale.question,
                        range: StressScale.range,
                        value: $stressLevel,
                        labelProvider: StressScale.label(for:),
                        coloredByValue: false
                    )
                    OptionChipGroup<FoodTiming>("Food timing", selection: $foodTiming)
                    OptionChipGroup<Caffeine>("Caffeine", selection: $caffeine)
                }

                Section("Bodyweight (manual)") {
                    WeightStepperField(weightKg: $bodyWeightManualKg)
                }
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                }
            }
            .onChange(of: startTime) { _, newStart in
                if endTime < newStart { endTime = newStart }
            }
        }
    }

    private func save() {
        session.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        session.startTime = startTime
        session.endTime = hasEnd ? max(endTime, startTime) : nil
        session.goal = goal
        session.location = location
        session.energyBefore = energyBefore
        session.soreness = soreness
        session.painToday = painToday
        session.sleepQualitySubjective = sleepQuality
        session.stressLevel = stressLevel
        session.foodTiming = foodTiming
        session.caffeine = caffeine
        session.bodyWeightManualKg = bodyWeightManualKg
        session.touch()
        try? context.save()
        dismiss()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let session = (try? container.mainContext.fetch(FetchDescriptor<WorkoutSession>()))?.first
        ?? WorkoutSession(title: "Sample")
    return WorkoutEditView(session: session)
        .modelContainer(container)
}
