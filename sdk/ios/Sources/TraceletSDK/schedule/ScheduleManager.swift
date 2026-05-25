import BackgroundTasks
import Foundation
import TraceletCore

/// Schedule manager using BGTaskScheduler (iOS 13+).
///
/// Parses schedule strings in "dayStart-dayEnd HH:mm-HH:mm" format
/// and schedules BGAppRefreshTask for start/stop times.
public final class ScheduleManager {
    private let configManager: ConfigManager
    private let stateManager: StateManager
    private let eventDispatcher: TraceletEventSending
    
    private let parser = ScheduleParser()

    private static let startTaskId = "com.tracelet.schedule.start"
    private static let stopTaskId = "com.tracelet.schedule.stop"

    /// Called when schedule says to start tracking.
    public var onScheduleStart: (() -> Void)?
    /// Called when schedule says to stop tracking.
    public var onScheduleStop: (() -> Void)?

    public init(configManager: ConfigManager,
         stateManager: StateManager,
         eventDispatcher: TraceletEventSending) {
        self.configManager = configManager
        self.stateManager = stateManager
        self.eventDispatcher = eventDispatcher
    }

    // MARK: - Public API

    public func start() {
        stateManager.schedulerEnabled = true

        // Check if currently within schedule
        if isWithinSchedule() {
            onScheduleStart?()
            eventDispatcher.sendSchedule(stateManager.toMap(configManager.getConfig()))
        } else {
            onScheduleStop?()
            eventDispatcher.sendSchedule(stateManager.toMap(configManager.getConfig()))
        }

        scheduleNextTasks()
    }

    public func stop() {
        stateManager.schedulerEnabled = false
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: ScheduleManager.startTaskId)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: ScheduleManager.stopTaskId)
        }
        eventDispatcher.sendSchedule(stateManager.toMap(configManager.getConfig()))
    }

    /// Register BGTask identifiers. Must be called in application:didFinishLaunching.
    public static func registerBackgroundTasks(onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: startTaskId, using: nil) { task in
                onStart()
                task.setTaskCompleted(success: true)
            }
            BGTaskScheduler.shared.register(forTaskWithIdentifier: stopTaskId, using: nil) { task in
                onStop()
                task.setTaskCompleted(success: true)
            }
        }
    }

    // MARK: - Schedule parsing

    /// Check if current time is within any configured schedule window.
    public func isWithinSchedule() -> Bool {
        let schedules = configManager.getSchedule()
        guard !schedules.isEmpty else { return false }

        let now = Date()
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let tzOffset = Int32(TimeZone.current.secondsFromGMT(for: now))
        
        return parser.isWithinSchedule(schedules: schedules, timestampMs: nowMs, tzOffsetSeconds: tzOffset)
    }

    // MARK: - Internal

    private func scheduleNextTasks() {
        guard #available(iOS 13.0, *) else { return }

        let schedules = configManager.getSchedule()
        guard !schedules.isEmpty else { return }

        let now = Date()
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let tzOffset = Int32(TimeZone.current.secondsFromGMT(for: now))
        
        let alarms = parser.calculateNextAlarms(schedules: schedules, timestampMs: nowMs, tzOffsetSeconds: tzOffset)

        let startRequest = BGAppRefreshTaskRequest(identifier: ScheduleManager.startTaskId)
        if alarms.nextStartMs < Int64.max {
            let nextStart = Date(timeIntervalSince1970: TimeInterval(alarms.nextStartMs) / 1000)
            if nextStart.timeIntervalSinceNow > 0 {
                startRequest.earliestBeginDate = nextStart
            } else {
                startRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15)
            }
        } else {
             startRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15)
        }

        let stopRequest = BGAppRefreshTaskRequest(identifier: ScheduleManager.stopTaskId)
        if alarms.nextStopMs < Int64.max {
            let nextStop = Date(timeIntervalSince1970: TimeInterval(alarms.nextStopMs) / 1000)
            if nextStop.timeIntervalSinceNow > 0 {
                stopRequest.earliestBeginDate = nextStop
            } else {
                 stopRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15)
            }
        } else {
            stopRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15)
        }

        do {
            try BGTaskScheduler.shared.submit(startRequest)
            try BGTaskScheduler.shared.submit(stopRequest)
        } catch {
            NSLog("[Tracelet] Failed to schedule BGTask: \(error.localizedDescription)")
        }
    }
}
