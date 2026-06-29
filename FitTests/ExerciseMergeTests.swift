import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Locks the exercise-merge mechanics (spec §21), driven through the REAL
/// `ExerciseMerge.merge(_:into:context:)` that `ExerciseMergeView` calls. The merge
/// loop was extracted (additively) from the View precisely so it can be exercised
/// against a live `ModelContext` here; the View only adds save/dismiss around it.
///
/// Runs on the single shared test container (`ModelTestSupport`) which is NOT reset
/// between tests, so every test uses fresh `UUID()`s and asserts only on its own
/// objects.
@MainActor
final class ExerciseMergeTests: XCTestCase {

    func testMergeMovesSetsKeepsNameAsAliasAndDeletesDuplicate() throws {
        let context = ModelTestSupport.makeContext()

        // Canonical C and duplicate D with two sets on D.
        let canonical = Exercise(canonicalName: "Lat Pulldown")
        let duplicate = Exercise(canonicalName: "Cable Pulldown")
        context.insert(canonical)
        context.insert(duplicate)

        let set1 = WorkoutSet(id: UUID(), exerciseNameAtTime: "Cable Pulldown")
        set1.exercise = duplicate
        let set2 = WorkoutSet(id: UUID(), exerciseNameAtTime: "Cable Pulldown")
        set2.exercise = duplicate
        context.insert(set1)
        context.insert(set2)
        try context.save()

        let canonicalID = canonical.id
        let duplicateID = duplicate.id

        // Merge D → C.
        ExerciseMerge.merge([duplicate], into: canonical, context: context)
        try context.save()

        // Sets now reference the canonical exercise…
        XCTAssertEqual(set1.exercise?.id, canonicalID)
        XCTAssertEqual(set2.exercise?.id, canonicalID)
        // …and their historical name snapshot is preserved untouched.
        XCTAssertEqual(set1.exerciseNameAtTime, "Cable Pulldown")
        XCTAssertEqual(set2.exerciseNameAtTime, "Cable Pulldown")

        // The duplicate's name survives as an alias on the canonical.
        XCTAssertTrue(canonical.aliasNames.contains("Cable Pulldown"),
                      "Merged exercise's name should be kept as an alias on the canonical.")

        // The duplicate Exercise is gone from the store.
        var dupDescriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == duplicateID })
        dupDescriptor.fetchLimit = 1
        XCTAssertNil(try context.fetch(dupDescriptor).first,
                     "Merged duplicate exercise should be deleted.")
    }

    func testMergeCarriesDuplicateAliasesAndDedupesExistingNames() throws {
        let context = ModelTestSupport.makeContext()

        let canonical = Exercise(canonicalName: "Bench Press")
        context.insert(canonical)
        // Canonical already has an alias that the duplicate's name will collide with
        // (case-insensitively) — it must NOT be duplicated.
        let existingAlias = ExerciseAlias(aliasName: "Flat Bench", exercise: canonical)
        context.insert(existingAlias)

        let duplicate = Exercise(canonicalName: "flat bench") // collides with existing alias
        context.insert(duplicate)
        // The duplicate carries its own alias, which is genuinely new.
        let dupAlias = ExerciseAlias(aliasName: "Barbell Bench", languageOptional: "en", exercise: duplicate)
        context.insert(dupAlias)
        try context.save()

        ExerciseMerge.merge([duplicate], into: canonical, context: context)
        try context.save()

        let names = canonical.aliasNames
        // The duplicate's own alias came across.
        XCTAssertTrue(names.contains("Barbell Bench"))
        // "flat bench" collides case-insensitively with the existing "Flat Bench"
        // alias, so it must NOT be added a second time.
        let flatBenchCount = names.filter { $0.lowercased() == "flat bench" }.count
        XCTAssertEqual(flatBenchCount, 1, "Case-insensitive duplicate alias must not be created.")
    }
}
