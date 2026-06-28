import SwiftUI

/// A titled card container for grouping content outside of `Form`/`List`.
struct SectionCard<Content: View>: View {
    let title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let title {
                Label {
                    Text(title).font(.headline)
                } icon: {
                    if let systemImage { Image(systemName: systemImage) }
                }
                .labelStyle(TitleAndOptionalIconLabelStyle(hasIcon: systemImage != nil))
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct TitleAndOptionalIconLabelStyle: LabelStyle {
    let hasIcon: Bool
    func makeBody(configuration: Configuration) -> some View {
        if hasIcon {
            HStack(spacing: Theme.Spacing.s) {
                configuration.icon.foregroundStyle(.secondary)
                configuration.title
            }
        } else {
            configuration.title
        }
    }
}

/// A small labelled value tile, used in stat grids.
struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(tint)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Friendly empty-state placeholder.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// A read-only key/value row for detail screens.
struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.m)
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A compact purple capsule flagging a set's superset / circuit group (F10),
/// e.g. "Superset A". Renders nothing when the set has no group, so callers can
/// place it unconditionally. Styled like `SourceBadge`/`PRBadge`.
struct SupersetBadge: View {
    let group: Int?
    var compact: Bool = false

    private let tint: Color = .purple

    var body: some View {
        if let label = group.flatMap(SupersetGroup.letter(for:)) {
            Label {
                Text(compact ? label : "Superset \(label)")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Superset \(label)")
        }
    }
}

/// A pill that flags imported/backfilled provenance.
struct SourceBadge: View {
    let text: String
    var systemImage: String = "arrow.down.circle"
    var tint: Color = .secondary

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}
