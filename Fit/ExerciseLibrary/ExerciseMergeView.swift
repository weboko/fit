import SwiftUI
import SwiftData

/// Merge one or more duplicate exercises into a canonical exercise (spec §21).
///
/// On merge:
/// - every set of a merged exercise is reassigned to the canonical
///   (`set.exercise = canonical`),
/// - `set.exerciseNameAtTime` is left untouched (historical snapshot),
/// - the merged exercise's canonical name and all its aliases are preserved as
///   aliases on the canonical exercise,
/// - the merged `Exercise` objects are then deleted.
struct ExerciseMergeView: View {
    /// The canonical exercise everything is merged into.
    let canonical: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.canonicalName, order: .forward)
    private var allExercises: [Exercise]

    @State private var selectedIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var showingConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DetailRow(label: "Merge into", value: canonical.canonicalName.isEmpty ? "Untitled" : canonical.canonicalName)
                    Text("Selected exercises and their history will be folded into this exercise, and their names kept as aliases. This cannot be undone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Choose duplicates to merge") {
                    if mergeCandidates.isEmpty {
                        Text("No other exercises to merge.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mergeCandidates) { exercise in
                            Button {
                                toggle(exercise)
                            } label: {
                                HStack {
                                    Image(systemName: selectedIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(exercise.id) ? Color.accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.canonicalName.isEmpty ? "Untitled" : exercise.canonicalName)
                                            .foregroundStyle(.primary)
                                        Text(detail(for: exercise))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if exercise.archived {
                                        Text("Archived")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Merge Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Merge") { showingConfirm = true }
                        .disabled(selectedIDs.isEmpty)
                }
            }
            .alert("Merge \(selectedIDs.count) exercise\(selectedIDs.count == 1 ? "" : "s")?", isPresented: $showingConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Merge", role: .destructive) { performMerge() }
            } message: {
                Text("All sets will move to “\(canonical.canonicalName)”, the merged names become aliases, and the duplicates are deleted. This cannot be undone.")
            }
        }
    }

    // MARK: - Derived

    /// Everything except the canonical target itself, filtered by search.
    private var mergeCandidates: [Exercise] {
        allExercises.filter { exercise in
            exercise.id != canonical.id && exercise.matches(query: searchText)
        }
    }

    private func detail(for exercise: Exercise) -> String {
        let setCount = (exercise.sets ?? []).count
        var parts = ["\(setCount) set\(setCount == 1 ? "" : "s")"]
        if !exercise.aliasNames.isEmpty {
            parts.append("aliases: \(exercise.aliasNames.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func toggle(_ exercise: Exercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }

    private func performMerge() {
        let toMerge = mergeCandidates.filter { selectedIDs.contains($0.id) }
        guard !toMerge.isEmpty else { return }

        // Names already present on the canonical (canonical + aliases), lowercased,
        // so we don't create duplicate aliases.
        var existingNames = Set(canonical.searchableNames.map { $0.lowercased() })

        func addAliasIfNew(_ name: String, language: String?) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            guard !existingNames.contains(key) else { return }
            existingNames.insert(key)
            let alias = ExerciseAlias(aliasName: trimmed, languageOptional: language, exercise: canonical)
            context.insert(alias)
        }

        for merged in toMerge {
            // Move every set to the canonical exercise; keep exerciseNameAtTime.
            for set in merged.sets ?? [] {
                set.exercise = canonical
                set.touch()
            }
            // Preserve the merged name as an alias.
            addAliasIfNew(merged.canonicalName, language: nil)
            // Preserve the merged exercise's own aliases.
            for alias in merged.aliases ?? [] {
                addAliasIfNew(alias.aliasName, language: alias.languageOptional)
            }
            // Delete the merged exercise (cascade removes its now-empty aliases).
            context.delete(merged)
        }

        canonical.touch()
        try? context.save()
        dismiss()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let exercises = (try? container.mainContext.fetch(FetchDescriptor<Exercise>())) ?? []
    let canonical = exercises.first ?? Exercise(canonicalName: "Bench Press")
    if exercises.isEmpty { container.mainContext.insert(canonical) }
    return ExerciseMergeView(canonical: canonical)
        .modelContainer(container)
}
