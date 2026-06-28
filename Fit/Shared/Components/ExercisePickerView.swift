import SwiftUI
import SwiftData

/// Reusable exercise picker presented as a sheet. Supports search across
/// canonical names and aliases, favourites, recently used, category filtering
/// and one-tap "create new exercise" (name only) for fast gym use (spec §14.2).
struct ExercisePickerView: View {
    /// Called with the chosen exercise. The caller is responsible for dismissal
    /// behaviour beyond the automatic dismiss performed here.
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Exercise> { !$0.archived },
           sort: \Exercise.canonicalName)
    private var exercises: [Exercise]

    @Query(sort: \WorkoutSet.timestamp, order: .reverse)
    private var recentSets: [WorkoutSet]

    @State private var searchText = ""
    @State private var categoryFilter: ExerciseCategory?

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty, categoryFilter == nil, !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { row($0) }
                    }
                }
                if searchText.isEmpty, categoryFilter == nil, !recentExercises.isEmpty {
                    Section("Recent") {
                        ForEach(recentExercises) { row($0) }
                    }
                }
                Section(searchText.isEmpty ? "All exercises" : "Results") {
                    if filtered.isEmpty {
                        createRow
                    } else {
                        ForEach(filtered) { row($0) }
                        if !trimmedQuery.isEmpty, !exactNameExists {
                            createRow
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search name or alias")
            .navigationTitle("Choose exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) { categoryBar }
        }
    }

    // MARK: Rows

    private func row(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(exercise.canonicalName)
                        .foregroundStyle(.primary)
                    if exercise.isGoalExercise {
                        Image(systemName: "target").font(.caption).foregroundStyle(.orange)
                            .accessibilityLabel("Goal exercise")
                    }
                }
                if let category = exercise.category {
                    Text(category.displayName + (exercise.equipment.map { " · \($0.displayName)" } ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !exercise.aliasNames.isEmpty {
                    Text(exercise.aliasNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var createRow: some View {
        Button {
            createAndSelect()
        } label: {
            Label(trimmedQuery.isEmpty ? "Create new exercise" : "Create “\(trimmedQuery)”",
                  systemImage: "plus.circle.fill")
        }
        .disabled(trimmedQuery.isEmpty)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                OptionChip(title: "All", isSelected: categoryFilter == nil) { categoryFilter = nil }
                ForEach(Array(ExerciseCategory.allCases)) { cat in
                    OptionChip(title: cat.displayName, isSelected: categoryFilter == cat) {
                        categoryFilter = (categoryFilter == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
        }
        .background(.bar)
    }

    // MARK: Derived data

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var exactNameExists: Bool {
        exercises.contains { $0.canonicalName.compare(trimmedQuery, options: .caseInsensitive) == .orderedSame }
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            (categoryFilter == nil || exercise.category == categoryFilter) &&
            exercise.matches(query: searchText)
        }
    }

    private var favorites: [Exercise] {
        exercises.filter(\.isFavorite)
    }

    private var recentExercises: [Exercise] {
        var seen = Set<UUID>()
        var result: [Exercise] = []
        for set in recentSets {
            guard let exercise = set.exercise, !exercise.archived else { continue }
            if seen.insert(exercise.id).inserted {
                result.append(exercise)
            }
            if result.count >= 8 { break }
        }
        return result
    }

    // MARK: Actions

    private func createAndSelect() {
        let exercise = Exercise(canonicalName: trimmedQuery)
        context.insert(exercise)
        try? context.save()
        onSelect(exercise)
        dismiss()
    }
}
