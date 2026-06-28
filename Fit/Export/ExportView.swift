import SwiftUI
import SwiftData
import UIKit

// MARK: - Date-range presets

/// User-facing date-range presets for the export screen.
private enum DateRangePreset: String, CaseIterable, Identifiable {
    case all
    case last7
    case last30
    case last90
    case thisYear
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All data"
        case .last7: return "Last 7 days"
        case .last30: return "Last 30 days"
        case .last90: return "Last 90 days"
        case .thisYear: return "This year"
        case .custom: return "Custom range"
        }
    }

    /// Resolve to a concrete (start, end) pair. `custom` returns nil so the view
    /// uses its own DatePicker bindings instead.
    func resolvedRange(now: Date = Date(), calendar: Calendar = .current) -> (start: Date?, end: Date?)? {
        switch self {
        case .all:
            return (nil, nil)
        case .last7:
            return (calendar.date(byAdding: .day, value: -7, to: now), now)
        case .last30:
            return (calendar.date(byAdding: .day, value: -30, to: now), now)
        case .last90:
            return (calendar.date(byAdding: .day, value: -90, to: now), now)
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            let startOfYear = calendar.date(from: comps)
            return (startOfYear, now)
        case .custom:
            return nil
        }
    }
}

// MARK: - Export tab

/// The Export tab. Lets the user pick a date range, format and inclusions, then
/// generates the files via `DataExportService` (off the main thread) and presents
/// the iOS share sheet. All export logic lives in the service, not here.
struct ExportView: View {
    @Environment(\.modelContext) private var context

    // Date range
    @State private var preset: DateRangePreset = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    // Format
    @State private var format: ExportFormat = .zip

    // Inclusions — defaulted from AppSettings where available.
    @State private var includeHealth: Bool = UserDefaults.standard.object(forKey: AppSettingsKeys.defaultExportIncludesHealth) as? Bool ?? true
    @State private var includeJournal: Bool = UserDefaults.standard.object(forKey: AppSettingsKeys.defaultExportIncludesJournal) as? Bool ?? true
    @State private var includeBodyWeight: Bool = true
    @State private var includeSleep: Bool = true

    // Run state
    @State private var isExporting = false
    @State private var result: ExportResult?
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                dateRangeSection
                formatSection
                inclusionsSection
                generateSection
                if let result {
                    resultSection(result)
                }
            }
            .navigationTitle("Export")
            .sheet(isPresented: $showShareSheet) {
                if let result {
                    ShareSheet(activityItems: result.fileURLs)
                }
            }
            .alert("Export failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    // MARK: - Sections

    private var dateRangeSection: some View {
        Section("Date range") {
            Picker("Range", selection: $preset) {
                ForEach(DateRangePreset.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)

            if preset == .custom {
                DatePicker("From", selection: $customStart, displayedComponents: [.date])
                DatePicker("To", selection: $customEnd, in: customStart..., displayedComponents: [.date])
            }
        }
    }

    private var formatSection: some View {
        Section {
            Picker("Format", selection: $format) {
                ForEach(ExportFormat.allCases) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Format")
        } footer: {
            Text("CSV gives one spreadsheet per data type. JSON is a single structured file. ZIP bundles everything together.")
        }
    }

    private var inclusionsSection: some View {
        Section {
            Toggle("Apple Health data", isOn: $includeHealth)
            Toggle("Journal notes", isOn: $includeJournal)
            Toggle("Body weight", isOn: $includeBodyWeight)
            Toggle("Sleep", isOn: $includeSleep)
        } header: {
            Text("Include")
        } footer: {
            Text("Workouts, sets and your exercise library are always included.")
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                runExport()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                        Text("Generating…")
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Generate & Share")
                    }
                    Spacer()
                }
                .frame(minHeight: Theme.Size.controlHeight)
            }
            .disabled(isExporting)
        } footer: {
            Text("Everything is generated on this device. Nothing is uploaded — sharing is entirely up to you.")
        }
    }

    private func resultSection(_ result: ExportResult) -> some View {
        Section("Last export") {
            DetailRow(label: "Format", value: result.format.shortLabel)
            DetailRow(label: "Files", value: "\(result.fileURLs.count)")
            DetailRow(label: "Generated", value: result.generatedAt.formatted(.dateTime.hour().minute().second()))
            ForEach(result.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                showShareSheet = true
            } label: {
                Label("Share again", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Actions

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func resolvedDateRange() -> (start: Date?, end: Date?) {
        if let resolved = preset.resolvedRange() {
            return resolved
        }
        // Custom: normalise so the end covers the whole selected day.
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: customStart)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
        return (startOfDay, endOfDay)
    }

    private func runExport() {
        let range = resolvedDateRange()
        let request = ExportRequest(
            dateRangeStart: range.start,
            dateRangeEnd: range.end,
            format: format,
            includeHealthData: includeHealth,
            includeJournal: includeJournal,
            includeBodyWeight: includeBodyWeight,
            includeSleep: includeSleep
        )

        isExporting = true
        errorMessage = nil

        // Build a background ModelContext from the same container so the fetch +
        // file writing happen off the main actor. The produced URLs are plain
        // file URLs, safe to hand back to the main actor for the share sheet.
        let container = context.container
        Task.detached(priority: .userInitiated) {
            let bgContext = ModelContext(container)
            let service = DataExportService()
            do {
                let exportResult = try service.export(request, context: bgContext)
                await MainActor.run {
                    self.result = exportResult
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isExporting = false
                }
            }
        }
    }
}

// MARK: - Share sheet wrapper

/// A thin `UIViewControllerRepresentable` over `UIActivityViewController` for
/// sharing arbitrary file URLs. Used where `ShareLink` (single item) is not a fit.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ExportView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
