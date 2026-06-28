import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Deterministic arithmetic over `StatsKit` and the derived `WorkoutSet` values
/// it sums. Every expectation is computed by hand from the documented formulas:
///   - effective load (external mode) = weightKg
///   - volume = effectiveLoadKg × reps
///   - Epley est-1RM = load × (1 + reps/30); reps == 1 ⇒ load
/// `@MainActor` because the in-memory SwiftData fixtures are main-actor isolated.
@MainActor
final class StatsKitTests: XCTestCase {

    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = Fixture.emptyContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Derived per-set values (the building blocks StatsKit sums)

    func testEffectiveLoadAndVolumeForExternalSet() {
        let set = Fixture.externalSet(in: context, weightKg: 80, reps: 6)
        XCTAssertEqual(set.effectiveLoadKg, 80)
        // volume = 80 × 6 = 480
        XCTAssertEqual(set.volumeKg, 480)
    }

    func testEpleyOneRepMaxMatchesFormula() {
        let set = Fixture.externalSet(in: context, weightKg: 100, reps: 5)
        // 100 × (1 + 5/30) = 100 × 1.1666… = 116.666…
        let expected = 100.0 * (1.0 + 5.0 / 30.0)
        XCTAssertEqual(try XCTUnwrap(set.estimatedOneRepMaxKg), expected, accuracy: 1e-9)
    }

    func testEpleyOneRepMaxIsExactLoadAtOneRep() {
        let set = Fixture.externalSet(in: context, weightKg: 120, reps: 1)
        // Single rep: est-1RM is the load itself, not load × (1 + 1/30).
        XCTAssertEqual(set.estimatedOneRepMaxKg, 120)
    }

    // MARK: - StatsKit.totalVolumeKg

    func testTotalVolumeSumsWorkingSetsOnly() {
        // Working: 80×6 = 480, 100×3 = 300 ⇒ 780.
        Fixture.externalSet(in: context, weightKg: 80, reps: 6)
        Fixture.externalSet(in: context, weightKg: 100, reps: 3)
        // Warm-up must NOT count toward the default total.
        Fixture.externalSet(in: context, weightKg: 40, reps: 10, isWarmup: true)

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.totalVolumeKg(sets), 780, accuracy: 1e-9)
    }

    func testTotalVolumeIncludesWarmupsWhenRequested() {
        Fixture.externalSet(in: context, weightKg: 80, reps: 6)            // 480
        Fixture.externalSet(in: context, weightKg: 40, reps: 10, isWarmup: true) // 400

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.totalVolumeKg(sets, includeWarmups: true), 880, accuracy: 1e-9)
    }

    func testTotalSetsAndRepsExcludeWarmups() {
        Fixture.externalSet(in: context, weightKg: 80, reps: 6)
        Fixture.externalSet(in: context, weightKg: 100, reps: 4)
        Fixture.externalSet(in: context, weightKg: 40, reps: 12, isWarmup: true)

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.totalSets(sets), 2)
        XCTAssertEqual(StatsKit.totalReps(sets), 10) // 6 + 4, warm-up's 12 excluded
        XCTAssertEqual(StatsKit.totalSets(sets, includeWarmups: true), 3)
        XCTAssertEqual(StatsKit.totalReps(sets, includeWarmups: true), 22)
    }

    // MARK: - Bests

    func testBestSetByWeightPicksHeaviestAndBreaksTiesByReps() {
        let light = Fixture.externalSet(in: context, weightKg: 60, reps: 10)
        let heavy = Fixture.externalSet(in: context, weightKg: 100, reps: 3)
        // Tie on weight with `heavy` but more reps — should still lose to nothing
        // here; included to confirm heaviest wins regardless of rep count.
        _ = light

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.bestSetByWeight(sets)?.id, heavy.id)
    }

    func testBestSetByWeightTieBrokenByReps() {
        let fewReps = Fixture.externalSet(in: context, weightKg: 100, reps: 2)
        let moreReps = Fixture.externalSet(in: context, weightKg: 100, reps: 5)
        _ = fewReps

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        // Equal load ⇒ the set with more reps is the "best".
        XCTAssertEqual(StatsKit.bestSetByWeight(sets)?.id, moreReps.id)
    }

    func testBestSetByWeightIgnoresWarmups() {
        Fixture.externalSet(in: context, weightKg: 200, reps: 1, isWarmup: true)
        let working = Fixture.externalSet(in: context, weightKg: 90, reps: 5)

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.bestSetByWeight(sets)?.id, working.id)
    }

    func testBestRepsSet() {
        Fixture.externalSet(in: context, weightKg: 80, reps: 6)
        let mostReps = Fixture.externalSet(in: context, weightKg: 60, reps: 12)

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(StatsKit.bestRepsSet(sets)?.id, mostReps.id)
    }

    func testBestEstimatedOneRepMax() {
        // 100×5 ⇒ 116.67 ; 120×1 ⇒ 120 (the bigger). Best = 120.
        Fixture.externalSet(in: context, weightKg: 100, reps: 5)
        Fixture.externalSet(in: context, weightKg: 120, reps: 1)

        let sets = try! context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(try XCTUnwrap(StatsKit.bestEstimatedOneRepMaxKg(sets)), 120, accuracy: 1e-9)
    }

    func testEmptyInputsAreZeroOrNil() {
        let none: [WorkoutSet] = []
        XCTAssertEqual(StatsKit.totalVolumeKg(none), 0)
        XCTAssertEqual(StatsKit.totalSets(none), 0)
        XCTAssertEqual(StatsKit.totalReps(none), 0)
        XCTAssertNil(StatsKit.bestSetByWeight(none))
        XCTAssertNil(StatsKit.bestRepsSet(none))
        XCTAssertNil(StatsKit.bestEstimatedOneRepMaxKg(none))
    }
}
