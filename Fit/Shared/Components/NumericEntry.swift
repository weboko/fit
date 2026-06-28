import SwiftUI

/// Fast weight entry: big value, +/- quick increments, recent values, and a
/// numeric keypad. Stores kg; displays/edits in the user's unit (spec §7.2).
struct WeightStepperField: View {
    @Binding var weightKg: Double?
    /// Recent weights (in kg) offered as one-tap buttons, newest first.
    var recentKg: [Double] = []
    var unit: WeightUnit = Format.weightUnit

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.bigControlHeight)
                    .background(Theme.Palette.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
                    .accessibilityLabel("Weight in \(unit.symbol)")
                Text(unit.symbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(unit.quickIncrements.reversed(), id: \.self) { inc in
                    incrementButton(-inc)
                }
                ForEach(unit.quickIncrements, id: \.self) { inc in
                    incrementButton(inc)
                }
            }

            if !recentKg.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(Array(recentKg.prefix(8).enumerated()), id: \.offset) { _, kg in
                            Button {
                                weightKg = kg
                                syncTextFromValue()
                            } label: {
                                Text(Format.weight(kg, unit: unit))
                                    .font(.subheadline)
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .frame(minHeight: 36)
                                    .background(Theme.Palette.subtle)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear(perform: syncTextFromValue)
        .onChange(of: text) { _, newValue in
            let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
            if cleaned.isEmpty {
                if weightKg != nil { weightKg = nil }
            } else if let entered = Double(cleaned) {
                let kg = unit.toKg(entered)
                if weightKg != kg { weightKg = kg }
            }
        }
        .onChange(of: weightKg) { _, _ in
            // Reflect button/external changes without fighting the keyboard.
            let parsed = Double(text.replacingOccurrences(of: ",", with: "."))
            if parsed != weightKg.map({ unit.fromKg($0) }) {
                syncTextFromValue()
            }
        }
    }

    private func incrementButton(_ deltaInUnit: Double) -> some View {
        Button {
            let currentUnitValue = weightKg.map { unit.fromKg($0) } ?? 0
            let next = max(0, currentUnitValue + deltaInUnit)
            weightKg = unit.toKg(next)
            syncTextFromValue()
        } label: {
            Text(deltaInUnit > 0 ? "+\(Format.decimal(deltaInUnit))" : "\(Format.decimal(deltaInUnit))")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                .background(deltaInUnit > 0 ? Color.accentColor.opacity(0.15) : Theme.Palette.subtle)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(deltaInUnit > 0
            ? "Add \(Format.decimal(deltaInUnit)) \(unit.symbol)"
            : "Subtract \(Format.decimal(abs(deltaInUnit))) \(unit.symbol)")
    }

    private func syncTextFromValue() {
        text = weightKg.map { Format.decimal(unit.fromKg($0)) } ?? ""
    }
}

/// Fast reps entry: stepper, common values, numeric keypad (spec §7.3).
struct RepsStepperField: View {
    @Binding var reps: Int?
    var quickValues: [Int] = [5, 6, 8, 10, 12]

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                stepButton("−", accessibilityLabel: "Decrease reps") { adjust(-1) }
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.bigControlHeight)
                    .background(Theme.Palette.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
                    .accessibilityLabel("Reps")
                stepButton("+", accessibilityLabel: "Increase reps") { adjust(1) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(quickValues, id: \.self) { v in
                        Button {
                            reps = v
                            text = String(v)
                        } label: {
                            Text("\(v)")
                                .font(.subheadline)
                                .padding(.horizontal, Theme.Spacing.m)
                                .frame(minHeight: 36)
                                .background(reps == v ? Color.accentColor.opacity(0.18) : Theme.Palette.subtle)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { text = reps.map(String.init) ?? "" }
        .onChange(of: text) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            if digits != newValue { text = digits; return }
            if digits.isEmpty { if reps != nil { reps = nil } }
            else if let v = Int(digits), reps != v { reps = v }
        }
        .onChange(of: reps) { _, newValue in
            if Int(text) != newValue { text = newValue.map(String.init) ?? "" }
        }
    }

    private func adjust(_ delta: Int) {
        let next = max(0, (reps ?? 0) + delta)
        reps = next
        text = String(next)
    }

    private func stepButton(_ symbol: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.title2.weight(.bold))
                .frame(width: 56, height: Theme.Size.bigControlHeight)
                .background(Theme.Palette.subtle)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
