import Foundation
import SwiftData

/// An alternative name for an exercise, in any language. Enables matching
/// "тяга блока" / "lat pulldown" / "спина тренажер" to one canonical exercise.
@Model
final class ExerciseAlias {
    var id: UUID = UUID()
    var aliasName: String = ""
    /// Optional BCP-47-ish language hint (e.g. "uk", "cs"); free-form, optional.
    var languageOptional: String?
    var createdAt: Date = Date()

    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        aliasName: String = "",
        languageOptional: String? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.aliasName = aliasName
        self.languageOptional = languageOptional
        self.exercise = exercise
        self.createdAt = Date()
    }
}
