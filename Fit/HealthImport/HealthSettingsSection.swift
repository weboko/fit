import SwiftUI
import SwiftData
import HealthKit
import Foundation

/// Settings block that shows Apple Health availability + authorization state and
/// offers buttons to request access and to import recent Health data. Designed
/// to live inside the Settings `Form`/`List` (consumed by the Settings module).
///
/// Guards everything: if Health is unavailable or permission has not been
/// granted, it explains the situation rather than failing.
struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service = HealthImportService()

    /// How far back the "Import recent" buttons look.
    @State private var lookback: ImportLookback = .ninetyDays

    init() {}

    // Rendered as a group of rows (not its own `Section`) so it can be embedded
    // inside the Settings `Form`'s own Apple Health section without nesting.
    var body: some View {
        Group {
            statusRow

            if HealthImportService.isAvailable {
                if service.authorizationStatus == .notDetermined {
                    Button {
                        Task { await service.requestAuthorization() }
                    } label: {
                        Label("Connect Apple Health", systemImage: "heart.text.square")
                    }
                    .disabled(service.isWorking)
                } else {
                    Picker("Look back", selection: $lookback) {
                        ForEach(ImportLookback.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Button {
                        Task {
                            let since = lookback.startDate
                            await service.importRecentWorkouts(into: context, since: since)
                        }
                    } label: {
                        Label("Import recent workouts", systemImage: "figure.run.square.stack")
                    }
                    .disabled(service.isWorking)

                    Button {
                        Task {
                            let since = lookback.startDate
                            await service.importBodyWeight(into: context, since: since)
                            await service.importSleep(into: context, since: since)
                        }
                    } label: {
                        Label("Import body weight & sleep", systemImage: "bed.double")
                    }
                    .disabled(service.isWorking)
                }
            }

            if let message = service.lastResultMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { service.refreshAuthorizationStatus() }
    }

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(HealthImportService.isAvailable ? "Status" : "Unavailable")
                    .font(.subheadline.weight(.medium))
                Text(service.authorizationStatusDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.m)
            if service.isWorking {
                ProgressView()
            } else {
                statusBadge
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !HealthImportService.isAvailable {
            SourceBadge(text: "Off", systemImage: "heart.slash", tint: .secondary)
        } else {
            switch service.authorizationStatus {
            case .sharingAuthorized:
                SourceBadge(text: "Connected", systemImage: "heart.fill", tint: .green)
            case .sharingDenied:
                SourceBadge(text: "Denied", systemImage: "heart.slash", tint: .orange)
            case .notDetermined:
                SourceBadge(text: "Not set", systemImage: "heart", tint: .secondary)
            @unknown default:
                SourceBadge(text: "Unknown", systemImage: "questionmark", tint: .secondary)
            }
        }
    }
}

/// Shared look-back window options for Health imports.
enum ImportLookback: String, CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case oneYear
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyDays: return "30 days"
        case .ninetyDays: return "90 days"
        case .oneYear: return "1 year"
        case .all: return "All time"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .thirtyDays: return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .ninetyDays: return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all: return Date.distantPast
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            Section("Apple Health") {
                HealthSettingsSection()
            }
        }
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
