import SwiftUI
import SwiftData

/// About screen (spec §24): app identity plus a plain-language privacy statement.
///
/// Fit is deliberately simple and private: it has no custom backend, no
/// third-party tracking or analytics, no AI/LLM calls and no ads. The privacy
/// copy here states exactly that so the user can trust where their data goes.
struct AboutView: View {
    var body: some View {
        Form {
            identitySection
            privacySection
            howItWorksSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section {
            VStack(alignment: .center, spacing: Theme.Spacing.s) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.accent)
                Text("Fit")
                    .font(.title2.weight(.bold))
                Text("Version \(AppInfo.version) (\(AppInfo.build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("A personal, local-first strength-training logger.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            ForEach(privacyPoints, id: \.text) { point in
                Label {
                    Text(point.text)
                } icon: {
                    Image(systemName: point.systemImage)
                        .foregroundStyle(Color.green)
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Fit is built to keep your training data yours. No account is required.")
        }
    }

    private struct PrivacyPoint {
        let systemImage: String
        let text: String
    }

    private let privacyPoints: [PrivacyPoint] = [
        PrivacyPoint(systemImage: "server.rack",
                     text: "No custom backend. There is no Fit server collecting your data."),
        PrivacyPoint(systemImage: "eye.slash",
                     text: "No third-party tracking, analytics or ads."),
        PrivacyPoint(systemImage: "brain",
                     text: "No AI or LLM calls. Nothing you log is sent to any model."),
        PrivacyPoint(systemImage: "iphone",
                     text: "Your data stays on your device and, if you're signed in, in your own private iCloud."),
        PrivacyPoint(systemImage: "square.and.arrow.up",
                     text: "Exports are always started by you — data never leaves on its own."),
        PrivacyPoint(systemImage: "heart.text.square",
                     text: "Apple Health access is transparent and read-only."),
    ]

    // MARK: - How it works

    private var howItWorksSection: some View {
        Section {
            Text("Fit works fully offline. Everything is stored locally with SwiftData. When iCloud is available, your data syncs and backs up privately to your own iCloud account using Apple's CloudKit — no one else can see it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("How it works")
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
