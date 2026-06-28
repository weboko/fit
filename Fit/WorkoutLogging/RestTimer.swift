import SwiftUI

/// Drives the between-sets rest countdown for the live workout (spec §6, §7).
///
/// Purely in-app: no local notifications here (that is a later feature). The
/// model only owns the timing state; the actual per-second ticking is driven by
/// the owning view via a `Timer.publish` autoconnect, which calls `tick(_:)`.
/// `stop()` / `skip()` clear `isRunning` so the view can tear the publisher's
/// effect down (hide the bar) — pause/stop therefore "invalidate" the visible
/// countdown without relying on a retained `Timer` instance.
@MainActor
@Observable
final class RestTimerModel {
    /// Seconds left on the current rest. Clamped to `0...duration`.
    private(set) var remaining: TimeInterval = 0
    /// The rest length the current countdown started from, for progress display.
    private(set) var duration: TimeInterval = 0
    /// Whether a countdown is active and the bar should be shown.
    private(set) var isRunning: Bool = false

    /// Fraction of the rest already elapsed, in `0...1`.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, (duration - remaining) / duration))
    }

    /// Begins (or restarts) a rest countdown for `seconds`.
    func start(_ seconds: TimeInterval) {
        let clamped = max(0, seconds)
        duration = clamped
        remaining = clamped
        isRunning = clamped > 0
    }

    /// Stops the countdown and hides the bar.
    func stop() {
        isRunning = false
        remaining = 0
        duration = 0
    }

    /// Skips the remaining rest. Equivalent to `stop()` for an in-app timer.
    func skip() {
        stop()
    }

    /// Adjusts the remaining time by `delta`, clamping at zero. Extends the
    /// `duration` when adding beyond the original length so progress stays valid.
    func add(_ delta: TimeInterval) {
        guard isRunning else { return }
        let newRemaining = max(0, remaining + delta)
        remaining = newRemaining
        if newRemaining > duration { duration = newRemaining }
        if newRemaining == 0 { stop() }
    }

    /// Advances the countdown by `seconds` (called once per tick by the view).
    func tick(_ seconds: TimeInterval = 1) {
        guard isRunning else { return }
        remaining = max(0, remaining - seconds)
        if remaining == 0 { stop() }
    }
}

/// Compact rest-timer control surfaced on the active workout screen while a
/// rest is running. Shows the remaining time over a linear progress track and
/// big-target buttons to trim, extend or skip the rest (spec §6, §14.1).
struct RestTimerBar: View {
    @Bindable var model: RestTimerModel

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Label("Rest", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Format.duration(model.remaining))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: model.progress)
                .tint(Color.accentColor)

            HStack(spacing: Theme.Spacing.s) {
                adjustButton(label: "−15s", systemImage: "gobackward.15") {
                    model.add(-15)
                }
                adjustButton(label: "+15s", systemImage: "goforward.15") {
                    model.add(15)
                }
                Button {
                    model.skip()
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }

    private func adjustButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The default rest length, read from `UserDefaults`, falling back to 90s.
enum RestTimerDefaults {
    static let fallbackSeconds: TimeInterval = 90

    static var defaultRestSeconds: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: AppSettingsKeys.defaultRestSeconds)
        return stored > 0 ? stored : fallbackSeconds
    }
}

#Preview {
    let model = RestTimerModel()
    model.start(90)
    return VStack {
        Spacer()
        RestTimerBar(model: model)
    }
    .background(Color(.systemGroupedBackground))
}
