import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
internal class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TraceletActivityAttributes>?
    
    private init() {}
    
    func startLiveActivity(title: String, body: String) {
        TraceletLog.debug("[Tracelet-LiveActivity] startLiveActivity called with title: \(title)")
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            TraceletLog.debug("[Tracelet-LiveActivity] ABORT: Live Activities are not enabled.")
            return
        }
        
        // Don't start a new one if we already have an active one
        if let current = currentActivity {
            TraceletLog.debug("[Tracelet-LiveActivity] ABORT: currentActivity is NOT nil (ID: \(current.id)). Returning early.")
            return
        }
        
        Task {
            let activeCount = Activity<TraceletActivityAttributes>.activities.count
            TraceletLog.debug("[Tracelet-LiveActivity] Found \(activeCount) existing activities to clean up.")
            
            // Clean up ANY existing activities first and await their completion
            // This prevents "maximum number of activities reached" race conditions
            for activity in Activity<TraceletActivityAttributes>.activities {
                TraceletLog.debug("[Tracelet-LiveActivity] Ending old activity ID: \(activity.id) state: \(activity.activityState)")
                let finalState = TraceletActivityAttributes.ContentState(status: "Tracking stopped")
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
                TraceletLog.debug("[Tracelet-LiveActivity] Finished ending activity ID: \(activity.id)")
            }
            
            TraceletLog.debug("[Tracelet-LiveActivity] Requesting new activity...")
            let attributes = TraceletActivityAttributes(title: title)
            let contentState = TraceletActivityAttributes.ContentState(status: body)
            
            do {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: contentState, staleDate: nil)
                    self.currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
                } else {
                    self.currentActivity = try Activity.request(attributes: attributes, contentState: contentState, pushType: nil)
                }
                TraceletLog.debug("[Tracelet-LiveActivity] SUCCESS: Live Activity started with ID: \(self.currentActivity?.id ?? "unknown")")
            } catch {
                TraceletLog.error("[Tracelet-LiveActivity] FAILED to request new Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    func stopLiveActivity() {
        TraceletLog.debug("[Tracelet-LiveActivity] stopLiveActivity called.")
        
        guard let activity = currentActivity else {
            TraceletLog.debug("[Tracelet-LiveActivity] currentActivity is already nil. Running fallback cleanup.")
            // Even if currentActivity is nil, ensure we nuke any orphaned activities
            Task {
                for act in Activity<TraceletActivityAttributes>.activities {
                    TraceletLog.debug("[Tracelet-LiveActivity] Fallback ending activity ID: \(act.id)")
                    let finalState = TraceletActivityAttributes.ContentState(status: "Tracking stopped")
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(state: finalState, staleDate: nil)
                        await act.end(content, dismissalPolicy: .immediate)
                    } else {
                        await act.end(using: finalState, dismissalPolicy: .immediate)
                    }
                }
            }
            return
        }
        
        TraceletLog.debug("[Tracelet-LiveActivity] Synchronously clearing currentActivity pointer for ID: \(activity.id)")
        currentActivity = nil
        
        Task {
            TraceletLog.debug("[Tracelet-LiveActivity] Async ending activity ID: \(activity.id)")
            let finalState = TraceletActivityAttributes.ContentState(status: "Tracking stopped")
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
            TraceletLog.debug("[Tracelet-LiveActivity] Successfully ended activity ID: \(activity.id)")
        }
    }
}
#endif
