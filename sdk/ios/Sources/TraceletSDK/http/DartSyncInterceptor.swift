import Foundation

/// Sentinel returned by `requestSyncBody` to mean "no custom sync-body builder
/// is registered" — distinct from `nil`, which means a builder *is* registered
/// but failed to produce a body (timed out or threw).
///
/// Sync providers use this to decide between three outcomes:
/// - a real JSON string  → POST the custom body;
/// - this sentinel        → no builder, fall through to the default payload;
/// - `nil`                → builder failed, abort the sync (do not POST).
///
/// The literal value is duplicated in the Dart and Android layers; all three
/// must stay in sync.
public let traceletNoSyncBodyBuilderSentinel = "__tracelet_no_sync_body_builder__"

public protocol DartSyncInterceptor: AnyObject {
    /// Returns the custom JSON body, ``traceletNoSyncBodyBuilderSentinel`` when
    /// no builder is registered, or `nil` when a registered builder failed.
    func requestSyncBody(locations: [[String: Any]]) -> String?
    func requestFreshHeaders() -> Bool
    func requestTokenRefresh() -> Bool
}
