import UIKit

/// Battery level and charging state utilities.
///
/// `isBatteryMonitoringEnabled` is set once via `initialize()` rather than
/// on every query, avoiding repeated KVO observer churn.
final class BatteryUtils {
    /// Must be called once (on main thread) during plugin setup.
    static func initialize() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    static func getBatteryLevel() -> Float {
        return UIDevice.current.batteryLevel
    }

    static func isCharging() -> Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    static func getBatteryInfo() -> [String: Any] {
        return [
            "level": getBatteryLevel(),
            "is_charging": isCharging(),
        ]
    }
}
