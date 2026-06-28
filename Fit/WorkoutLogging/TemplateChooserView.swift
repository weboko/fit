import SwiftUI
import SwiftData

/// A sheet that lets the user pick one of their templates to start a new workout
/// from (spec F4). Choosing a template calls `onSelect` and dismisses; an
/// `EmptyStateView` is shown when there are no templates yet.
struct TemplateChooserView: View {
    /// Called with the chosen template. The sheet dismisses itself afterwards.
    let onSelect: (WorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    EmptyStateView(
                        title: "No templates yet",
                        message: "Create a template from the Templates screen, or save a finished workout as one, then start from it here.",
                        systemImage: "list.bullet.rectangle.portrait"
                    )
                } else {
                    List(templates) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            row(template)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Start from template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(template.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
            let items = template.orderedItems
            if items.isEmpty {
                Text("No exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(items.map(\.displayName).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let template = WorkoutTemplate(name: "Push day")
    context.insert(template)
    if let bench = exercises.first(where: { $0.canonicalName == "Bench Press" }) {
        let item = TemplateItem(order: 0, targetSets: 4, targetReps: 8, targetWeightKg: 60,
                                weightMode: .external, exercise: bench,
                                exerciseNameAtTime: bench.canonicalName)
        item.template = template
        context.insert(item)
        template.items = [item]
    }
    try? context.save()
    return TemplateChooserView { _ in }
        .modelContainer(container)
}
