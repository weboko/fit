import SwiftUI
import SwiftData

/// Detail screen for a single exercise: metadata, aliases, favourite/goal
/// toggles, deterministic stats (StatsKit), a progress chart, the set history,
/// and actions (Edit / Merge / Archive) — spec §15, §17, §18, §21.
struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context

    @State private var showAllSets = false
    @State private var chartMetric: ChartMetric = .bestLoad
    @State private var showingMerge = false

    private enum ChartMetric: String, CaseIterable, Identifiable {
        case bestLoad
        case oneRepMax
        var id: String { rawValue }
        var label: String {
            switch self {
            case .bestLoad: return "Best load"
            case .oneRepMax: return "Est. 1RM"
            }
        }
    }

    /// Recent-first sets for this exercise (excludes warmups from stats only).
    private var sets: [WorkoutSet] { exercise.orderedSets }

    private var recentLimit: Int { 8 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                togglesCard
                metadataCard
                if !exercise.aliasNames.isEmpty { aliasesCard }
                statsCard
                personalRecordsCard
                chartCard
                setsCard
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.canonicalName.isEmpty ? "Exercise" : exercise.canonicalName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        ExerciseEditView(exercise: exercise)
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                    Button {
                        showingMerge = true
                    } label: {
                        Label("Merge…", systemImage: "arrow.triangle.merge")
                    }
                    Button {
                        toggleArchived()
                    } label: {
                        Label(exercise.archived ? "Unarchive" : "Archive",
                              systemImage: exercise.archived ? "tray.and.arrow.up" : "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingMerge) {
            ExerciseMergeView(canonical: exercise)
        }
    }

    // MARK: - Header / toggles

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(exercise.canonicalName.isEmpty ? "Untitled exercise" : exercise.canonicalName)
                .font(.title2.weight(.bold))
            HStack(spacing: Theme.Spacing.s) {
                if let category = exercise.category {
                    Text(category.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if exercise.archived {
                    SourceBadge(text: "Archived", systemImage: "archivebox", tint: .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var togglesCard: some View {
        SectionCard {
            Toggle(isOn: Binding(
                get: { exercise.isFavorite },
                set: { _ in toggleFavorite() }
            )) {
                Label("Favourite", systemImage: "star")
            }
            Toggle(isOn: Binding(
                get: { exercise.isGoalExercise },
                set: { _ in toggleGoal() }
            )) {
                Label("Goal exercise", systemImage: "target")
            }
        }
    }

    // MARK: - Metadata

    private var metadataCard: some View {
        SectionCard("Details", systemImage: "info.circle") {
            DetailRow(label: "Category", value: exercise.category?.displayName ?? "—")
            DetailRow(label: "Equipment", value: exercise.equipment?.displayName ?? "—")
            DetailRow(label: "Movement", value: exercise.movementPattern?.displayName ?? "—")
            DetailRow(label: "Default weight mode", value: exercise.defaultWeightMode.displayName)
            DetailRow(label: "Primary muscles", value: muscleList(exercise.primaryMuscles))
            DetailRow(label: "Secondary muscles", value: muscleList(exercise.secondaryMuscles))
            if !exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                Text(exercise.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var aliasesCard: some View {
        SectionCard("Also known as", systemImage: "character.book.closed") {
            FlowLayout {
                ForEach(exercise.aliasNames, id: \.self) { name in
                    Text(name)
                        .font(.subheadline)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s)
                        .background(Theme.Palette.subtle)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        SectionCard("Stats", systemImage: "chart.bar") {
            if workingSets.isEmpty {
                Text("No logged sets yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: Theme.Spacing.m) {
                    StatTile(value: bestWeightText, label: "Best load", systemImage: "scalemass")
                    StatTile(value: bestRepsText, label: "Best reps", systemImage: "repeat")
                    StatTile(value: oneRepMaxText, label: "Est. 1RM", systemImage: "arrow.up.right")
                    StatTile(value: "\(StatsKit.totalSets(workingSets))", label: "Total sets", systemImage: "number")
                    StatTile(value: "\(StatsKit.totalReps(workingSets))", label: "Total reps", systemImage: "sum")
                    StatTile(value: Format.weight(StatsKit.totalVolumeKg(workingSets)), label: "Total volume", systemImage: "chart.bar.fill")
                }
                Text("1RM is an Epley estimate, not a measured max.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Personal records

    @ViewBuilder
    private var personalRecordsCard: some View {
        let records = PersonalRecords.current(for: exercise)
        SectionCard("Personal records", systemImage: "trophy.fill") {
            if records.isEmpty {
                Text("No personal records yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(PRKind.allCases) { kind in
                        if let set = records[kind] {
                            personalRecordRow(kind, set: set)
                            if kind != lastRecordedKind(in: records) { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func personalRecordRow(_ kind: PRKind, set: WorkoutSet) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Label(kind.displayName, systemImage: kind.systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: 2) {
                Text(recordValueText(kind, set: set))
                    .font(.body.weight(.semibold))
                Text(set.timestamp.formatted(.dateTime.month().day().year()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recordValueText(_ kind: PRKind, set: WorkoutSet) -> String {
        switch kind {
        case .load, .reps:
            return Format.setSummary(set)
        case .estimatedOneRepMax:
            return Format.weight(set.estimatedOneRepMaxKg)
        }
    }

    private func lastRecordedKind(in records: [PRKind: WorkoutSet]) -> PRKind? {
        PRKind.allCases.last { records[$0] != nil }
    }

    private var chartCard: some View {
        SectionCard("Progress", systemImage: "chart.xyaxis.line") {
            Picker("Metric", selection: $chartMetric) {
                ForEach(ChartMetric.allCases) { metric in
                    Text(metric.label).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            MetricLineChart(points: chartPoints, unitSuffix: " \(Format.weightUnit.symbol)")

            if chartMetric == .oneRepMax {
                Text("Estimated 1RM per session (estimate).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sets

    private var setsCard: some View {
        SectionCard("Set history", systemImage: "list.bullet") {
            if sets.isEmpty {
                Text("No sets logged for this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = showAllSets ? sets : Array(sets.prefix(recentLimit))
                ForEach(shown) { set in
                    setRow(set)
                    if set.id != shown.last?.id { Divider() }
                }
                if sets.count > recentLimit {
                    Button(showAllSets ? "Show recent only" : "Show all \(sets.count) sets") {
                        showAllSets.toggle()
                    }
                    .font(.subheadline)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }

    private func setRow(_ set: WorkoutSet) -> some View {
        let prKinds = PersonalRecords.kinds(for: set, in: exercise.sets ?? [])
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.s) {
                    Text(Format.setSummary(set))
                        .font(.body.weight(.medium))
                    PRBadge(kinds: prKinds)
                }
                HStack(spacing: Theme.Spacing.s) {
                    Text(set.timestamp.formatted(.dateTime.month().day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if set.isWarmup {
                        Text("Warm-up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let effort = set.effort {
                        Text(EffortScale.shortLabel(for: effort))
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.intensity(effort))
                    }
                }
            }
            Spacer()
            if set.source != .manual {
                SourceBadge(text: set.source.displayName)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Derived stats text

    private var workingSets: [WorkoutSet] {
        sets.filter { !$0.isWarmup }
    }

    private var bestWeightText: String {
        guard let best = StatsKit.bestSetByWeight(sets) else { return "—" }
        return Format.setSummary(best)
    }

    private var bestRepsText: String {
        guard let best = StatsKit.bestRepsSet(sets), let reps = best.reps else { return "—" }
        return "\(reps)"
    }

    private var oneRepMaxText: String {
        guard let value = StatsKit.bestEstimatedOneRepMaxKg(sets) else { return "—" }
        return Format.weight(value)
    }

    private var chartPoints: [StatsKit.SessionPoint] {
        switch chartMetric {
        case .bestLoad: return StatsKit.bestLoadPerSession(sets)
        case .oneRepMax: return StatsKit.estimatedOneRepMaxPerSession(sets)
        }
    }

    private func muscleList(_ muscles: [MuscleGroup]) -> String {
        muscles.isEmpty ? "—" : muscles.map(\.displayName).joined(separator: ", ")
    }

    // MARK: - Actions

    private func toggleFavorite() {
        exercise.isFavorite.toggle()
        exercise.touch()
        try? context.save()
    }

    private func toggleGoal() {
        exercise.isGoalExercise.toggle()
        exercise.touch()
        try? context.save()
    }

    private func toggleArchived() {
        exercise.archived.toggle()
        exercise.touch()
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let exercises = (try? container.mainContext.fetch(FetchDescriptor<Exercise>())) ?? []
    let exercise = exercises.first { $0.canonicalName == "Bench Press" }
        ?? exercises.first
        ?? Exercise(canonicalName: "Bench Press")
    return NavigationStack {
        ExerciseDetailView(exercise: exercise)
    }
    .modelContainer(container)
}
