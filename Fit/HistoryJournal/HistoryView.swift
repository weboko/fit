import SwiftUI
import SwiftData

/// Tab entry point for the History + Journal module.
///
/// Top picker switches between the finished-workout history (grouped by day,
/// most recent first) and a flat journal timeline. A toolbar "+" opens the
/// backfill flow for logging a past workout after the fact.
struct HistoryView: View {

    /// The modes shown by the top picker.
    private enum Mode: String, CaseIterable, Identifiable {
        case workouts
        case journal
        case insights
        var id: String { rawValue }
        var label: String {
            switch self {
            case .workouts: return "Workouts"
            case .journal: return "Journal"
            case .insights: return "Insights"
            }
        }
    }

    @Environment(\.modelContext) private var context

    /// All sessions newest first; we split active vs finished in memory so the
    /// predicate stays simple (predicates cannot call custom helpers).
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var mode: Mode = .workouts
    @State private var showingBackfill = false

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .workouts: workoutsList
                case .journal: JournalTimelineView()
                case .insights: InsightsView()
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
                if mode == .workouts {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingBackfill = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Backfill past workout")
                    }
                }
            }
            .sheet(isPresented: $showingBackfill) {
                BackfillWorkoutView()
            }
        }
    }

    // MARK: Workouts list

    @ViewBuilder
    private var workoutsList: some View {
        if finishedSessions.isEmpty && activeSession == nil {
            EmptyStateView(
                title: "No workouts yet",
                message: "Finished workouts will appear here. Use + to log a past workout.",
                systemImage: "calendar",
                actionTitle: "Log a past workout",
                action: { showingBackfill = true }
            )
        } else {
            List {
                if let active = activeSession {
                    Section("In progress") {
                        NavigationLink {
                            WorkoutDetailView(session: active)
                        } label: {
                            ActiveWorkoutRow(session: active)
                        }
                    }
                }
                ForEach(groupedFinished, id: \.day) { group in
                    Section(sectionTitle(for: group.day)) {
                        ForEach(group.sessions) { session in
                            NavigationLink {
                                WorkoutDetailView(session: session)
                            } label: {
                                WorkoutHistoryRow(session: session)
                            }
                        }
                        .onDelete { offsets in
                            delete(at: offsets, in: group.sessions)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: Derived data

    private var activeSession: WorkoutSession? {
        sessions.first { $0.isActive }
    }

    private var finishedSessions: [WorkoutSession] {
        sessions.filter { !$0.isActive }
    }

    private struct DayGroup {
        let day: Date
        let sessions: [WorkoutSession]
    }

    private var groupedFinished: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: finishedSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped
            .map { DayGroup(day: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
            .sorted { $0.day > $1.day }
    }

    private func sectionTitle(for day: Date) -> String {
        Format.relativeDay(day)
    }

    // MARK: Actions

    private func delete(at offsets: IndexSet, in groupSessions: [WorkoutSession]) {
        for index in offsets {
            let session = groupSessions[index]
            context.delete(session)
        }
        try? context.save()
    }
}

// MARK: - Rows

/// One finished-workout row: title, date, duration and set count.
private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(session.displayTitle())
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.s)
                if session.isBackfilled {
                    SourceBadge(text: "Backfilled", systemImage: "clock.arrow.circlepath")
                }
            }
            HStack(spacing: Theme.Spacing.m) {
                Label(session.startTime.formatted(date: .omitted, time: .shortened),
                      systemImage: "clock")
                Label(Format.durationCompact(session.duration), systemImage: "timer")
                Label("\(session.orderedSets.count) sets", systemImage: "list.number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}

/// Row for the in-progress session, styled distinctly.
private struct ActiveWorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(session.displayTitle())
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.s)
                Label("Live", systemImage: "record.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            HStack(spacing: Theme.Spacing.m) {
                Label("Started \(session.startTime.formatted(date: .omitted, time: .shortened))",
                      systemImage: "clock")
                Label("\(session.orderedSets.count) sets", systemImage: "list.number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
