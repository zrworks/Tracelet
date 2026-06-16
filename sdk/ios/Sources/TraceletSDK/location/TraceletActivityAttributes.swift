import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The attributes required to launch the Tracelet Live Activity.
/// Developers must use these attributes in their Xcode Widget Extension.
@available(iOS 16.1, *)
public struct TraceletActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// A dynamic status string (e.g., "Tracking active", "Paused")
        public var status: String
        
        public init(status: String) {
            self.status = status
        }
    }

    /// The static title to display in the Live Activity.
    public var title: String

    public init(title: String) {
        self.title = title
    }
}
#endif
