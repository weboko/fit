import Foundation

/// Display unit for weights. Internally everything is stored and exported in kg
/// (spec §22); this only affects what the user sees and types.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }
    var symbol: String { self == .kg ? "kg" : "lb" }
    var displayName: String { self == .kg ? "Kilograms (kg)" : "Pounds (lb)" }

    /// Conversion factor from kg to this unit.
    var perKg: Double { self == .kg ? 1.0 : 2.2046226218 }

    func fromKg(_ kg: Double) -> Double { kg * perKg }
    func toKg(_ value: Double) -> Double { value / perKg }

    /// The increments offered by the quick +/- buttons, expressed in this unit.
    var quickIncrements: [Double] { self == .kg ? [1, 2.5, 5] : [2.5, 5, 10] }
}

/// Centralised formatting so weights, durations and dates look the same
/// everywhere. Storage stays in kg; display honours the user's unit preference.
enum Format {

    static var weightUnit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: AppSettingsKeys.weightUnit) ?? "kg") ?? .kg
    }

    /// Formats a kg value for display in the user's chosen unit, with the symbol.
    static func weight(_ kg: Double?, unit: WeightUnit? = nil, includeSymbol: Bool = true) -> String {
        guard let kg else { return "—" }
        let u = unit ?? weightUnit
        let value = u.fromKg(kg)
        let number = decimal(value)
        return includeSymbol ? "\(number) \(u.symbol)" : number
    }

    /// A short, friendly number: drops trailing ".0", keeps up to 2 decimals.
    static func decimal(_ value: Double, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Describes one set's load+reps compactly, e.g. "80 kg × 6" or "BW −20 × 5".
    static func setSummary(_ set: WorkoutSet) -> String {
        let repsPart = set.reps.map { "× \($0)" } ?? ""
        let loadPart: String
        switch set.weightMode {
        case .external:
            loadPart = weight(set.weightKg)
        case .bodyweight:
            loadPart = "BW"
        case .assistedBodyweight:
            let assist = set.assistanceKg.map { " −\(weight($0, includeSymbol: false))" } ?? ""
            loadPart = "BW\(assist)"
        case .addedBodyweight:
            let added = set.addedWeightKg.map { " +\(weight($0, includeSymbol: false))" } ?? ""
            loadPart = "BW\(added)"
        case .unknown:
            loadPart = set.weightKg.map { weight($0) } ?? "—"
        }
        return [loadPart, repsPart].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Compact duration like "1h 5m" for summaries.
    static func durationCompact(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func relativeDay(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }
}
