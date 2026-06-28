import Foundation
import SwiftData

/// A reusable workout template / routine: an ordered list of planned exercises
/// with per-exercise targets (sets × reps @ weight). Templates let the user save
/// a finished workout and start new ones from it, pre-creating the exercise list
/// (spec F4). Deterministic only — never AI generated.
///
/// SwiftData + CloudKit constraints honoured here (matching the other models):
/// - every stored property has a default value,
/// - every relationship is optional,
/// - the inverse is declared on this (parent) side only,
/// - no `.unique` attributes (CloudKit does not support them).
@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    var items: [TemplateItem]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Convenience

extension WorkoutTemplate {
    /// Items in their stored display order.
    var orderedItems: [TemplateItem] {
        (items ?? []).sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.exerciseNameAtTime.localizedCaseInsensitiveCompare($1.exerciseNameAtTime) == .orderedAscending
        }
    }

    /// Number of planned exercises in this template.
    var itemCount: Int { (items ?? []).count }

    /// A short, human display name, falling back to a generic label.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled template" : trimmed
    }

    func touch() { updatedAt = Date() }
}
