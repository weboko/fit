import SwiftUI
import SwiftData

/// Root tab layout. Uses 5 tabs with the Journal folded into History (the
/// spec-sanctioned alternative to a 6-tab layout, §14), keeping the iPhone tab
/// bar uncluttered for one-handed gym use.
///
/// Each tab's root view is owned by its module:
/// - `TodayView`            → WorkoutLogging
/// - `HistoryView`          → HistoryJournal
/// - `ExerciseLibraryView`  → ExerciseLibrary
/// - `ExportView`           → Export
/// - `SettingsView`         → Settings
struct ContentView: View {
    @Environment(\.modelContext) private var context

    /// First-run onboarding gate (F15). Shown once via a full-screen cover until
    /// the user finishes or skips, after which it never appears again.
    @AppStorage(AppSettingsKeys.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            ExerciseLibraryView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            SeedData.seedIfNeeded(in: context)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasOnboarded },
            set: { showing in if !showing { hasOnboarded = true } }
        )) {
            OnboardingView(onFinish: { hasOnboarded = true })
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
