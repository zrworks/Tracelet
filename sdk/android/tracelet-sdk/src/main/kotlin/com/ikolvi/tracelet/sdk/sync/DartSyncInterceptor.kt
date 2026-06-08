package com.ikolvi.tracelet.sdk.sync

/**
 * Sentinel returned by [DartSyncInterceptor.requestSyncBody] to mean "no custom
 * sync-body builder is registered" — distinct from `null`, which means a builder
 * *is* registered but failed to produce a body (timed out or threw).
 *
 * Sync providers use this to decide between three outcomes:
 * - a real JSON string  -> POST the custom body;
 * - this sentinel       -> no builder, fall through to the default payload;
 * - `null`              -> builder failed, abort the sync (do not POST).
 *
 * The literal value is duplicated in the Dart and iOS layers; all three must
 * stay in sync.
 */
const val NO_SYNC_BODY_BUILDER_SENTINEL = "__tracelet_no_sync_body_builder__"

interface DartSyncInterceptor {
    /**
     * Request a custom sync body from Dart.
     *
     * Returns the custom JSON body, [NO_SYNC_BODY_BUILDER_SENTINEL] when no
     * builder is registered, or `null` when a registered builder failed.
     */
    fun requestSyncBody(locations: List<Map<String, Any?>>): String?

    /**
     * Request fresh HTTP headers from Dart.
     * Returns true if headers were successfully refreshed.
     */
    fun requestFreshHeaders(): Boolean

    /**
     * Request a token refresh from Dart after a 401 Unauthorized.
     * Returns true if the token was refreshed and headers updated.
     */
    fun requestTokenRefresh(): Boolean
}
