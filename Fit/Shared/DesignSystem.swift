import SwiftUI

/// Lightweight design tokens so the gym-facing UI stays consistent and the
/// touch targets stay large enough for one-handed, tired use (spec §6, §14.1).
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Size {
        /// Minimum tappable control height for gym use.
        static let controlHeight: CGFloat = 48
        static let bigControlHeight: CGFloat = 56
        static let cornerRadius: CGFloat = 12
    }

    enum Palette {
        static let accent = Color.accentColor
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let subtle = Color(.tertiarySystemFill)

        /// Colour ramp for the 0–5 effort/intensity scales.
        static func intensity(_ value: Int) -> Color {
            switch value {
            case 0: return .gray
            case 1: return .green
            case 2: return .mint
            case 3: return .yellow
            case 4: return .orange
            case 5: return .red
            default: return .gray
            }
        }
    }
}

extension View {
    /// Standard card styling used across modules.
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
    }
}
