import Foundation
import XCTest
@testable import Fit

/// `WeightUnit` kg↔lb conversion. Storage is always kg; these only affect what
/// the user sees and types. Pure arithmetic — no UserDefaults dependence here
/// (we call the unit's methods directly rather than going through `Format`).
final class WeightConversionTests: XCTestCase {

    func testKilogramsAreAnIdentityConversion() {
        XCTAssertEqual(WeightUnit.kg.perKg, 1.0)
        XCTAssertEqual(WeightUnit.kg.fromKg(72.5), 72.5)
        XCTAssertEqual(WeightUnit.kg.toKg(72.5), 72.5)
    }

    func testKilogramsToPoundsKnownValue() {
        // 100 kg → 220.46226218 lb (factor 2.2046226218).
        XCTAssertEqual(WeightUnit.lb.fromKg(100), 220.46226218, accuracy: 1e-6)
    }

    func testPoundsToKilogramsKnownValue() {
        // 45 lb plate ≈ 20.4117 kg.
        XCTAssertEqual(WeightUnit.lb.toKg(45), 45.0 / 2.2046226218, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.lb.toKg(45), 20.41165665, accuracy: 1e-6)
    }

    func testKgToLbRoundTripWithinTolerance() {
        for kg in [0.0, 2.5, 20.0, 60.0, 100.0, 142.5] {
            let lb = WeightUnit.lb.fromKg(kg)
            let back = WeightUnit.lb.toKg(lb)
            XCTAssertEqual(back, kg, accuracy: 1e-9, "round-trip failed for \(kg) kg")
        }
    }

    func testSymbolsAndIncrements() {
        XCTAssertEqual(WeightUnit.kg.symbol, "kg")
        XCTAssertEqual(WeightUnit.lb.symbol, "lb")
        XCTAssertEqual(WeightUnit.kg.quickIncrements, [1, 2.5, 5])
        XCTAssertEqual(WeightUnit.lb.quickIncrements, [2.5, 5, 10])
    }

    /// `Format.weight` honours an explicitly passed unit (so the test does not
    /// depend on the persisted UserDefaults preference).
    func testFormatWeightUsesExplicitUnit() {
        XCTAssertEqual(Format.weight(100, unit: .kg), "100 kg")
        // 100 kg shown in lb: 220.46… rounded to 2 decimals ⇒ "220.46 lb".
        XCTAssertEqual(Format.weight(100, unit: .lb), "220.46 lb")
        XCTAssertEqual(Format.weight(nil, unit: .kg), "—")
        XCTAssertEqual(Format.weight(100, unit: .kg, includeSymbol: false), "100")
    }
}
