import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Record-at-the-time detection: a set is judged only against earlier non-warmup
/// sets of the same exercise, and a value is a PR when it strictly exceeds every
/// earlier value of that kind (the first set producing a value is itself a PR).
/// `@MainActor` for the in-memory SwiftData fixtures.
@MainActor
final class PersonalRecordsTests: XCTestCase {

    private var context: ModelContext!
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        context = Fixture.emptyContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    private func set(_ weightKg: Double, _ reps: Int, offset: TimeInterval, warmup: Bool = false) -> WorkoutSet {
        Fixture.externalSet(
            in: context,
            weightKg: weightKg,
            reps: reps,
            isWarmup: warmup,
            timestamp: t0.addingTimeInterval(offset)
        )
    }

    func testFirstSetIsAlwaysAPRForEveryKind() {
        let first = set(80, 5, offset: 0)
        let kinds = PersonalRecords.kinds(for: first, in: [first])
        // First set with a load, reps and an est-1RM holds all three records.
        XCTAssertEqual(kinds, [.load, .reps, .estimatedOneRepMax])
    }

    func testStrictlyHeavierLaterSetIsALoadPR() {
        let earlier = set(80, 5, offset: 0)
        let later = set(90, 5, offset: 100) // heavier load, same reps
        let all = [earlier, later]

        let kinds = PersonalRecords.kinds(for: later, in: all)
        XCTAssertTrue(kinds.contains(.load))
        XCTAssertTrue(kinds.contains(.estimatedOneRepMax)) // 90×... > 80×...
        // Same reps as before, so reps is NOT a new record.
        XCTAssertFalse(kinds.contains(.reps))
    }

    func testEqualLoadIsNotALoadPR() {
        let earlier = set(100, 3, offset: 0)
        let later = set(100, 3, offset: 100) // identical — must NOT be a PR
        let all = [earlier, later]

        let kinds = PersonalRecords.kinds(for: later, in: all)
        XCTAssertFalse(kinds.contains(.load))
        XCTAssertFalse(kinds.contains(.reps))
        XCTAssertFalse(kinds.contains(.estimatedOneRepMax))
    }

    func testMoreRepsAtLighterLoadIsARepsPROnly() {
        let earlier = set(100, 3, offset: 0)
        let later = set(60, 10, offset: 100) // many more reps, lighter load
        let all = [earlier, later]

        let kinds = PersonalRecords.kinds(for: later, in: all)
        XCTAssertTrue(kinds.contains(.reps))
        XCTAssertFalse(kinds.contains(.load)) // 60 < 100
    }

    func testWarmupSetHoldsNoRecords() {
        let warmup = set(200, 1, offset: 0, warmup: true)
        let kinds = PersonalRecords.kinds(for: warmup, in: [warmup])
        XCTAssertTrue(kinds.isEmpty)
    }

    func testWarmupsAreSkippedWhenJudgingLaterSets() {
        // A heavy warm-up earlier must not block a lighter working PR.
        let heavyWarmup = set(300, 1, offset: 0, warmup: true)
        let working = set(120, 3, offset: 100)
        let all = [heavyWarmup, working]

        let kinds = PersonalRecords.kinds(for: working, in: all)
        // The working set is the first *non-warmup* set, so it is a PR despite
        // the heavier warm-up that came before it.
        XCTAssertTrue(kinds.contains(.load))
    }

    func testCurrentReturnsAllTimeBestPerKind() {
        let exercise = Fixture.exercise(in: context)
        let s1 = Fixture.externalSet(in: context, weightKg: 80, reps: 5, timestamp: t0, exercise: exercise)
        let s2 = Fixture.externalSet(in: context, weightKg: 100, reps: 3,
                                     timestamp: t0.addingTimeInterval(100), exercise: exercise)
        let s3 = Fixture.externalSet(in: context, weightKg: 60, reps: 15,
                                     timestamp: t0.addingTimeInterval(200), exercise: exercise)
        _ = (s1, s3)

        let current = PersonalRecords.current(for: exercise)
        XCTAssertEqual(current[.load]?.id, s2.id)   // heaviest = 100
        XCTAssertEqual(current[.reps]?.id, s3.id)   // most reps = 15
        // Best est-1RM: 100×3 = 110 vs 80×5 ≈ 93.3 vs 60×15 = 90 ⇒ s2.
        XCTAssertEqual(current[.estimatedOneRepMax]?.id, s2.id)
    }
}
