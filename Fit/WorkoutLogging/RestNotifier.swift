import Foundation
import UserNotifications

/// Schedules (and cancels) a single local notification that fires when the
/// between-sets rest timer runs out, so the user is alerted even if the app is
/// backgrounded or the screen is locked (F5).
///
/// Everything is gated behind the `restAlertsEnabled` Settings toggle and the
/// system notification permission. Scheduling without permission is a harmless
/// system-level no-op, so callers never have to branch on authorization — the
/// methods here stay safe to call from the rest-timer lifecycle regardless of
/// the current permission state. A single fixed identifier means a new rest (or
/// a ±15s adjustment) simply replaces any still-pending alert.
@MainActor
enum RestNotifier {
    /// Identifier shared by every rest-end request so there is only ever one
    /// pending alert; rescheduling replaces it rather than stacking up.
    private static let identifier = "fit.rest.end"

    /// Whether rest-end alerts are turned on in Settings. Defaults to `false`
    /// until the user opts in (and grants notification permission).
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettingsKeys.restAlertsEnabled)
    }

    /// Asks the system for permission to post alerts with sound. Returns whether
    /// permission was granted. Safe to call repeatedly; the system only prompts
    /// the first time.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    /// Schedules the rest-end alert to fire after `seconds`, replacing any
    /// previously pending one. No-op when alerts are disabled or `seconds <= 0`.
    static func scheduleRestEnd(after seconds: TimeInterval) {
        guard isEnabled, seconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Removes any pending rest-end alert. Safe to call when nothing is pending.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
