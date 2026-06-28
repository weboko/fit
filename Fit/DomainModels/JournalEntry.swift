import Foundation
import SwiftData

/// A free-text journal/review entry. Can be attached at workout, exercise or
/// set level. The journal is a separate layer from live logging (spec §9).
@Model
final class JournalEntry {
    var id: UUID = UUID()

    /// Parent workout (relationship for cascade delete). Optional so standalone
    /// journal entries are possible.
    var workout: WorkoutSession?

    /// Optional finer-grained targets, stored as IDs to keep the graph simple.
    var exerciseIdOptional: UUID?
    var setIdOptional: UUID?

    var timestamp: Date = Date()
    var entryTypeRaw: String = JournalEntryType.workoutNote.rawValue
    var text: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        workout: WorkoutSession? = nil,
        exerciseIdOptional: UUID? = nil,
        setIdOptional: UUID? = nil,
        timestamp: Date = Date(),
        entryType: JournalEntryType = .workoutNote,
        text: String = ""
    ) {
        self.id = id
        self.workout = workout
        self.exerciseIdOptional = exerciseIdOptional
        self.setIdOptional = setIdOptional
        self.timestamp = timestamp
        self.entryTypeRaw = entryType.rawValue
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension JournalEntry {
    var entryType: JournalEntryType {
        get { JournalEntryType(rawValue: entryTypeRaw) ?? .workoutNote }
        set { entryTypeRaw = newValue.rawValue }
    }

    func touch() { updatedAt = Date() }
}
