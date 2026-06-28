import SwiftUI
import SwiftData

/// The Settings tab entry point (spec §22, §23, §24).
///
/// A `Form`-based screen that gathers app-level preferences:
/// - weight display unit
/// - a best-effort iCloud/sync indicator (the app is local-first)
/// - Apple Health permissions + import (delegated to the HealthImport module)
/// - default export options
/// - data management (counts / seed / delete-all) and an About screen
///
/// Storage stays in kg everywhere; the unit choice only affects display.
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    /// Weight display unit. Stored as the `WeightUnit` rawValue ("kg"/"lb").
    @AppStorage(AppSettingsKeys.weightUnit) private var weightUnitRaw: String = WeightUnit.kg.rawValue

    /// Whether a freshly-opened Export should include Apple Health data by default.
    @AppStorage(AppSettingsKeys.defaultExportIncludesHealth) private var exportIncludesHealth: Bool = true

    /// Whether a freshly-opened Export should include journal entries by default.
    @AppStorage(AppSettingsKeys.defaultExportIncludesJournal) private var exportIncludesJournal: Bool = true

    /// Whether a local notification fires when the between-sets rest timer ends.
    /// Opt-in: also requires the system notification permission (F5).
    @AppStorage(AppSettingsKeys.restAlertsEnabled) private var restAlertsEnabled: Bool = false

    /// Default rest length in seconds, shared with the active-workout timer.
    /// `0`/unset is treated as the 90s fallback for display and selection (F5/F19).
    @AppStorage(AppSettingsKeys.defaultRestSeconds) private var defaultRestSeconds: Int = 0

    /// Max heart rate (bpm) used for HR-zone boundaries at Health import (F13).
    /// `0`/unset is treated as the 190 bpm fallback for display and computation.
    @AppStorage(AppSettingsKeys.maxHeartRateBpm) private var maxHeartRateBpm: Int = 0

    /// Shown when the user enables alerts but notification permission is denied.
    @State private var restPermissionDenied = false

    /// The rest durations offered by the picker, in seconds.
    private let restDurationOptions = [30, 45, 60, 75, 90, 120, 150, 180]

    /// Picker binding that maps `0`/unset onto the 90s fallback so the control
    /// always shows a concrete, valid selection.
    private var restSecondsSelection: Binding<Int> {
        Binding(
            get: { defaultRestSeconds > 0 ? defaultRestSeconds : 90 },
            set: { defaultRestSeconds = $0 }
        )
    }

    /// Stepper binding that maps `0`/unset onto the 190 bpm fallback so the
    /// control always shows a concrete, valid max heart rate (F13).
    private var maxHeartRateSelection: Binding<Int> {
        Binding(
            get: { maxHeartRateBpm > 0 ? maxHeartRateBpm : HeartRateZones.defaultMaxBpm },
            set: { maxHeartRateBpm = $0 }
        )
    }

    private var selectedUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    /// Best-effort iCloud availability. `ubiquityIdentityToken` is non-nil when
    /// the user is signed into iCloud on this device.
    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                restSection
                syncSection
                healthSection
                trackingSection
                exportSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Picker("Weight unit", selection: selectedUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
        } header: {
            Text("Units")
        } footer: {
            Text("Weights are always stored and exported in kilograms. This only changes what you see and type.")
        }
    }

    // MARK: - Rest (timer alerts + default duration) — F5 / F19

    private var restSection: some View {
        Section {
            Toggle("Rest timer alerts", isOn: $restAlertsEnabled)
                .onChange(of: restAlertsEnabled) { _, isOn in
                    if isOn { confirmNotificationPermission() }
                }
            Picker("Default rest", selection: restSecondsSelection) {
                ForEach(restDurationOptions, id: \.self) { seconds in
                    Text(Format.duration(TimeInterval(seconds))).tag(seconds)
                }
            }
        } header: {
            Text("Rest")
        } footer: {
            if restPermissionDenied {
                Text("Notifications are turned off for Fit. Enable them in iOS Settings to get alerts when a rest ends.")
                    .foregroundStyle(.red)
            } else {
                Text("The default rest length starts the between-sets timer after each saved set. Alerts post a notification when a rest ends and need notification permission.")
            }
        }
    }

    /// Requests notification permission when the user enables alerts. If the
    /// request is denied, the toggle is reverted and the footnote explains why.
    private func confirmNotificationPermission() {
        restPermissionDenied = false
        Task { @MainActor in
            let granted = await RestNotifier.requestAuthorization()
            if !granted {
                restAlertsEnabled = false
                restPermissionDenied = true
            }
        }
    }

    // MARK: - iCloud / sync

    private var syncSection: some View {
        Section {
            HStack {
                Label {
                    Text(iCloudAvailable ? "iCloud available" : "Local only (iCloud signed out)")
                } icon: {
                    Image(systemName: iCloudAvailable ? "checkmark.icloud" : "icloud.slash")
                        .foregroundStyle(iCloudAvailable ? Color.green : Color.secondary)
                }
                Spacer()
            }
        } header: {
            Text("iCloud & Sync")
        } footer: {
            Text("Fit is local-first: everything works offline and stays on your device. When you're signed into iCloud, your data also syncs and backs up privately to your own iCloud account. There is no separate Fit server.")
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            // Provided by the HealthImport module: permission status + import buttons.
            HealthSettingsSection()
            Stepper(value: maxHeartRateSelection, in: 120...220, step: 1) {
                HStack {
                    Text("Max heart rate")
                    Spacer()
                    Text("\(maxHeartRateSelection.wrappedValue) bpm")
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                ImportHealthDataView()
            } label: {
                Label("Import Health data", systemImage: "heart.text.square")
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Health access is read-only. Imported workouts, body weight and sleep are clearly marked and never overwrite anything you logged manually. Max heart rate sets the heart-rate zone boundaries used when importing workouts.")
        }
    }

    // MARK: - Tracking (body weight) — F6

    private var trackingSection: some View {
        Section {
            NavigationLink {
                BodyWeightView()
            } label: {
                Label("Body weight", systemImage: "scalemass")
            }
        } header: {
            Text("Tracking")
        } footer: {
            Text("Log your body weight over time. The latest value is offered as the default when you log bodyweight exercises.")
        }
    }

    // MARK: - Export defaults

    private var exportSection: some View {
        Section {
            Toggle("Include Health data", isOn: $exportIncludesHealth)
            Toggle("Include journal entries", isOn: $exportIncludesJournal)
        } header: {
            Text("Export defaults")
        } footer: {
            Text("These are just the starting choices when you open the Export tab. Run a full export — CSV, JSON or a zip — from there.")
        }
    }

    // MARK: - Data management

    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                DataManagementView()
            } label: {
                Label("Data management", systemImage: "internaldrive")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                AboutView()
            } label: {
                Label("About Fit", systemImage: "info.circle")
            }
            DetailRow(label: "Version", value: "\(AppInfo.version) (\(AppInfo.build))")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
