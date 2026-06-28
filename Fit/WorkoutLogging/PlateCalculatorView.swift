import SwiftUI

/// Plate calculator (spec F8): given a target barbell load, the bar weight and
/// the available plates, shows the per-side plate breakdown. Pure deterministic
/// utility — reachable from set entry or usable standalone.
///
/// Bar weight and the enabled plate set persist in `UserDefaults` so the user's
/// equipment is remembered between sessions.
struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    /// Bar-weight options offered (kg). 0 covers fixed/cable setups.
    private static let barOptions: [Double] = [20, 15, 10, 7.5, 0]
    /// The standard plate set offered as toggleable chips (kg, per side).
    private static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    @State private var targetKg: Double?
    @AppStorage(AppSettingsKeys.barWeightKg) private var barWeightKg: Double = 20
    @AppStorage(AppSettingsKeys.enabledPlatesCSV) private var enabledPlatesCSV: String =
        PlateCalculatorView.standardPlates.map { String($0) }.joined(separator: ",")

    /// - Parameter targetKg: optional pre-fill for the target load (e.g. the
    ///   current set's weight when opened from set entry).
    init(targetKg: Double? = nil) {
        _targetKg = State(initialValue: targetKg)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    targetCard
                    barCard
                    platesCard
                    resultCard
                }
                .padding(Theme.Spacing.l)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Inputs

    private var targetCard: some View {
        SectionCard("Target load", systemImage: "scalemass") {
            WeightStepperField(weightKg: $targetKg)
        }
    }

    private var barCard: some View {
        SectionCard("Bar weight", systemImage: "minus") {
            Picker("Bar weight", selection: $barWeightKg) {
                ForEach(Self.barOptions, id: \.self) { bar in
                    Text(bar > 0 ? Format.weight(bar) : "None")
                        .tag(bar)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var platesCard: some View {
        SectionCard("Available plates", systemImage: "circle.grid.2x2") {
            FlowLayout {
                ForEach(Self.standardPlates, id: \.self) { plate in
                    OptionChip(title: Format.weight(plate, includeSymbol: false),
                               isSelected: enabledPlates.contains(plate)) {
                        toggle(plate)
                    }
                }
            }
            Text("kg per side, unlimited count")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Output

    @ViewBuilder
    private var resultCard: some View {
        let result = PlateMath.solve(targetKg: targetKg ?? 0,
                                     barKg: barWeightKg,
                                     available: Array(enabledPlates))
        SectionCard("Per side", systemImage: "dumbbell") {
            if (targetKg ?? 0) <= barWeightKg {
                Text("Just the bar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if result.perSide.isEmpty {
                Text("No plates can be loaded — enable some plate sizes above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(result.perSide) { group in
                        plateRow(group)
                    }
                }
            }

            Divider()

            DetailRow(label: "Per side",
                      value: Format.weight(result.placedPerSideKg))
            DetailRow(label: "Total bar load",
                      value: Format.weight(result.achievableKg))

            if !result.isExact {
                Text("Can't match exactly — closest is \(Format.weight(result.achievableKg)), \(Format.weight(2 * result.remainderKg)) short.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func plateRow(_ group: PlateGroup) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Text("\(group.count) × \(Format.weight(group.plate))")
                .font(.subheadline.weight(.semibold))
                .frame(width: 120, alignment: .leading)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(0..<group.count, id: \.self) { _ in
                    plateCapsule(group.plate)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// A simple visual whose height scales with the plate size, relative to the
    /// largest plate in the standard set.
    private func plateCapsule(_ plate: Double) -> some View {
        let largest = Self.standardPlates.max() ?? plate
        let fraction = largest > 0 ? plate / largest : 1
        let height = 18 + CGFloat(fraction) * 26
        return Capsule()
            .fill(Theme.Palette.accent.opacity(0.7))
            .frame(width: 10, height: height)
    }

    // MARK: - Enabled plates persistence

    private var enabledPlates: Set<Double> {
        Set(enabledPlatesCSV
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) })
    }

    private func toggle(_ plate: Double) {
        var set = enabledPlates
        if set.contains(plate) {
            set.remove(plate)
        } else {
            set.insert(plate)
        }
        // Persist in a stable, descending order.
        enabledPlatesCSV = set.sorted(by: >).map { String($0) }.joined(separator: ",")
    }
}

#Preview {
    PlateCalculatorView(targetKg: 102.5)
}
