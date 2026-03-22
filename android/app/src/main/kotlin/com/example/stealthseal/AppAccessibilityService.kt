package com.example.stealthseal

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Intent
import android.content.SharedPreferences
import android.content.Context
import android.content.pm.PackageManager
import android.app.Service
import java.util.concurrent.ConcurrentHashMap

class AppAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppLockService"
        private val lockedApps = ConcurrentHashMap<String, Boolean>()

        // ── Timestamp when each app was re-locked ──
        // Used to suppress ghost closing events. When user exits an unlocked app
        // (e.g., presses Home), the app sometimes fires TYPE_WINDOW_STATE_CHANGED
        // AFTER the launcher event. Without this, the service sees the re-locked
        // app and launches PIN on exit.
        private val reLockedAt = ConcurrentHashMap<String, Long>()

        // ── Timestamp when each app was just unlocked ──
        // Used to prevent PIN from being re-launched immediately after successful unlock
        // Provides a grace period for the APP to foreground and stabilize
        private val justUnlockedAt = ConcurrentHashMap<String, Long>()
        private const val UNLOCK_GRACE_PERIOD_MS = 0  // No grace period; relock immediately

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
        Log.d(TAG, "Accessibility Service Connected!")
        loadLockedApps()

        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == "lockedApps") {
                loadLockedApps()
                Log.d(TAG, "Locked apps updated (instant sync)")
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ensure service restarts if killed by the system
        return Service.START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Service should keep running even when app is swiped from recents
        Log.d(TAG, "App removed from recents — service still running")
        super.onTaskRemoved(rootIntent)
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
            Log.d(TAG, "Loaded ${lockedApps.size} locked apps")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading locked apps: ${e.message}")
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
            justUnlockedAt.remove(packageName)  // Clear grace period when re-locking
            Log.d(TAG, "Re-locked: $packageName")
        }
    }

    /**
     * Re-lock any unlocked apps that are not currently in the foreground.
     * This ensures apps are locked as soon as they lose focus.
     */
    private fun reLockUnlockedAppsNotInForeground(currentForegroundApp: String) {
        try {
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val unlockedAppsStr = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedApps = unlockedAppsStr.split(",").filter { it.isNotEmpty() }
            
            for (unlockedApp in unlockedApps) {
                if (unlockedApp != currentForegroundApp && !NEVER_LOCKABLE.contains(unlockedApp)) {
                    reLockApp(unlockedApp)
                    Log.d(TAG, "🔒 Auto re-locked background unlocked app: $unlockedApp")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error re-locking background apps: ${e.message}")
        }
    }

    private fun clearAllSessionUnlocks() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("sessionUnlockedApps", "").apply()
        justUnlockedAt.clear()  // Clear all grace periods
        Log.d(TAG, "Cleared all session unlocks")
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
        // 2.5 RECENTS OVERVIEW — ignore while user is in recents switcher
        // Prevents lock UI from appearing while recents grid is shown.
        // ══════════════════════════════════════════════════════════
        val cls = event.className?.toString() ?: ""
        if (cls.contains("Recents", true) || cls.contains("Overview", true) || cls.contains("TaskSwitcher", true)) {
            Log.d(TAG, "In recents/overview (class=$cls), skipping lock launch")
            return
        }

        // No ghost suppression: lock immediately on any foreground change or return

        // ══════════════════════════════════════════════════════════
        // 5. APP TRANSITION — user moved to a different app
        //    ALWAYS re-lock the previous app on any real transition.
        // ══════════════════════════════════════════════════════════
        if (packageName != currentUserApp) {
            val prev = currentUserApp
            
            // Re-lock previous app when user leaves it (for security - requires PIN again)
            if (prev != null && isSessionUnlocked(prev) && !NEVER_LOCKABLE.contains(prev)) {
                reLockApp(prev)
                Log.d(TAG, "✅ RE-LOCKED when exiting: $prev → $packageName")
            }
            
            // Also check and re-lock any other unlocked locked apps that are not current
            reLockUnlockedAppsNotInForeground(packageName)
            
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
        if (isSessionUnlocked(packageName)) {
            // Mark this app as just unlocked to prevent PIN re-launch
            justUnlockedAt[packageName] = System.currentTimeMillis()
            return
        }

        // ══════════════════════════════════════════════════════════
        // No grace period: always allow lock to show immediately on return

        // ══════════════════════════════════════════════════════════
        // 9. PIN ALREADY SHOWING — prevent duplicate
        // ══════════════════════════════════════════════════════════
        if (AppLockActivity.isShowing) {
            Log.d(TAG, "PIN already showing for ${AppLockActivity.currentlyBlockedPackage}, skip $packageName")
            return
        }

        // ══════════════════════════════════════════════════════════
        // 10. LOCK IT — show PIN screen
        // ══════════════════════════════════════════════════════════
        Log.d(TAG, "LOCKED: $packageName - showing PIN")
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
            Log.d(TAG, "PIN launched for: $appName ($packageName)")
        } catch (e: Exception) {
            Log.e(TAG, "Error launching PIN: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service Interrupted")
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
