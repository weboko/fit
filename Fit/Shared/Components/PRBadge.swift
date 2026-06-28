import SwiftUI

/// A compact gold capsule flagging that a set holds one or more personal
/// records. Styled like `SourceBadge` but accented for celebration. Renders
/// nothing when `kinds` is empty, so callers can place it unconditionally.
struct PRBadge: View {
    let kinds: Set<PRKind>

    init(kinds: Set<PRKind>) {
        self.kinds = kinds
    }

    private let tint: Color = .yellow

    /// Stable ordering of the kinds this badge represents.
    private var orderedKinds: [PRKind] {
        PRKind.allCases.filter { kinds.contains($0) }
    }

    var body: some View {
        if !kinds.isEmpty {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "trophy.fill")
                Text("PR")
                    .fontWeight(.semibold)
                ForEach(orderedKinds) { kind in
                    Image(systemName: kind.systemImage)
                }
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.2))
            .foregroundStyle(tint)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    private var accessibilityText: String {
        let names = orderedKinds.map(\.displayName)
        guard !names.isEmpty else { return "Personal record" }
        return "Personal record: " + names.joined(separator: ", ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
        PRBadge(kinds: [.load])
        PRBadge(kinds: [.load, .estimatedOneRepMax])
        PRBadge(kinds: Set(PRKind.allCases))
        PRBadge(kinds: [])
    }
    .padding()
}
