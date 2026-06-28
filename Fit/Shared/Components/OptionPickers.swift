import SwiftUI

/// A single selectable chip.
struct OptionChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .frame(minHeight: 40)
                .background(isSelected ? tint.opacity(0.18) : Theme.Palette.subtle)
                .foregroundStyle(isSelected ? tint : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isSelected ? tint : .clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A wrapping group of chips for choosing one value of a `DisplayableOption`
/// enum. Use for fast, low-typing entry of form/limiter/pain/etc.
struct OptionChipGroup<T: DisplayableOption>: View {
    let title: String?
    @Binding var selection: T?
    var allowsDeselect: Bool = true
    var tint: Color = .accentColor

    init(_ title: String? = nil, selection: Binding<T?>, allowsDeselect: Bool = true, tint: Color = .accentColor) {
        self.title = title
        self._selection = selection
        self.allowsDeselect = allowsDeselect
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            FlowLayout {
                ForEach(Array(T.allCases)) { option in
                    OptionChip(title: option.displayName,
                               isSelected: selection == option,
                               tint: tint) {
                        if selection == option, allowsDeselect {
                            selection = nil
                        } else {
                            selection = option
                        }
                    }
                }
            }
        }
    }
}

/// Non-optional variant for enums that always have a value (e.g. weight mode).
struct OptionChipGroupRequired<T: DisplayableOption>: View {
    let title: String?
    @Binding var selection: T
    var tint: Color = .accentColor

    init(_ title: String? = nil, selection: Binding<T>, tint: Color = .accentColor) {
        self.title = title
        self._selection = selection
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            FlowLayout {
                ForEach(Array(T.allCases)) { option in
                    OptionChip(title: option.displayName,
                               isSelected: selection == option,
                               tint: tint) {
                        selection = option
                    }
                }
            }
        }
    }
}

/// A compact menu picker for a `DisplayableOption`, good for Form rows where
/// space is tight.
struct OptionMenuPicker<T: DisplayableOption>: View {
    let title: String
    @Binding var selection: T?
    var noneLabel: String = "Not set"

    var body: some View {
        Picker(title, selection: $selection) {
            Text(noneLabel).tag(Optional<T>.none)
            ForEach(Array(T.allCases)) { option in
                Text(option.displayName).tag(Optional(option))
            }
        }
    }
}
