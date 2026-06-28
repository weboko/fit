import SwiftUI
import SwiftData

/// The Exercise Library tab. A searchable, filterable list of all exercises
/// (canonical names + aliases), with create-new, favourite/goal markers,
/// archive visibility toggle and swipe actions (spec §10, §14.6, §17).
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context

    // All exercises; archived filtering and text search are done in memory
    // because `#Predicate` cannot call `Exercise.matches(query:)`.
    @Query(sort: \Exercise.canonicalName, order: .forward)
    private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var categoryFilter: ExerciseCategory?
    @State private var showArchived = false
    @State private var quickAddName = ""
    @State private var showingQuickAdd = false
    @State private var newExercise: Exercise?

    var body: some View {
        NavigationStack {
            List {
                if filteredExercises.isEmpty {
                    Section {
                        emptyState
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(filteredExercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    toggleArchived(exercise)
                                } label: {
                                    Label(exercise.archived ? "Unarchive" : "Archive",
                                          systemImage: exercise.archived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(exercise.archived ? .blue : .gray)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggleFavorite(exercise)
                                } label: {
                                    Label(exercise.isFavorite ? "Unfavorite" : "Favorite",
                                          systemImage: exercise.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                        }
                    } header: {
                        Text("\(filteredExercises.count) exercise\(filteredExercises.count == 1 ? "" : "s")")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search name or alias")
            .safeAreaInset(edge: .top) { categoryBar }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle(isOn: $showArchived) {
                            Label("Show archived", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            createAndEditNew()
                        } label: {
                            Label("New exercise (full)", systemImage: "square.and.pencil")
                        }
                        Button {
                            quickAddName = ""
                            showingQuickAdd = true
                        } label: {
                            Label("Quick add by name", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Programmatic navigation into the editor for a freshly created exercise.
            .navigationDestination(item: $newExercise) { exercise in
                ExerciseEditView(exercise: exercise)
            }
            // If the user backs out of a freshly created (still blank) exercise
            // without saving, discard it so the list isn't polluted.
            .onChange(of: newExercise) { _, new in
                if new == nil { purgeBlankUnsavedExercises() }
            }
            .alert("New exercise", isPresented: $showingQuickAdd) {
                TextField("Name", text: $quickAddName)
                Button("Cancel", role: .cancel) { quickAddName = "" }
                Button("Add") { quickAdd() }
                    .disabled(trimmedQuickAddName.isEmpty)
            } message: {
                Text("Add a new exercise by name. You can fill in the details later.")
            }
        }
    }

    // MARK: - Subviews

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                OptionChip(title: "All", isSelected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(Array(ExerciseCategory.allCases)) { category in
                    OptionChip(title: category.displayName,
                               isSelected: categoryFilter == category) {
                        categoryFilter = (categoryFilter == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if allExercises.isEmpty {
            EmptyStateView(
                title: "No exercises yet",
                message: "Create your first exercise to start logging sets.",
                systemImage: "dumbbell",
                actionTitle: "New exercise",
                action: { createAndEditNew() }
            )
            .padding(.vertical, Theme.Spacing.xl)
        } else {
            EmptyStateView(
                title: "No matches",
                message: "No exercises match your search or filters.",
                systemImage: "magnifyingglass"
            )
            .padding(.vertical, Theme.Spacing.xl)
        }
    }

    // MARK: - Derived data

    private var trimmedQuickAddName: String {
        quickAddName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            (showArchived || !exercise.archived) &&
            (categoryFilter == nil || exercise.category == categoryFilter) &&
            exercise.matches(query: searchText)
        }
    }

    // MARK: - Actions

    private func toggleArchived(_ exercise: Exercise) {
        exercise.archived.toggle()
        exercise.touch()
        try? context.save()
    }

    private func toggleFavorite(_ exercise: Exercise) {
        exercise.isFavorite.toggle()
        exercise.touch()
        try? context.save()
    }

    private func createAndEditNew() {
        let exercise = Exercise(canonicalName: "")
        context.insert(exercise)
        // Don't save yet: the editor's Save commits it; Cancel could discard it.
        newExercise = exercise
    }

    private func quickAdd() {
        let name = trimmedQuickAddName
        guard !name.isEmpty else { return }
        let exercise = Exercise(canonicalName: name)
        context.insert(exercise)
        try? context.save()
        quickAddName = ""
    }

    /// Removes exercises that were created for the editor but abandoned with a
    /// blank name and no history.
    private func purgeBlankUnsavedExercises() {
        var changed = false
        for exercise in allExercises {
            let blankName = exercise.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let noHistory = (exercise.sets ?? []).isEmpty && (exercise.aliases ?? []).isEmpty
            if blankName && noHistory {
                context.delete(exercise)
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
