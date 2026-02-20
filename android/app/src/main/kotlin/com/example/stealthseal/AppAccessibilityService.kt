package com.example.stealthseal

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Intent
import android.content.SharedPreferences
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache
import java.util.concurrent.ConcurrentHashMap

class AppAccessibilityService : AccessibilityService() {

    companion object {
        private const val CHANNEL = "com.stealthseal.app/applock"
        private const val TAG = "🔐AppLockService"
        private val lockedApps = ConcurrentHashMap<String, Boolean>()
    }

    private var lastPackageName: String? = null
    private var lastLoadTime: Long = 0
    private val RELOAD_INTERVAL_MS = 1000 // Reload every 1 second

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "✅ Accessibility Service Connected!")
        loadLockedApps()
    }

    private fun loadLockedApps() {
        try {
            val sharedPref = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val lockedAppsStr = sharedPref.getString("lockedApps", "")
            
            lockedApps.clear() // Clear old list
            
            if (lockedAppsStr != null && lockedAppsStr.isNotEmpty()) {
                val apps = lockedAppsStr.split(",")
                for (app in apps) {
                    if (app.trim().isNotEmpty()) {
                        lockedApps[app.trim()] = true
                    }
                }
                Log.d(TAG, "📋 Loaded ${lockedApps.size} locked apps: $lockedApps")
            } else {
                Log.d(TAG, "📋 No locked apps found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error loading locked apps: ${e.message}")
        }
    }

    private fun reloadLockedAppsIfNeeded() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastLoadTime >= RELOAD_INTERVAL_MS) {
            Log.d(TAG, "🔄 Reloading locked apps list...")
            loadLockedApps()
            lastLoadTime = currentTime
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) {
            Log.d(TAG, "❌ Event is null")
            return
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // ✅ Reload locked apps list periodically
            reloadLockedAppsIfNeeded()
            
            val packageName = event.packageName?.toString()
            
            if (packageName == null) {
                Log.d(TAG, "❌ Package name is null")
                return
            }

            // Skip StealthSeal itself
            if (packageName == "com.example.stealthseal") {
                return
            }

            Log.d(TAG, "📱 Event received for: $packageName | IsLocked: ${lockedApps.containsKey(packageName)}")

            // Avoid duplicate events
            if (packageName == lastPackageName) {
                Log.d(TAG, "⏭️  Skipping duplicate: $packageName")
                return
            }
            lastPackageName = packageName

            // Check if app is locked locally
            if (lockedApps.containsKey(packageName)) {
                Log.d(TAG, "🔒 LOCKED APP DETECTED (Direct): $packageName")
                launchLockScreen(packageName)
                return
            }

            // Try Flutter engine method (if app is foreground)
            try {
                val engine = FlutterEngineCache.getInstance().get("stealth_engine")
                
                if (engine != null) {
                    Log.d(TAG, "✅ Flutter engine available, using method channel")
                    val messenger = engine.dartExecutor.binaryMessenger
                    MethodChannel(messenger, CHANNEL).invokeMethod("onAppDetected", packageName)
                    Log.d(TAG, "✅ Method invoked: $packageName")
                }
            } catch (e: Exception) {
                Log.d(TAG, "ℹ️ Flutter not available (expected when app is backgrounded): ${e.message}")
            }
        }
    }

    private fun launchLockScreen(packageName: String) {
        try {
            Log.d(TAG, "🔓 Launching lock screen overlay for: $packageName")
            
            val intent = Intent(this, LockScreenOverlayActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                           Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                           Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            intent.putExtra("locked_package", packageName)
            
            startActivity(intent)
            Log.d(TAG, "✅ Lock screen overlay started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error launching lock screen: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "⚠️ Accessibility Service Interrupted")
    }
}

