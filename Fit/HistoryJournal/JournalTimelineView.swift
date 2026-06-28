import SwiftUI
import SwiftData

/// A flat timeline of every `JournalEntry`, newest first, with tap-to-edit.
///
/// Used as one half of `HistoryView`'s picker. Standalone notes (no workout)
/// can be created here with the "+" button; entries attached to a workout are
/// editable too and show their context.
struct JournalTimelineView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \JournalEntry.timestamp, order: .reverse)
    private var entries: [JournalEntry]

    @State private var editing: JournalEntry?
    @State private var creatingNew = false

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(
                    title: "No journal entries",
                    message: "Capture how training felt, niggles, or anything worth remembering.",
                    systemImage: "text.book.closed",
                    actionTitle: "New note",
                    action: { creatingNew = true }
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        Button {
                            editing = entry
                        } label: {
                            JournalEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creatingNew = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New journal note")
            }
        }
        .sheet(item: $editing) { entry in
            JournalEntryEditor(entry: entry)
        }
        .sheet(isPresented: $creatingNew) {
            JournalEntryEditor(workout: nil)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        try? context.save()
    }
}

/// A single timeline row showing the entry type, when it happened, the text and
/// the linked workout (if any).
struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Label(entry.entryType.displayName, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.s)
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(displayText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(4)
            if let workout = entry.workout {
                Label(workout.displayTitle(), systemImage: "dumbbell")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var displayText: String {
        let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(empty note)" : trimmed
    }

    private var icon: String {
        switch entry.entryType {
        case .workoutNote: return "note.text"
        case .exerciseNote: return "dumbbell"
        case .setNote: return "list.number"
        case .correction: return "pencil.and.outline"
        }
    }
}

#Preview {
    NavigationStack {
        JournalTimelineView()
            .navigationTitle("Journal")
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
