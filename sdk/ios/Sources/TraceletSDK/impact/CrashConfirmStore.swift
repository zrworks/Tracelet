import Foundation
import UserNotifications

/// A crash/fall candidate awaiting confirmation, persisted to disk so its
/// countdown survives process death (#182).
///
/// `TraceletSdk` emits a transient `potential_crash` / `potential_fall`
/// candidate with a `confirmDeadlineMs`; if the user does not cancel before
/// that deadline it auto-confirms to a `crash` / `fall`. The in-process
/// confirmation runs on a timer, which dies if iOS suspends or kills the app
/// (common right after a violent impact). Persisting the candidate lets the SDK
/// re-emit the confirmed event when it next runs, and a scheduled local
/// notification alerts the user even while the app is dead.
struct PendingImpact: Codable {
    let id: Int64
    let kind: String
    let confidence: Double
    let peakG: Double
    let speedBefore: Double
    let latitude: Double
    let longitude: Double
    let timestampMs: Int64
    let confirmDeadlineMs: Int64

    /// The confirmed event kind this candidate escalates to.
    var confirmedKind: String { kind == "potential_fall" ? "fall" : "crash" }
}

/// Disk-backed store of pending crash/fall candidates (#182), persisted via
/// `UserDefaults`. `claim(_:)` is the atomic "take" used to dedupe the
/// in-process confirmation against the relaunch-drain safety net: whichever
/// path claims the candidate first delivers the confirmed event; the loser
/// finds nothing and does nothing.
final class CrashConfirmStore {

    static let shared = CrashConfirmStore()

    private let defaults = UserDefaults.standard
    private let storeKey = "com.tracelet.crashconfirm.pending"
    private let lock = NSLock()

    /// Persists (or overwrites) a pending candidate.
    func put(_ p: PendingImpact) {
        lock.lock(); defer { lock.unlock() }
        var map = load()
        map[String(p.id)] = p
        save(map)
    }

    /// Atomically removes and returns the candidate for `id`, or `nil` if it was
    /// already claimed/cancelled.
    func claim(_ id: Int64) -> PendingImpact? {
        lock.lock(); defer { lock.unlock() }
        var map = load()
        guard let p = map.removeValue(forKey: String(id)) else { return nil }
        save(map)
        return p
    }

    /// Removes the candidate for `id` if present (idempotent).
    func remove(_ id: Int64) {
        lock.lock(); defer { lock.unlock() }
        var map = load()
        if map.removeValue(forKey: String(id)) != nil { save(map) }
    }

    /// Candidates whose confirmation deadline (plus guard margin) has elapsed.
    func due(nowMs: Int64, guardMs: Int64) -> [PendingImpact] {
        lock.lock(); defer { lock.unlock() }
        return load().values.filter { nowMs >= $0.confirmDeadlineMs + guardMs }
    }

    private func load() -> [String: PendingImpact] {
        guard let data = defaults.data(forKey: storeKey) else { return [:] }
        return (try? JSONDecoder().decode([String: PendingImpact].self, from: data)) ?? [:]
    }

    private func save(_ map: [String: PendingImpact]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: storeKey)
        }
    }
}

/// Schedules and cancels the user-facing local notification that backs a
/// crash/fall confirmation (#182). Because iOS cannot run arbitrary code at a
/// precise future time once the app is killed, a `UNTimeIntervalNotificationTrigger`
/// scheduled at the confirmation deadline is the reliable way to alert the user
/// (or prompt them to open the app for SOS) even while the process is dead.
enum CrashConfirmNotifier {

    private static func identifier(_ id: Int64) -> String {
        "com.tracelet.crashconfirm.\(id)"
    }

    /// Schedules the safety-net notification `delaySeconds` from now. No-op if
    /// notifications are not authorized — the relaunch drain still delivers the
    /// confirmed event in that case, so we never surprise the user with a prompt.
    static func schedule(_ p: PendingImpact, delaySeconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                TraceletLog.debug("crash confirm: notifications not authorized — relying on relaunch drain")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = p.kind == "potential_fall" ? "Possible fall detected" : "Possible crash detected"
            content.body = "Open the app if you need help."
            content.sound = .default
            content.userInfo = ["traceletCrashConfirmId": p.id]
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, delaySeconds), repeats: false,
            )
            let request = UNNotificationRequest(
                identifier: identifier(p.id), content: content, trigger: trigger,
            )
            center.add(request) { error in
                if let error = error {
                    TraceletLog.error("crash confirm: failed to schedule notification — \(error)")
                }
            }
        }
    }

    /// Cancels a pending (and any delivered) safety-net notification for `id`.
    static func cancel(id: Int64) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(id)])
        center.removeDeliveredNotifications(withIdentifiers: [identifier(id)])
    }
}
