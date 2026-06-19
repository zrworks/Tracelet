package com.ikolvi.tracelet.sdk.crash

import android.content.Context
import uniffi.tracelet_core.CrashModel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Acquires + decrypts the opt-in crash ML model (#183), or returns `null` so the
 * SDK falls back to the rule-based detector. Never throws to the caller.
 *
 * Flow: use the cached **encrypted** blob if present, else download it; verify
 * the optional SHA-256; AES-256-GCM-decrypt via the Rust core
 * ([CrashModel.fromEncrypted]); return the loaded model. Only the *encrypted*
 * blob is ever written to disk — the decrypted model lives in memory only.
 */
object CrashModelLoader {
    private const val CACHE_FILE = "tracelet_crash_model.enc"

    /**
     * AES-256-GCM decryption key (32 bytes), supplied at runtime by the host —
     * injected from a build-time secret or fetched from a key endpoint. It is
     * **never** stored in this open-source repo. When unset, model loading is
     * skipped and the rule engine is used.
     */
    @Volatile
    @JvmStatic
    var decryptionKey: ByteArray? = null

    /**
     * Loads the model for [url], or `null` to fall back to the rule engine.
     *
     * @param sha256 optional hex digest of the encrypted blob, verified after
     *   fetch; a mismatch discards the cache and returns `null`.
     */
    fun load(
        context: Context,
        url: String,
        sha256: String?,
        log: (String) -> Unit = {},
    ): CrashModel? {
        val key = decryptionKey
        if (key == null) {
            log("crash model: no decryption key set — using rule engine")
            return null
        }
        if (key.size != 32) {
            log("crash model: decryption key must be 32 bytes — using rule engine")
            return null
        }
        return try {
            val cache = File(context.filesDir, CACHE_FILE)
            var blob = if (cache.exists() && cache.length() > 0) cache.readBytes() else null
            if (blob == null) {
                blob = download(url)
                cache.writeBytes(blob)
            }
            if (sha256 != null && !sha256Hex(blob).equals(sha256, ignoreCase = true)) {
                log("crash model: SHA-256 mismatch — discarding cache, using rule engine")
                cache.delete()
                return null
            }
            val model = CrashModel.fromEncrypted(blob, key)
            log("crash model: loaded (${model.treeCount()} trees)")
            model
        } catch (e: Exception) {
            log("crash model: load failed (${e.message}) — using rule engine")
            null
        }
    }

    private fun download(url: String): ByteArray {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 30_000
            requestMethod = "GET"
        }
        try {
            val code = conn.responseCode
            if (code != 200) throw RuntimeException("download HTTP $code")
            return conn.inputStream.use { it.readBytes() }
        } finally {
            conn.disconnect()
        }
    }

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { "%02x".format(it) }
}
