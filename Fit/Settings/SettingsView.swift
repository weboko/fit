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
                syncSection
                healthSection
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
            NavigationLink {
                ImportHealthDataView()
            } label: {
                Label("Import Health data", systemImage: "heart.text.square")
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Health access is read-only. Imported workouts, body weight and sleep are clearly marked and never overwrite anything you logged manually.")
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
