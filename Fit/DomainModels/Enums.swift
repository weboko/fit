import Foundation

// MARK: - Shared protocol for option-style enums

/// All option enums in the domain are stored as stable lowercase string raw
/// values (never integer positions) so the schema and exports remain stable
/// across releases, and expose a human-facing `displayName` for the UI.
public protocol DisplayableOption: RawRepresentable, CaseIterable, Codable, Hashable, Identifiable, Sendable where RawValue == String {
    var displayName: String { get }
}

public extension DisplayableOption {
    var id: String { rawValue }
}

// MARK: - Set-level enums

/// How the load for a set is expressed. Critical for pull-ups, which can be
/// bodyweight, assisted (negative load) or weighted (added load).
public enum WeightMode: String, DisplayableOption {
    case external          // e.g. bench press 80 kg on the bar
    case bodyweight        // pure bodyweight, e.g. a normal pull-up
    case assistedBodyweight // bodyweight minus assistance, e.g. -20 kg band/machine
    case addedBodyweight   // bodyweight plus added load, e.g. +10 kg weighted pull-up
    case unknown           // not entered / backfilled

    public var displayName: String {
        switch self {
        case .external: return "External weight"
        case .bodyweight: return "Bodyweight"
        case .assistedBodyweight: return "Assisted (−)"
        case .addedBodyweight: return "Added weight (+)"
        case .unknown: return "Unknown"
        }
    }

    public var shortLabel: String {
        switch self {
        case .external: return "Weight"
        case .bodyweight: return "Bodyweight"
        case .assistedBodyweight: return "Assisted"
        case .addedBodyweight: return "Weighted"
        case .unknown: return "—"
        }
    }
}

/// Optional "reps left in the tank" (RIR). Deliberately not surfaced to the
/// user as the jargon "RIR" — see `question` for the friendly prompt.
public enum RepsLeft: String, DisplayableOption {
    case unknown
    case threePlus
    case two
    case one
    case zero
    case failed

    public static let question = "How many more clean reps were left?"

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .threePlus: return "3+"
        case .two: return "2"
        case .one: return "1"
        case .zero: return "0"
        case .failed: return "Failed"
        }
    }
}

/// Subjective form/technique quality for a set.
public enum FormQuality: String, DisplayableOption {
    case unknown
    case good     // good / controlled
    case okay
    case shaky
    case bad
    case notSure

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .good: return "Good / controlled"
        case .okay: return "Okay"
        case .shaky: return "Shaky"
        case .bad: return "Bad"
        case .notSure: return "Not sure"
        }
    }
}

/// What limited the set / why progress stopped. Very useful for later analysis.
public enum Limiter: String, DisplayableOption {
    case none
    case muscleFailed
    case gripFailed
    case breathCardio
    case formBroke
    case pain
    case balance
    case fear
    case equipment
    case other
    case unknown

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .muscleFailed: return "Muscle failed"
        case .gripFailed: return "Grip failed"
        case .breathCardio: return "Breath / cardio failed"
        case .formBroke: return "Form broke"
        case .pain: return "Pain / discomfort"
        case .balance: return "Balance / coordination"
        case .fear: return "Fear / uncertainty"
        case .equipment: return "Equipment issue"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }
}

/// Pain / discomfort severity. Tracking only — never medical advice.
public enum PainSeverity: String, DisplayableOption {
    case none
    case mild
    case moderate
    case strong
    case stopExercise

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        case .stopExercise: return "Had to stop"
        }
    }
}

public enum PainLocation: String, DisplayableOption {
    case shoulder
    case elbow
    case wrist
    case lowerBack
    case upperBack
    case hip
    case knee
    case ankle
    case neck
    case chest
    case other

    public var displayName: String {
        switch self {
        case .shoulder: return "Shoulder"
        case .elbow: return "Elbow"
        case .wrist: return "Wrist"
        case .lowerBack: return "Lower back"
        case .upperBack: return "Upper back"
        case .hip: return "Hip"
        case .knee: return "Knee"
        case .ankle: return "Ankle"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .other: return "Other"
        }
    }
}

