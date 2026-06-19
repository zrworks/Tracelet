package com.ikolvi.tracelet.sdk.impact

import android.content.Context
import android.content.SharedPreferences
import com.ikolvi.tracelet.sdk.util.TraceletLog
import org.json.JSONObject

/**
 * A crash/fall candidate awaiting confirmation, persisted to disk so its
 * countdown survives process death (#182).
 *
 * The native [com.ikolvi.tracelet.sdk.TraceletSdk] emits a transient
 * `potential_crash` / `potential_fall` candidate with a [confirmDeadlineMs];
 * if the user does not cancel before that deadline it auto-confirms to a
 * `crash` / `fall`. The in-process confirmation runs on a main-thread poll
 * loop, which dies if the OS kills the app (common right after a violent
 * impact). Persisting the candidate lets a wake-up [CrashConfirmReceiver]
 * re-emit the confirmed event from a fresh process.
 */
data class PendingImpact(
    val id: Long,
    val kind: String,
    val confidence: Double,
    val peakG: Double,
    val speedBefore: Double,
    val latitude: Double,
    val longitude: Double,
    val timestampMs: Long,
    val confirmDeadlineMs: Long,
) {
    /** The confirmed event kind this candidate escalates to. */
    val confirmedKind: String
        get() = if (kind == "potential_fall") "fall" else "crash"

    fun toJson(): String = JSONObject().apply {
        put("id", id)
        put("kind", kind)
        put("confidence", confidence)
        put("peakG", peakG)
        put("speedBefore", speedBefore)
        put("latitude", latitude)
        put("longitude", longitude)
        put("timestampMs", timestampMs)
        put("confirmDeadlineMs", confirmDeadlineMs)
    }.toString()

    companion object {
        fun fromJson(json: String): PendingImpact? = try {
            val o = JSONObject(json)
            PendingImpact(
                id = o.getLong("id"),
                kind = o.getString("kind"),
                confidence = o.getDouble("confidence"),
                peakG = o.getDouble("peakG"),
                speedBefore = o.getDouble("speedBefore"),
                latitude = o.getDouble("latitude"),
                longitude = o.getDouble("longitude"),
                timestampMs = o.getLong("timestampMs"),
                confirmDeadlineMs = o.getLong("confirmDeadlineMs"),
            )
        } catch (e: Exception) {
            TraceletLog.error("CrashConfirmStore: corrupt candidate JSON — ${e.message}")
            null
        }
    }
}

/**
 * Disk-backed store of pending crash/fall candidates (#182).
 *
 * Each candidate lives under its own key so concurrent puts/removals for
 * different ids never clobber one another. [claim] is the atomic "take"
 * operation used to dedupe the in-process confirmation against the
 * process-death safety-net alarm: whichever path claims the candidate first
 * delivers the confirmed event; the loser finds nothing and does nothing.
 */
class CrashConfirmStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Persists (or overwrites) a pending candidate. */
    @Synchronized
    fun put(p: PendingImpact) {
        prefs.edit().putString(key(p.id), p.toJson()).apply()
    }

    /**
     * Atomically removes and returns the candidate for [id], or `null` if it
     * was already claimed/cancelled. Uses a synchronous commit so the removal
     * is visible to other processes before the caller acts on the result.
     */
    @Synchronized
    @Suppress("ApplySharedPref")
    fun claim(id: Long): PendingImpact? {
        val json = prefs.getString(key(id), null) ?: return null
        prefs.edit().remove(key(id)).commit()
        return PendingImpact.fromJson(json)
    }

    /** Removes the candidate for [id] if present (idempotent). */
    @Synchronized
    fun remove(id: Long) {
        prefs.edit().remove(key(id)).apply()
    }

    companion object {
        private const val PREFS_NAME = "com.tracelet.crashconfirm"
        private fun key(id: Long): String = "candidate_$id"
    }
}
