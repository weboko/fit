import SwiftUI
import SwiftData

/// A button that exports a single workout (CSV + JSON, bundled as a `.zip`) and
/// presents the iOS share sheet. Consumed by HistoryJournal's workout detail.
///
/// All export work runs through `DataExportService` off the main actor; this view
/// only triggers it and presents the share sheet over the resulting file URL.
struct WorkoutShareButton: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context

    @State private var isExporting = false
    @State private var result: ExportResult?
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    init(session: WorkoutSession) {
        self.session = session
    }

    var body: some View {
        Button {
            runExport()
        } label: {
            if isExporting {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView()
                    Text("Preparing…")
                }
            } else {
                Label("Share workout", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isExporting)
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

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func runExport() {
        let request = ExportRequest(
            format: .zip,
            includeHealthData: true,
            includeJournal: true,
            includeBodyWeight: false,
            includeSleep: false,
            selectedWorkoutIDs: [session.id]
        )

        isExporting = true
        errorMessage = nil

        let container = context.container
        Task { @MainActor in
            do {
                let exportResult = try await Task.detached(priority: .userInitiated) {
                    let bgContext = ModelContext(container)
                    return try DataExportService().export(request, context: bgContext)
                }.value
                self.result = exportResult
                self.isExporting = false
                self.showShareSheet = true
            } catch {
                self.errorMessage = error.localizedDescription
                self.isExporting = false
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let session = (try? container.mainContext.fetch(FetchDescriptor<WorkoutSession>()))?.first
        ?? WorkoutSession(title: "Sample")
    return WorkoutShareButton(session: session)
        .modelContainer(container)
}
