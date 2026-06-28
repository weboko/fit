import SwiftUI
import SwiftData

/// App entry point. Builds the shared SwiftData container (local-first with
/// CloudKit mirroring, falling back to local-only) and installs it into the
/// environment for every module to use.
@main
struct FitApp: App {
    let container: ModelContainer

    init() {
        container = PersistenceController.makeSharedContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
