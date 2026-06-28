import SwiftUI
import SwiftData

/// View and manually log body weight over time, with a trend chart (spec F6).
///
/// Storage stays in kg everywhere; the chart and rows display in the user's unit
/// via `Format.weight`. Each manual edit/add/delete refreshes the
/// `lastBodyWeightKg` UserDefaults key so that bodyweight-mode set entry picks up
/// the most recent weight as its default (see `SetEntryView`).
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \BodyWeightEntry.timestamp, order: .reverse)
    private var entries: [BodyWeightEntry]

    /// The manual entry being added or edited via the sheet.
    @State private var editing: BodyWeightEntry?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(
                    title: "No body weight yet",
                    message: "Log your body weight to see a trend over time. It's also offered as the default when you log bodyweight exercises.",
                    systemImage: "scalemass",
                    actionTitle: "Log weight",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    chartSection
                    statsSection
                    entriesSection
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Body weight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Log weight", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            BodyWeightEntryEditor(entry: nil, onCommit: refreshLatestDefault)
        }
        .sheet(item: $editing) { entry in
            BodyWeightEntryEditor(entry: entry, onCommit: refreshLatestDefault)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var chartSection: some View {
        Section {
            MetricLineChart(
                points: chartPoints,
                unitSuffix: " \(Format.weightUnit.symbol)",
                accessibilitySummary: chartAccessibilitySummary
            )
        } header: {
            Text("Trend")
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.m) {
                StatTile(
                    value: Format.weight(entries.first?.weightKg),
                    label: "Latest",
                    systemImage: "scalemass"
                )
                StatTile(
                    value: "\(entries.count)",
                    label: entries.count == 1 ? "Entry" : "Entries",
                    systemImage: "number"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        Section {
            ForEach(entries) { entry in
                row(entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if entry.source == .manual { editing = entry }
                    }
            }
            .onDelete(perform: delete)
        } header: {
            Text("History")
        }
    }

    private func row(_ entry: BodyWeightEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.weight(entry.weightKg))
                    .font(.headline)
                Spacer(minLength: Theme.Spacing.m)
                if entry.source == .healthImport {
                    SourceBadge(text: "Apple Health", systemImage: "heart.fill", tint: .pink)
                }
            }
            Text(Format.relativeDay(entry.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Derived

    /// Chart points oldest→newest, plotting the raw kg values (consistent with
    /// the other progress charts, which also plot kg with a kg suffix).
    private var chartPoints: [StatsKit.SessionPoint] {
        entries
            .sorted { $0.timestamp < $1.timestamp }
            .map { StatsKit.SessionPoint(date: $0.timestamp, value: $0.weightKg) }
    }

    /// A data-rich VoiceOver summary of the body-weight trend chart: number of
    /// entries, value range, latest weight and direction (spec F23). Formatted
    /// like the chart labels (raw kg figure + unit symbol); empty/single handled.
    private var chartAccessibilitySummary: String {
        let points = chartPoints
        guard let first = points.first, let last = points.last else {
            return "Body weight: no data yet."
        }
        let unit = Format.weightUnit.symbol
        func valueText(_ value: Double) -> String { "\(Format.decimal(value)) \(unit)" }
        let latest = valueText(last.value)
        if points.count == 1 {
            return "Body weight: one entry, \(latest)."
        }
        let low = points.map(\.value).min() ?? first.value
        let high = points.map(\.value).max() ?? last.value
        let trend: String
        if last.value > first.value { trend = "trending up" }
        else if last.value < first.value { trend = "trending down" }
        else { trend = "flat" }
        return "Body weight over \(points.count) entries: "
            + "\(valueText(low)) to \(valueText(high)), latest \(latest), \(trend)."
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        try? context.save()
        refreshLatestDefault()
    }

    /// Updates the shared "last body weight" default to the most recent entry's
    /// weight so bodyweight-mode set entry stays in sync. If no entries remain,
    /// the key is left untouched (don't clear a previously remembered value).
    private func refreshLatestDefault() {
        let latest = (try? context.fetch(latestDescriptor()))?.first
        guard let latest, latest.weightKg > 0 else { return }
        UserDefaults.standard.set(latest.weightKg, forKey: AppSettingsKeys.lastBodyWeightKg)
    }

    private func latestDescriptor() -> FetchDescriptor<BodyWeightEntry> {
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}

/// Add or edit a single manual body-weight measurement: date+time, weight and an
/// optional note. Saving inserts a new `.manual` entry or updates the given one,
/// then calls `onCommit` so the caller can refresh the "latest" default.
struct BodyWeightEntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The entry being edited, or nil when adding a new one.
    let entry: BodyWeightEntry?
    /// Called after a successful save so the latest-weight default can refresh.
    var onCommit: () -> Void

    @State private var timestamp: Date
    @State private var weightKg: Double?
    @State private var note: String

    init(entry: BodyWeightEntry?, onCommit: @escaping () -> Void) {
        self.entry = entry
        self.onCommit = onCommit
        _timestamp = State(initialValue: entry?.timestamp ?? Date())
        _weightKg = State(initialValue: entry.map { $0.weightKg }.flatMap { $0 > 0 ? $0 : nil })
        _note = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $timestamp)
                }
                Section("Weight") {
                    WeightStepperField(weightKg: $weightKg, recentKg: recentKg)
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(entry == nil ? "Log weight" : "Edit weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        (weightKg ?? 0) > 0
    }

    /// Recent manual/imported weights offered as one-tap suggestions, newest
    /// first, excluding the entry currently being edited.
    private var recentKg: [Double] {
        let descriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all
            .filter { $0.id != entry?.id && $0.weightKg > 0 }
            .prefix(8)
            .map(\.weightKg)
    }

    private func save() {
        guard let weightKg, weightKg > 0 else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.timestamp = timestamp
            entry.weightKg = weightKg
            entry.notes = trimmedNote
            entry.source = .manual
        } else {
            let newEntry = BodyWeightEntry(
                timestamp: timestamp,
                weightKg: weightKg,
                source: .manual
            )
            newEntry.notes = trimmedNote
            context.insert(newEntry)
        }
        try? context.save()
        onCommit()
        dismiss()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let calendar = Calendar.current
    let samples: [(Int, Double)] = [(0, 80.2), (7, 80.8), (14, 81.1), (21, 80.5), (28, 81.6)]
    for (daysAgo, kg) in samples {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let entry = BodyWeightEntry(timestamp: date, weightKg: kg, source: .manual)
        context.insert(entry)
    }
    try? context.save()
    return NavigationStack {
        BodyWeightView()
    }
    .modelContainer(container)
}
