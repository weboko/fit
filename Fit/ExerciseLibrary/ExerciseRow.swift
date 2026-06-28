import SwiftUI

/// A compact list row for an exercise in the library. Shows the canonical name,
/// favourite / goal markers, category + equipment subtitle (or aliases), and an
/// archived badge. Tapping is handled by the enclosing `NavigationLink`.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(exercise.canonicalName.isEmpty ? "Untitled exercise" : exercise.canonicalName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(exercise.archived ? .secondary : .primary)
                        .lineLimit(1)

                    if exercise.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if exercise.isGoalExercise {
                        Image(systemName: "target")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            if exercise.archived {
                Text("Archived")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 2)
                    .background(Theme.Palette.subtle)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    /// Category + equipment if known, otherwise the alias list, otherwise nil.
    private var subtitle: String? {
        var parts: [String] = []
        if let category = exercise.category { parts.append(category.displayName) }
        if let equipment = exercise.equipment { parts.append(equipment.displayName) }
        if !parts.isEmpty { return parts.joined(separator: " · ") }

        let aliases = exercise.aliasNames
        if !aliases.isEmpty { return aliases.joined(separator: ", ") }
        return nil
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let exercise = Exercise(
        canonicalName: "Bench Press",
        category: .chest,
        equipment: .barbell,
        isGoalExercise: true,
        isFavorite: true
    )
    return List {
        ExerciseRow(exercise: exercise)
    }
    .modelContainer(container)
}
