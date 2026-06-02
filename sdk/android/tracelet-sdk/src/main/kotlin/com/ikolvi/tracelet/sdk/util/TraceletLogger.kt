package com.ikolvi.tracelet.sdk.util

import android.content.Context
import android.util.Log
import com.ikolvi.tracelet.sdk.ConfigManager

/**
 * Logger that writes to Android logcat.
 *
 * Log levels: OFF(0), ERROR(1), WARNING(2), INFO(3), DEBUG(4), VERBOSE(5)
 */
class TraceletLogger(
    private val context: Context,
    private val config: ConfigManager,
) {
    var rustDatabase: uniffi.tracelet_core.DatabaseManager? = null

    companion object {
        private const val TAG = "Tracelet"

        // Log level constants matching Dart LogLevel enum
        const val LEVEL_OFF = 0
        const val LEVEL_ERROR = 1
        const val LEVEL_WARNING = 2
        const val LEVEL_INFO = 3
        const val LEVEL_DEBUG = 4
        const val LEVEL_VERBOSE = 5

        fun levelToString(level: Int): String = when (level) {
            LEVEL_ERROR -> "ERROR"
            LEVEL_WARNING -> "WARNING"
            LEVEL_INFO -> "INFO"
            LEVEL_DEBUG -> "DEBUG"
            LEVEL_VERBOSE -> "VERBOSE"
            else -> "OFF"
        }
    }

    /** Log an error message. */
    fun error(message: String, tag: String = TAG) {
        logInternal(LEVEL_ERROR, message, tag)
    }

    /** Log a warning message. */
    fun warning(message: String, tag: String = TAG) {
        logInternal(LEVEL_WARNING, message, tag)
    }

    /** Log an info message. */
    fun info(message: String, tag: String = TAG) {
        logInternal(LEVEL_INFO, message, tag)
    }

    /** Log a debug message. */
    fun debug(message: String, tag: String = TAG) {
        logInternal(LEVEL_DEBUG, message, tag)
    }

    /** Log a verbose message. */
    fun verbose(message: String, tag: String = TAG) {
        logInternal(LEVEL_VERBOSE, message, tag)
    }

    /** Log with explicit level (from Dart). */
    fun log(level: String, message: String): Boolean {
        // Compare without allocating a new uppercase string (A-L2).
        val levelInt = when {
            level.equals("ERROR", ignoreCase = true) -> LEVEL_ERROR
            level.equals("WARNING", ignoreCase = true) || level.equals("WARN", ignoreCase = true) -> LEVEL_WARNING
            level.equals("INFO", ignoreCase = true) -> LEVEL_INFO
            level.equals("DEBUG", ignoreCase = true) -> LEVEL_DEBUG
            level.equals("VERBOSE", ignoreCase = true) -> LEVEL_VERBOSE
            else -> LEVEL_INFO
        }
        logInternal(levelInt, message, TAG)
        return true
    }

    /** Get the log as a string (optionally filtered). */
    fun getLog(query: Map<String, Any?>?): String {
        return try {
            val limit = (query?.get("limit") as? Number)?.toInt() ?: 500
            val logs = rustDatabase?.getLogs(limit) ?: emptyList()
            logs.joinToString("\n") { "[${it.timestamp}] [${it.level}] ${it.message}" }
        } catch (e: Exception) {
            "Failed to retrieve logs: ${e.message}"
        }
    }

    /** Delete all log entries. */
    fun destroyLog(): Boolean {
        return try {
            rustDatabase?.clearLogs()
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Email the log (returns intent data; actual email launch is done by caller). */
    fun getLogForEmail(): String {
        return getLog(mapOf("limit" to 2000))
    }

    /** Prune old logs based on config. */
    fun pruneOldLogs() {
        // Not implemented
    }

    // =========================================================================
    // Private
    // =========================================================================

    private fun logInternal(level: Int, message: String, tag: String) {
        val configLevel = config.getLogLevel()
        if (configLevel == LEVEL_OFF || level > configLevel) return

        // Write to Android logcat
        when (level) {
            LEVEL_ERROR -> Log.e(tag, message)
            LEVEL_WARNING -> Log.w(tag, message)
            LEVEL_INFO -> Log.i(tag, message)
            LEVEL_DEBUG -> Log.d(tag, message)
            LEVEL_VERBOSE -> Log.v(tag, message)
        }

        // Persist to Rust Core Database
        try {
            val levelName = levelToString(level)
            rustDatabase?.insertLog(levelName, message, "plugin")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist log to Rust Database: ${e.message}")
        }
    }
}

