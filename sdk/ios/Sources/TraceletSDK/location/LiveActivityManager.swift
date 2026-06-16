import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
internal class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TraceletActivityAttributes>?
    
    private init() {}
    
    func startLiveActivity(title: String, body: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            TraceletLog.debug("[Tracelet] Live Activities are not enabled.")
            return
        }
        
        // Don't start a new one if we already have an active one
        if currentActivity != nil {
            return
        }
        
        // Clean up any orphaned activities from previous app sessions
        for activity in Activity<TraceletActivityAttributes>.activities {
            Task {
                let finalState = TraceletActivityAttributes.ContentState(status: "Tracking stopped")
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
            }
        }
        
        let attributes = TraceletActivityAttributes(title: title)
        let contentState = TraceletActivityAttributes.ContentState(status: body)
        
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: contentState, pushType: nil)
            }
            TraceletLog.debug("[Tracelet] Live Activity started with ID: \(currentActivity?.id ?? "unknown")")
        } catch {
            TraceletLog.error("[Tracelet] Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    func stopLiveActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            let finalState = TraceletActivityAttributes.ContentState(status: "Tracking stopped")
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
            currentActivity = nil
            TraceletLog.debug("[Tracelet] Live Activity stopped")
        }
    }
}
#endif
