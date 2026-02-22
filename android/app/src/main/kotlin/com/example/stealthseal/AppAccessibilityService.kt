package com.example.stealthseal

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Intent
import android.content.SharedPreferences
import android.content.Context
import android.content.pm.PackageManager
import java.util.concurrent.ConcurrentHashMap

class AppAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "🔐AppLockService"
        private val lockedApps = ConcurrentHashMap<String, Boolean>()

        // ── Timestamp when each app was re-locked ──
        // Used to suppress ghost closing events. When user exits an unlocked app
        // (e.g., presses Home), the app sometimes fires TYPE_WINDOW_STATE_CHANGED
        // AFTER the launcher event. Without this, the service sees the re-locked
        // app and launches PIN on exit.
        private val reLockedAt = ConcurrentHashMap<String, Long>()

        // Events from these packages are 100% invisible — no state change at all.
        // Overlays, keyboards, system helpers that should NOT affect lock state.
        private val INVISIBLE_PACKAGES = setOf(
            "com.android.systemui",                // Notifications, status bar, recents
            "android",                             // Android system process
            // Keyboards
            "com.android.inputmethod.latin",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.swiftkey.languageprovider",
            "com.touchtype.swiftkey",
            "com.google.android.gboard",
            // Google system helpers (fire events but are NOT user apps)
            "com.google.android.gms",              // Google Play Services
            "com.google.android.gsf",              // Google Services Framework
            "com.google.android.webview",           // WebView
            "com.android.webview",                  // System WebView
            "com.google.android.trichromelibrary",  // Chrome WebView library
            // System providers
            "com.android.providers.media",
            "com.android.providers.downloads",
            "com.android.providers.contacts",
            "com.android.providers.calendar",
            "com.android.providers.telephony",
            "com.android.documentsui",              // File picker
            "com.android.externalstorage",
            "com.android.shell",
            // OPPO/Realme-specific system helpers
            "com.coloros.safecenter",
            "com.oplus.safecenter",
            "com.heytap.cloud",
        )

        // Apps that should NEVER be locked but ARE real navigation targets
        private val NEVER_LOCKABLE = setOf(
            "com.example.stealthseal",
            "com.android.launcher", "com.android.launcher2", "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher", "com.mi.android.globallauncher",
            "com.oppo.launcher", "com.coloros.launcher", "com.heytap.launcher",
            "com.realme.launcher", "com.oplus.launcher", "com.transsion.hilauncher",
            "com.vivo.launcher", "com.huawei.android.launcher",
            "com.android.settings", "com.android.phone",
            "com.android.server.telecom", "com.android.incallui",
            "com.android.packageinstaller", "com.google.android.packageinstaller",
            "com.android.permissioncontroller", "com.android.providers.settings",
            "com.android.emergency", "com.android.stk",
        )
    }

    // The last REAL foreground app (not overlays, not our PIN screen)
    private var currentUserApp: String? = null

    private var lastLoadTime: Long = 0
    private val RELOAD_INTERVAL_MS = 500

    private var prefsListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "✅ Accessibility Service Connected!")
        loadLockedApps()
        clearAllSessionUnlocks()

        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == "lockedApps") {
                loadLockedApps()
                Log.d(TAG, "📋 Locked apps updated (instant sync)")
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
    }

    private fun loadLockedApps() {
        try {
            val sharedPref = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val lockedAppsStr = sharedPref.getString("lockedApps", "")
            lockedApps.clear()
            if (!lockedAppsStr.isNullOrEmpty()) {
                for (app in lockedAppsStr.split(",")) {
                    val trimmed = app.trim()
                    if (trimmed.isNotEmpty()) lockedApps[trimmed] = true
                }
            }
            Log.d(TAG, "📋 Loaded ${lockedApps.size} locked apps")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error loading locked apps: ${e.message}")
        }
    }

    private fun reloadLockedAppsIfNeeded() {
        val now = System.currentTimeMillis()
        if (now - lastLoadTime >= RELOAD_INTERVAL_MS) {
            loadLockedApps()
            lastLoadTime = now
        }
    }

    private fun isSessionUnlocked(packageName: String): Boolean {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        val str = prefs.getString("sessionUnlockedApps", "") ?: ""
        return str.split(",").any { it == packageName }
    }

    private fun reLockApp(packageName: String) {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        val str = prefs.getString("sessionUnlockedApps", "") ?: ""
        val set = str.split(",").filter { it.isNotEmpty() }.toMutableSet()
        if (set.remove(packageName)) {
            prefs.edit().putString("sessionUnlockedApps", set.joinToString(",")).apply()
            reLockedAt[packageName] = System.currentTimeMillis()
            Log.d(TAG, "🔒 Re-locked: $packageName")
        }
    }

    private fun clearAllSessionUnlocks() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("sessionUnlockedApps", "").apply()
        Log.d(TAG, "🧹 Cleared all session unlocks")
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName.split(".").lastOrNull() ?: packageName
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        reloadLockedAppsIfNeeded()
        val packageName = event.packageName?.toString() ?: return

        // ══════════════════════════════════════════════════════════
        // 1. INVISIBLE — overlays, keyboards, system helpers
        // ══════════════════════════════════════════════════════════
        if (INVISIBLE_PACKAGES.contains(packageName)) return

        // ══════════════════════════════════════════════════════════
        // 2. OUR APP — ignore events from StealthSeal / PIN screen
        // ══════════════════════════════════════════════════════════
        if (packageName == "com.example.stealthseal") return

        // ══════════════════════════════════════════════════════════
        // 3. GHOST EVENT: app was JUST re-locked (closing animation)
        //    When user exits a session-unlocked app (e.g., Chrome)
        //    by pressing Home, the launcher fires first → re-locks
        //    Chrome → then Chrome fires a "ghost" closing event.
        //    Without this check, that ghost would launch a PIN.
        //    1000ms window catches all closing animations.
        // ══════════════════════════════════════════════════════════
        val timeSinceReLock = System.currentTimeMillis() - (reLockedAt[packageName] ?: 0)
        if (timeSinceReLock < 2500) {
            Log.d(TAG, "⏳ Ghost (re-locked ${timeSinceReLock}ms ago): $packageName")
            return
        }

        // ══════════════════════════════════════════════════════════
        // 4. GHOST EVENT: PIN was just dismissed without correct PIN
        //    for THIS specific package. When user presses Home/Back
        //    from PIN, the locked app underneath briefly foregrounds.
        //    Only suppress for the SAME package (so opening a
        //    different locked app right after is not blocked).
        // ══════════════════════════════════════════════════════════
        if (packageName == AppLockActivity.dismissedPackage &&
            System.currentTimeMillis() - AppLockActivity.dismissedAt < 2500) {
            Log.d(TAG, "⏳ Ghost (PIN dismissed ${System.currentTimeMillis() - AppLockActivity.dismissedAt}ms ago): $packageName")
            return
        }

        // ══════════════════════════════════════════════════════════
        // 5. APP TRANSITION — user moved to a different app
        //    ALWAYS re-lock the previous app on any real transition.
        // ══════════════════════════════════════════════════════════
        if (packageName != currentUserApp) {
            val prev = currentUserApp
            if (prev != null && isSessionUnlocked(prev)) {
                reLockApp(prev)
            }
            currentUserApp = packageName
        }

        // ══════════════════════════════════════════════════════════
        // 6. NEVER-LOCKABLE apps — don't try to lock them
        // ══════════════════════════════════════════════════════════
        if (NEVER_LOCKABLE.contains(packageName)) return

        // ══════════════════════════════════════════════════════════
        // 7. NOT IN LOCKED LIST — skip
        // ══════════════════════════════════════════════════════════
        if (!lockedApps.containsKey(packageName)) return

        // ══════════════════════════════════════════════════════════
        // 8. SESSION UNLOCKED — user entered PIN, let them through
        // ══════════════════════════════════════════════════════════
        if (isSessionUnlocked(packageName)) return

        // ══════════════════════════════════════════════════════════
        // 9. PIN ALREADY SHOWING — prevent duplicate
        // ══════════════════════════════════════════════════════════
        if (AppLockActivity.isShowing) {
            Log.d(TAG, "⏳ PIN already showing for ${AppLockActivity.currentlyBlockedPackage}, skip $packageName")
            return
        }

        // ══════════════════════════════════════════════════════════
        // 10. LOCK IT — show PIN screen
        // ══════════════════════════════════════════════════════════
        Log.d(TAG, "🔒 LOCKED: $packageName — showing PIN")
        launchLockScreen(packageName)
    }

    private fun launchLockScreen(packageName: String) {
        try {
            val appName = getAppName(packageName)
            val intent = Intent(this, AppLockActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                           Intent.FLAG_ACTIVITY_CLEAR_TOP or
                           Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            intent.putExtra(AppLockActivity.EXTRA_LOCKED_PACKAGE, packageName)
            intent.putExtra(AppLockActivity.EXTRA_APP_NAME, appName)
            startActivity(intent)
            Log.d(TAG, "✅ PIN launched for: $appName ($packageName)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error launching PIN: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "⚠️ Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (prefsListener != null) {
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
            prefsListener = null
        }
    }
}
