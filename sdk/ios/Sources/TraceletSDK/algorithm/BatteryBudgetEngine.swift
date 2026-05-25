import Foundation

/// Event emitted when the battery budget engine adjusts tracking parameters.
public struct BudgetAdjustmentEvent {
    /// Estimated current battery drain in %/hr.
    public let currentBatteryDrain: Double
    /// Configured budget target in %/hr.
    public let targetBudget: Double
    /// Adjusted distance filter (meters).
    public let newDistanceFilter: Double
    /// Adjusted desired accuracy level index.
    public let newDesiredAccuracy: Int
    /// Adjusted periodic interval (nil if not in periodic mode).
    public let newPeriodicInterval: Int?
}

/// Auto-adjusts tracking parameters to stay within a battery drain budget.
///
/// Given a target maximum battery consumption per hour (% points), monitors
/// actual battery drain and adjusts `distanceFilter`, `desiredAccuracy`, and
/// (for periodic mode) the polling interval.
///
/// Accuracy levels (ordered by battery cost, index 0 = highest):
/// `high (0) → medium (1) → low (2) → veryLow (3) → passive (4)`
public class BatteryBudgetEngine {
    
    private let coreEngine: BatteryBudgetEngineCore

    /// Target maximum battery drain per hour (% points).
    public var targetBudgetPerHour: Double {
        // the core doesn't expose a getter for target_budget_per_hour directly, but we don't really need it
        // we can store it locally if needed, but it's only used internally
        return _targetBudgetPerHour
    }
    private let _targetBudgetPerHour: Double

    /// Current adjusted distance filter (meters).
    public var distanceFilter: Double { coreEngine.distanceFilter() }

    /// Current adjusted accuracy index (0=high, 4=passive).
    public var accuracyIndex: Int { Int(coreEngine.accuracyIndex()) }

    /// Current adjusted periodic interval (nil if not periodic).
    public var periodicInterval: Int? { coreEngine.periodicInterval().map { Int(truncating: $0) } }

    public init(
        targetBudgetPerHour: Double,
        initialDistanceFilter: Double = 10.0,
        initialAccuracyIndex: Int = 0,
        initialPeriodicInterval: Int? = nil
    ) {
        self._targetBudgetPerHour = targetBudgetPerHour
        self.coreEngine = BatteryBudgetEngineCore(
            targetBudgetPerHour: targetBudgetPerHour,
            initialDistanceFilter: initialDistanceFilter,
            initialAccuracyIndex: Int32(initialAccuracyIndex),
            initialPeriodicInterval: initialPeriodicInterval.map { NSNumber(value: $0) }
        )
    }

    /// Process a new battery sample and return an adjustment if needed.
    ///
    /// Call this periodically (every 5 minutes is recommended).
    ///
    /// - Parameter batteryLevel: 0.0–1.0 (percentage as fraction)
    /// - Returns: adjustment event if parameters changed, nil otherwise
    public func processSample(_ batteryLevel: Double) -> BudgetAdjustmentEvent? {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        
        guard let event = coreEngine.processSample(batteryLevel: batteryLevel, nowMs: nowMs) else {
            return nil
        }
        
        return BudgetAdjustmentEvent(
            currentBatteryDrain: event.currentBatteryDrain,
            targetBudget: event.targetBudget,
            newDistanceFilter: event.newDistanceFilter,
            newDesiredAccuracy: Int(event.newDesiredAccuracy),
            newPeriodicInterval: event.newPeriodicInterval.map { Int(truncating: $0) }
        )
    }

    /// Reset the engine state. Call when tracking restarts.
    public func reset() {
        coreEngine.reset()
    }
}
