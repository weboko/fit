import Foundation

/// One group of identical plates loaded on a single side of the bar.
/// `Identifiable` so views can `ForEach` over the breakdown directly.
struct PlateGroup: Identifiable {
    let plate: Double
    let count: Int
    var id: Double { plate }
}

/// Result of solving a plate-loading problem (spec F8).
/// All weights are in kg, matching the app's storage convention.
struct PlateResult {
    /// Plates to load on each side, largest first.
    let perSide: [PlateGroup]
    /// Per-side weight that couldn't be matched with the available plates (kg).
    let remainderKg: Double
    /// The total bar load actually achievable with this breakdown (kg).
    let achievableKg: Double

    /// Sum of one side's placed plates (kg).
    var placedPerSideKg: Double {
        perSide.reduce(0) { $0 + $1.plate * Double($1.count) }
    }

    /// Whether the target was matched exactly (within float tolerance).
    var isExact: Bool { remainderKg <= PlateMath.epsilon }
}

/// Pure, deterministic plate-loading math. No state, no I/O.
enum PlateMath {
    /// Tolerance for floating-point comparisons so small dust (e.g. 1.2499999)
    /// doesn't leave a phantom remainder or block a plate from being placed.
    static let epsilon = 0.0001

    /// Greedily solves how to load `targetKg` on a bar of `barKg` using the
    /// `available` per-side plate sizes (unlimited count of each).
    ///
    /// - The required per-side load is `max(0, (targetKg - barKg) / 2)`.
    /// - Plates are placed largest-first, taking each plate as many times as it
    ///   fits, then moving to the next smaller size.
    /// - `remainderKg` is the per-side weight left unmatched; `achievableKg` is
    ///   the realised total bar load (`barKg + 2 * placed`).
    ///
    /// Edge cases handled: `targetKg < barKg` (no plates, no remainder,
    /// achievable is just the bar) and an empty `available` list (the whole
    /// per-side load becomes the remainder).
    static func solve(targetKg: Double, barKg: Double, available: [Double]) -> PlateResult {
        let perSideNeeded = max(0, (targetKg - barKg) / 2)

        // Below the bar, or nothing to add: just the bar.
        guard perSideNeeded > epsilon else {
            return PlateResult(perSide: [], remainderKg: 0, achievableKg: barKg)
        }

        // Largest first; ignore non-positive sizes defensively.
        let plates = available.filter { $0 > epsilon }.sorted(by: >)

        var remaining = perSideNeeded
        var groups: [PlateGroup] = []

        for plate in plates {
            guard remaining > epsilon else { break }
            let count = Int((remaining + epsilon) / plate)
            if count > 0 {
                groups.append(PlateGroup(plate: plate, count: count))
                remaining -= plate * Double(count)
            }
        }

        let placedPerSide = perSideNeeded - remaining
        let remainder = max(0, remaining)
        // Snap dust to zero so the UI doesn't report a meaningless shortfall.
        let cleanRemainder = remainder <= epsilon ? 0 : remainder
        let achievable = barKg + 2 * placedPerSide

        return PlateResult(
            perSide: groups,
            remainderKg: cleanRemainder,
            achievableKg: achievable
        )
    }
}
