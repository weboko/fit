import SwiftUI
import SwiftData
import HealthKit
import Foundation

/// Full Apple Health import browser: pick a time window, import workouts, body
/// weight and sleep, and review what has already been imported. Consumed by
/// Settings and (optionally) HistoryJournal via a `NavigationLink`.
///
/// Everything is guarded for the simulator / no-Health / permission-denied
/// cases — the screen still renders and explains why imports are unavailable.
struct ImportHealthDataView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service = HealthImportService()

    @State private var lookback: ImportLookback = .ninetyDays

    @Query(sort: \HealthWorkout.startTime, order: .reverse)
    private var importedWorkouts: [HealthWorkout]

    @Query(sort: \BodyWeightEntry.timestamp, order: .reverse)
    private var bodyWeightEntries: [BodyWeightEntry]

    @Query(sort: \SleepEntry.date, order: .reverse)
    private var sleepEntries: [SleepEntry]

    init() {}

    private var importedBodyWeight: [BodyWeightEntry] {
        bodyWeightEntries.filter { $0.source == .healthImport }
    }
    private var importedSleep: [SleepEntry] {
        sleepEntries.filter { $0.source == .healthImport }
    }

    var body: some View {
        List {
            if !HealthImportService.isAvailable {
                unavailableSection
            } else {
                authorizationSection
                if service.canAttemptImport {
                    controlsSection
                }
            }
            importedWorkoutsSection
            bodyWeightSection
            sleepSection
        }
        .navigationTitle("Import from Health")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if service.isWorking {
                ProgressView("Importing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear { service.refreshAuthorizationStatus() }
    }

    // MARK: Sections

    private var unavailableSection: some View {
        Section {
            Label("Apple Health is not available on this device.",
                  systemImage: "heart.slash")
                .foregroundStyle(.secondary)
        }
    }

    private var authorizationSection: some View {
        Section {
            HStack {
                Text(service.authorizationStatusDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if service.authorizationStatus == .notDetermined {
                Button {
                    Task { await service.requestAuthorization() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.text.square")
                }
                .disabled(service.isWorking)
            }
        } header: {
            Text("Permission")
        } footer: {
            if let message = service.lastResultMessage {
                Text(message)
            }
        }
    }

    private var controlsSection: some View {
        Section {
            Picker("Look back", selection: $lookback) {
                ForEach(ImportLookback.allCases) { option in
                    Text(option.label).tag(option)
                }
            }

            Button {
                Task { await service.importRecentWorkouts(into: context, since: lookback.startDate) }
            } label: {
                Label("Import workouts", systemImage: "figure.strengthtraining.traditional")
            }
            .disabled(service.isWorking)

            Button {
                Task { await service.importBodyWeight(into: context, since: lookback.startDate) }
            } label: {
                Label("Import body weight", systemImage: "scalemass")
            }
            .disabled(service.isWorking)

            Button {
                Task { await service.importSleep(into: context, since: lookback.startDate) }
            } label: {
                Label("Import sleep", systemImage: "bed.double")
            }
            .disabled(service.isWorking)

            Button {
                Task {
                    await service.importRecentWorkouts(into: context, since: lookback.startDate)
                    await service.importBodyWeight(into: context, since: lookback.startDate)
                    await service.importSleep(into: context, since: lookback.startDate)
                }
            } label: {
                Label("Import everything", systemImage: "square.and.arrow.down.on.square")
            }
            .disabled(service.isWorking)
        } header: {
            Text("Import")
        } footer: {
            Text("Only new records are added. Existing imported records and anything you entered by hand are left untouched.")
        }
    }

    @ViewBuilder
    private var importedWorkoutsSection: some View {
        Section {
            if importedWorkouts.isEmpty {
                Text("No imported workouts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(importedWorkouts) { hw in
                    HealthWorkoutSummaryRow(workout: hw)
                        .padding(.vertical, Theme.Spacing.xs)
                }
            }
        } header: {
            HStack {
                Text("Workouts")
                Spacer()
                if !importedWorkouts.isEmpty {
                    Text("\(importedWorkouts.count)").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var bodyWeightSection: some View {
        Section {
            if importedBodyWeight.isEmpty {
                Text("No imported body-weight entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(importedBodyWeight) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(Format.weight(entry.weightKg))
                                .font(.headline)
                            Text(entry.timestamp.formatted(.dateTime.weekday().month().day().hour().minute()))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SourceBadge(text: "Apple Health", systemImage: "heart.fill", tint: .pink)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        } header: {
            HStack {
                Text("Body weight")
                Spacer()
                if !importedBodyWeight.isEmpty {
                    Text("\(importedBodyWeight.count)").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var sleepSection: some View {
        Section {
            if importedSleep.isEmpty {
                Text("No imported sleep records yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(importedSleep) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(Format.durationCompact(entry.durationSeconds))
                                .font(.headline)
                            Text(entry.date.formatted(.dateTime.weekday().month().day()))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SourceBadge(text: "Apple Health", systemImage: "heart.fill", tint: .pink)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        } header: {
            HStack {
                Text("Sleep")
                Spacer()
                if !importedSleep.isEmpty {
                    Text("\(importedSleep.count)").foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImportHealthDataView()
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
