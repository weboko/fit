import Foundation
import HealthKit

/// Static HealthKit helpers shared by the import service and the UI: the set of
/// READ object types we ask permission for, and a readable name for each
/// `HKWorkoutActivityType`. We never request any share/write types — the app is
/// strictly read-only against Health (spec §11, §26.3).
enum HealthKitTypes {

    // MARK: Quantity / category type identifiers we read

    /// Body mass (weight) quantity type.
    static var bodyMass: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bodyMass)
    }

    /// Heart-rate quantity type (instantaneous BPM samples).
    static var heartRate: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    static var restingHeartRate: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)
    }

    static var heartRateVariabilitySDNN: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    }

    static var activeEnergyBurned: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
    }

    static var basalEnergyBurned: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)
    }

    static var stepCount: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .stepCount)
    }

    static var sleepAnalysis: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    // MARK: Read-type set

    /// The complete set of object types we request READ access for. Built
    /// defensively: any identifier that fails to resolve on the current OS is
    /// simply omitted rather than crashing.
    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let optionals: [HKObjectType?] = [
            heartRate,
            restingHeartRate,
            heartRateVariabilitySDNN,
            activeEnergyBurned,
            basalEnergyBurned,
            bodyMass,
            stepCount,
            sleepAnalysis
        ]
        for type in optionals.compactMap({ $0 }) {
            types.insert(type)
        }
        return types
    }

    // MARK: Units

    static let kilocalorie = HKUnit.kilocalorie()
    static let kilogram = HKUnit.gramUnit(with: .kilo)
    static var beatsPerMinute: HKUnit { HKUnit.count().unitDivided(by: .minute()) }

    // MARK: Workout activity-type names

    /// A short, human-readable name for a workout activity type. Covers the
    /// strength-relevant types in detail and falls back to a generic label for
    /// the long tail so the UI never shows a raw integer.
    static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .mixedCardio: return "Mixed Cardio"
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"
        case .preparationAndRecovery: return "Recovery"
        case .hiking: return "Hiking"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .dance: return "Dance"
        case .barre: return "Barre"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .wrestling: return "Wrestling"
        case .martialArts: return "Martial Arts"
        case .swimBikeRun: return "Triathlon"
        case .other: return "Other Workout"
        default: return "Workout"
        }
    }

    /// SF Symbol that best represents a workout activity type, for list rows.
    static func symbol(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "dumbbell"
        case .coreTraining:
            return "figure.core.training"
        case .running:
            return "figure.run"
        case .walking, .hiking:
            return "figure.walk"
        case .cycling:
            return "figure.outdoor.cycle"
        case .swimming:
            return "figure.pool.swim"
        case .rowing:
            return "figure.rower"
        case .yoga, .pilates, .flexibility, .barre:
            return "figure.yoga"
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio:
            return "figure.highintensity.intervaltraining"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
}
