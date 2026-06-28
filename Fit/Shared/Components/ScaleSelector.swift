import SwiftUI

/// Large 0–5 segmented selector used for effort (per set), energy and stress
/// (per session). Optional binding so "not entered" is a valid state.
struct ScaleSelector: View {
    let title: String?
    let range: ClosedRange<Int>
    @Binding var value: Int?
    /// Friendly label for the currently selected value (e.g. EffortScale.label).
    var labelProvider: (Int) -> String
    var coloredByValue: Bool = true

    init(
        title: String? = nil,
        range: ClosedRange<Int> = 0...5,
        value: Binding<Int?>,
        labelProvider: @escaping (Int) -> String,
        coloredByValue: Bool = true
    ) {
        self.title = title
        self.range = range
        self._value = value
        self.labelProvider = labelProvider
        self.coloredByValue = coloredByValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(range), id: \.self) { i in
                    Button {
                        value = (value == i) ? nil : i
                    } label: {
                        Text("\(i)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                            .background(background(for: i))
                            .foregroundStyle(value == i ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(value.map(labelProvider) ?? "Not entered")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .animation(.none, value: value)
        }
    }

    private func background(for i: Int) -> Color {
        if value == i {
            return coloredByValue ? Theme.Palette.intensity(i) : Color.accentColor
        }
        return Theme.Palette.subtle
    }
}