/// Provenance of a set / record. Helps distinguish live data from backfill.
public enum RecordSource: String, DisplayableOption {
    case manual
    case imported
    case edited
    case backfilled

    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .imported: return "Imported"
        case .edited: return "Edited"
        case .backfilled: return "Backfilled"
        }
    }
}

// MARK: - Session-level enums

public enum WorkoutGoal: String, DisplayableOption {
    case strength
    case hypertrophy
    case technique
    case lightRecovery
    case mixed
    case notSure

    public var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Muscle size"
        case .technique: return "Technique"
        case .lightRecovery: return "Light / recovery"
        case .mixed: return "Mixed"
        case .notSure: return "Not sure"
        }
    }
}

public enum Soreness: String, DisplayableOption {
    case unknown
    case none
    case mild
    case moderate
    case strong
    case veryStrong

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        case .veryStrong: return "Very strong"
        }
    }
}

public enum PainToday: String, DisplayableOption {
    case no
    case yesOkay
    case yesModified
    case yesStopped
    case unknown

    public var displayName: String {
        switch self {
        case .no: return "No"
        case .yesOkay: return "Yes, but okay to train"
        case .yesModified: return "Yes, I modified exercises"
        case .yesStopped: return "Yes, I stopped/avoided something"
        case .unknown: return "Unknown"
        }
    }
}

public enum SleepQuality: String, DisplayableOption {
    case unknown
    case terrible
    case bad
    case okay
    case good
    case excellent

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .terrible: return "Terrible"
        case .bad: return "Bad"
        case .okay: return "Okay"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

public enum FoodTiming: String, DisplayableOption {
    case unknown
    case fasted
    case ateRecently
    case normal
    case heavyMeal

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .fasted: return "Fasted"
        case .ateRecently: return "Ate recently"
        case .normal: return "Normal"
        case .heavyMeal: return "Heavy meal before"
        }
    }
}

public enum Caffeine: String, DisplayableOption {
    case unknown
    case none
    case coffee
    case preWorkout
    case other

    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .none: return "None"
        case .coffee: return "Coffee"
        case .preWorkout: return "Pre-workout"
        case .other: return "Other"
        }
    }
}

public enum WorkoutLocation: String, DisplayableOption {
    case gym
    case home
    case outdoor
    case travel
    case other
    case unknown

    public var displayName: String {
        switch self {
        case .gym: return "Gym"
        case .home: return "Home"
        case .outdoor: return "Outdoor"
        case .travel: return "Travel"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Exercise library enums

public enum ExerciseCategory: String, DisplayableOption {
    case chest
    case back
    case biceps
    case triceps
    case shoulders
    case legs
    case core
    case cardio
    case mobility
    case fullBody
    case other

    public var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .shoulders: return "Shoulders"
        case .legs: return "Legs"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        case .fullBody: return "Full body"
        case .other: return "Other"
        }
    }
}

public enum Equipment: String, DisplayableOption {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case assistedMachine
    case kettlebell
    case resistanceBand
    case bench
    case other

    public var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .assistedMachine: return "Assisted machine"
        case .kettlebell: return "Kettlebell"
        case .resistanceBand: return "Resistance band"
        case .bench: return "Bench"
        case .other: return "Other"
        }
    }
}

public enum MovementPattern: String, DisplayableOption {
    case horizontalPush
    case verticalPush
    case horizontalPull
    case verticalPull
    case squat
    case hinge
    case lunge
    case curl
    case extension_   // "extension" is a Swift keyword; raw value stays "extension"
    case carry
    case core
    case isolation
    case other

