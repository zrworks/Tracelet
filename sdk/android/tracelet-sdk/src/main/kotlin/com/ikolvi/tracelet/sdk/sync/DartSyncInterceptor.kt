package com.ikolvi.tracelet.sdk.sync

interface DartSyncInterceptor {
    /**
     * Request a custom sync body from Dart.
     * Returns a JSON string if a custom builder is registered, null otherwise.
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
