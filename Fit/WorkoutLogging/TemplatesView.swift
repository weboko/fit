import SwiftUI
import SwiftData

/// Lists the user's reusable workout templates and lets them create, rename,
/// reorder-content, edit and delete them (spec F4). Tapping a template opens the
/// editor. An `EmptyStateView` is shown when there are none.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    @State private var newTemplate: WorkoutTemplate?

    var body: some View {
        Group {
            if templates.isEmpty {
                EmptyStateView(
                    title: "No templates yet",
                    message: "Save a finished workout as a template, or create one here, to start future workouts faster.",
                    systemImage: "list.bullet.rectangle.portrait",
                    actionTitle: "Create template",
                    action: createTemplate
                )
            } else {
                List {
                    ForEach(templates) { template in
                        NavigationLink {
                            TemplateEditorView(template: template)
                        } label: {
                            row(template)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createTemplate()
                } label: {
                    Label("New template", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $newTemplate) { template in
            TemplateEditorView(template: template)
        }
    }

    private func row(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(template.displayName)
                .font(.headline)
            Text(subtitle(for: template))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func subtitle(for template: WorkoutTemplate) -> String {
        let count = template.itemCount
        let countPart = "\(count) exercise\(count == 1 ? "" : "s")"
        let names = template.orderedItems.map(\.displayName).filter { !$0.isEmpty }
        if names.isEmpty { return countPart }
        return countPart + " · " + names.joined(separator: ", ")
    }

    // MARK: - Actions

    private func createTemplate() {
        let template = WorkoutTemplate(name: "")
        context.insert(template)
        try? context.save()
        newTemplate = template
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(templates[index])
        }
        try? context.save()
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
        template.items = [item]
    }
    try? context.save()
    return NavigationStack {
        TemplatesView()
    }
    .modelContainer(container)
}