    public init?(rawValue: String) {
        switch rawValue {
        case "horizontalPush": self = .horizontalPush
        case "verticalPush": self = .verticalPush
        case "horizontalPull": self = .horizontalPull
        case "verticalPull": self = .verticalPull
        case "squat": self = .squat
        case "hinge": self = .hinge
        case "lunge": self = .lunge
        case "curl": self = .curl
        case "extension": self = .extension_
        case "carry": self = .carry
        case "core": self = .core
        case "isolation": self = .isolation
        case "other": self = .other
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .horizontalPush: return "horizontalPush"
        case .verticalPush: return "verticalPush"
        case .horizontalPull: return "horizontalPull"
        case .verticalPull: return "verticalPull"
        case .squat: return "squat"
        case .hinge: return "hinge"
        case .lunge: return "lunge"
        case .curl: return "curl"
        case .extension_: return "extension"
        case .carry: return "carry"
        case .core: return "core"
        case .isolation: return "isolation"
        case .other: return "other"
        }
    }

    public var displayName: String {
        switch self {
        case .horizontalPush: return "Horizontal push"
        case .verticalPush: return "Vertical push"
        case .horizontalPull: return "Horizontal pull"
        case .verticalPull: return "Vertical pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .curl: return "Curl"
        case .extension_: return "Extension"
        case .carry: return "Carry"
        case .core: return "Core"
        case .isolation: return "Isolation"
        case .other: return "Other"
        }
    }
}

/// Muscle groups for primary/secondary tagging. Stored as arrays of raw values
/// on `Exercise` for CloudKit friendliness.
public enum MuscleGroup: String, DisplayableOption {
    case chest
    case upperBack
    case lats
    case lowerBack
    case traps
    case frontDelts
    case sideDelts
    case rearDelts
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case quads
    case hamstrings
    case glutes
    case calves
    case neck
    case fullBody
    case other

    public var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .upperBack: return "Upper back"
        case .lats: return "Lats"
        case .lowerBack: return "Lower back"
        case .traps: return "Traps"
        case .frontDelts: return "Front delts"
        case .sideDelts: return "Side delts"
        case .rearDelts: return "Rear delts"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .neck: return "Neck"
        case .fullBody: return "Full body"
        case .other: return "Other"
        }
    }
}

// MARK: - Journal

public enum JournalEntryType: String, DisplayableOption {
    case workoutNote
    case exerciseNote
    case setNote
    case correction

    public var displayName: String {
        switch self {
        case .workoutNote: return "Workout note"
        case .exerciseNote: return "Exercise note"
        case .setNote: return "Set note"
        case .correction: return "Correction"
        }
    }
}

// MARK: - Provenance for health/imported values

public enum DataSource: String, DisplayableOption {
    case manual
    case healthImport
    case unknown

    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .healthImport: return "Apple Health"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - 0–5 subjective scales

/// Shared helpers for the two 0–5 scales (effort per set, energy per session).
/// Stored as `Int?` on the models; these provide the friendly labels.
public enum EffortScale {
    public static let range = 0...5
    public static let question = "How hard was that set?"

    public static func label(for value: Int) -> String {
        switch value {
        case 0: return "Warm-up / very easy"
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Hard"
        case 4: return "Very hard"
        case 5: return "Maximal / almost failed"
        default: return "—"
        }
    }

    public static func shortLabel(for value: Int) -> String {
        switch value {
        case 0: return "Warm-up"
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Hard"
        case 4: return "Very hard"
        case 5: return "Maximal"
        default: return "—"
        }
    }
}

public enum EnergyScale {
    public static let range = 0...5
    public static let question = "How ready do you feel to train now?"

    public static func label(for value: Int) -> String {
        switch value {
        case 0: return "Exhausted"
        case 1: return "Low"
        case 2: return "Below normal"
        case 3: return "Normal"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return "—"
        }
    }
}

public enum StressScale {
    public static let range = 0...5
    public static let question = "How stressed do you feel today?"

    public static func label(for value: Int) -> String {
        switch value {
        case 0: return "None"
        case 1: return "Very low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Very high"
        default: return "—"
        }
    }
}
