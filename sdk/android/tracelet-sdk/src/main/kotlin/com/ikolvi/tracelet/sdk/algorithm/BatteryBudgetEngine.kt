package com.ikolvi.tracelet.sdk.algorithm

/**
 * Auto-adjusts tracking parameters to stay within a battery drain budget.
 *
 * Given a target maximum battery consumption per hour (% points), monitors
 * actual battery drain and adjusts `distanceFilter`, `desiredAccuracy`, and
 * (for periodic mode) the polling interval.
 *
 * Control loop (called every sampling window):
 * 1. Compute actual drain over the window, normalize to %/hr.
 * 2. Compare to target budget.
 * 3. If draining too fast: increase distanceFilter, degrade accuracy.
 * 4. If under budget: decrease distanceFilter, improve accuracy.
 * 5. Clamp values to sane ranges.
 *
 * Accuracy levels (ordered by battery cost, index 0 = highest):
 * `high (0) → medium (1) → low (2) → veryLow (3) → passive (4)`
 */
class BatteryBudgetEngine(
    /** Target maximum battery drain per hour (% points). */
    val targetBudgetPerHour: Double,
    initialDistanceFilter: Double = 10.0,
    initialAccuracyIndex: Int = 0,
    initialPeriodicInterval: Int? = null,
) {

    private val coreEngine = uniffi.tracelet_core.BatteryBudgetEngine(
        targetBudgetPerHour,
        initialDistanceFilter,
        initialAccuracyIndex,
        initialPeriodicInterval
    )

    /** Current adjusted distance filter (meters). */
    val distanceFilter: Double
        get() = coreEngine.distanceFilter()

    /** Current adjusted accuracy index (0=high, 4=passive). */
    val accuracyIndex: Int
        get() = coreEngine.accuracyIndex()

    /** Current adjusted periodic interval (null if not periodic). */
    val periodicInterval: Int?
        get() = coreEngine.periodicInterval()

    /**
     * Process a new battery sample and return an adjustment if needed.
     *
     * Call this periodically (every 5 minutes is recommended).
     *
     * @param batteryLevel 0.0–1.0 (percentage as fraction)
     * @return adjustment event if parameters changed, null otherwise
     */
    fun processSample(batteryLevel: Double, nowMs: Long = System.currentTimeMillis()): BudgetAdjustmentEvent? {
        val event = coreEngine.processSample(batteryLevel, nowMs)
        if (event == null) return null

        return BudgetAdjustmentEvent(
            currentBatteryDrain = event.currentBatteryDrain,
            targetBudget = event.targetBudget,
            newDistanceFilter = event.newDistanceFilter,
            newDesiredAccuracy = event.newDesiredAccuracy,
            newPeriodicInterval = event.newPeriodicInterval,
        )
    }

    /** Reset the engine state. Call when tracking restarts. */
    fun reset() {
        coreEngine.reset()
    }
}

/**
 * Event emitted when the battery budget engine adjusts tracking parameters.
 */
data class BudgetAdjustmentEvent(
    /** Estimated current battery drain in %/hr. */
    val currentBatteryDrain: Double,
    /** Configured budget target in %/hr. */
    val targetBudget: Double,
    /** Adjusted distance filter (meters). */
    val newDistanceFilter: Double,
    /** Adjusted desired accuracy level index. */
    val newDesiredAccuracy: Int,
    /** Adjusted periodic interval (null if not in periodic mode). */
    val newPeriodicInterval: Int?,
)
