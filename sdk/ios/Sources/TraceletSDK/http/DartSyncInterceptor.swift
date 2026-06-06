import Foundation

public protocol DartSyncInterceptor: AnyObject {
    func requestSyncBody(locations: [[String: Any]]) -> String?
    func requestFreshHeaders() -> Bool
    func requestTokenRefresh() -> Bool
}
