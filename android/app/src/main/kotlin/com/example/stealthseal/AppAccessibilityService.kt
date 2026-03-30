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

        private val reLockedAt = ConcurrentHashMap<String, Long>()

        private val justUnlockedAt = ConcurrentHashMap<String, Long>()
        private const val UNLOCK_GRACE_PERIOD_MS = 0  

        private val INVISIBLE_PACKAGES = setOf(
            "com.android.systemui",                
            "android",                             
            
            "com.android.inputmethod.latin",
            "com.google.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.swiftkey.languageprovider",
            "com.touchtype.swiftkey",
            "com.google.android.gboard",
            
            "com.google.android.gms",              
            "com.google.android.gsf",              
            "com.google.android.webview",           
            "com.android.webview",                  
            "com.google.android.trichromelibrary",  
            
            "com.android.providers.media",
            "com.android.providers.downloads",
            "com.android.providers.contacts",
            "com.android.providers.calendar",
            "com.android.providers.telephony",
            "com.android.documentsui",              
            "com.android.externalstorage",
            "com.android.shell",
            
            "com.coloros.safecenter",
            "com.oplus.safecenter",
            "com.heytap.cloud",
        )

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
        
        return Service.START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        
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
            justUnlockedAt.remove(packageName)  
            Log.d(TAG, "Re-locked: $packageName")
        }
    }

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
        justUnlockedAt.clear()  
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

        if (INVISIBLE_PACKAGES.contains(packageName)) return

        if (packageName == "com.example.stealthseal") return

        val cls = event.className?.toString() ?: ""
        if (cls.contains("Recents", true) || cls.contains("Overview", true) || cls.contains("TaskSwitcher", true)) {
            Log.d(TAG, "📋 Recents switcher opened (class=$cls) - re-locking app: $currentUserApp")
            
            if (currentUserApp != null && isSessionUnlocked(currentUserApp!!) && !NEVER_LOCKABLE.contains(currentUserApp)) {
                reLockApp(currentUserApp!!)
                Log.d(TAG, "   ✅ Re-locked: $currentUserApp before entering recents")
            }
            return
        }

        if (packageName != currentUserApp) {
            val prev = currentUserApp

            if (NEVER_LOCKABLE.contains(packageName)) {
                Log.d(TAG, "🏠 HOME/LAUNCHER detected: $packageName - clearing ALL session unlocks")
                clearAllSessionUnlocks()

                if (prev != null && isSessionUnlocked(prev) && !NEVER_LOCKABLE.contains(prev)) {
                    reLockApp(prev)
                    Log.d(TAG, "   ✅ Also re-locked previous app: $prev")
                }
            }
            
            else if (prev != null && isSessionUnlocked(prev) && !NEVER_LOCKABLE.contains(prev)) {
                reLockApp(prev)
                Log.d(TAG, "✅ RE-LOCKED when exiting: $prev → $packageName")

                reLockUnlockedAppsNotInForeground(packageName)
            }
            
            currentUserApp = packageName
        }

        if (NEVER_LOCKABLE.contains(packageName)) return

        if (!lockedApps.containsKey(packageName)) return

        val isUnlocked = isSessionUnlocked(packageName)
        Log.d(TAG, "📱 $packageName - isSessionUnlocked? $isUnlocked")
        
        if (isUnlocked) {
            
            justUnlockedAt[packageName] = System.currentTimeMillis()
            Log.d(TAG, "   ✅ User already unlocked $packageName in this session, allowing")
            return
        } else {
            
            Log.d(TAG, "   🔒 $packageName NOT in sessionUnlockedApps - will show PIN screen")
        }

        if (AppLockActivity.isShowing) {
            if (AppLockActivity.currentlyBlockedPackage == packageName) {
                
                Log.d(TAG, "⏭️  PIN already showing for $packageName, skip duplicate")
                return  
            } else {

                Log.d(TAG, "⏭️  Different app PIN can show: prev=${AppLockActivity.currentlyBlockedPackage}, new=$packageName")
            }
        }

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
            Log.d(TAG, "🔐 LOCKED: Showing PIN screen for $appName ($packageName)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error launching PIN: ${e.message}")
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
