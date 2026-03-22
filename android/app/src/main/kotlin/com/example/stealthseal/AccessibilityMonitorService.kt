package com.example.stealthseal

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager

/**
 * Service that monitors whether the Accessibility Service is enabled.
 * If it gets disabled (manually or by removing from active apps), notifies the user.
 */
class AccessibilityMonitorService : Service() {

    companion object {
        private const val TAG = "AccessibilityMonitor"
        
        fun start(context: Context) {
            val intent = Intent(context, AccessibilityMonitorService::class.java)
            context.startService(intent)
            Log.d(TAG, "Accessibility monitor service start requested")
        }

        fun stop(context: Context) {
            val intent = Intent(context, AccessibilityMonitorService::class.java)
            context.stopService(intent)
            Log.d(TAG, "Accessibility monitor service stop requested")
        }
    }

    private var isAccessibilityEnabled = false
    private val handler = Handler(Looper.getMainLooper())
    private var monitoringRunnable: Runnable? = null
    private val MONITOR_INTERVAL_MS = 5000  // Check every 5 seconds

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Accessibility monitor service created")
        checkAccessibilityStatus()
        startMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Accessibility monitor service started")
        startMonitoring()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        Log.d(TAG, "Accessibility monitor service destroyed")
    }

    private fun startMonitoring() {
        if (monitoringRunnable != null) return
        
        monitoringRunnable = object : Runnable {
            override fun run() {
                checkAccessibilityStatus()
                handler.postDelayed(this, MONITOR_INTERVAL_MS.toLong())
            }
        }
        handler.post(monitoringRunnable!!)
        Log.d(TAG, "Accessibility monitoring started (every ${MONITOR_INTERVAL_MS}ms)")
    }

    private fun stopMonitoring() {
        if (monitoringRunnable != null) {
            handler.removeCallbacks(monitoringRunnable!!)
            monitoringRunnable = null
            Log.d(TAG, "Accessibility monitoring stopped")
        }
    }

    private fun checkAccessibilityStatus() {
        try {
            val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabled = accessibilityManager.isEnabled
            
            // Check if our specific accessibility service is enabled
            val isOurServiceEnabled = isOurAccessibilityServiceEnabled()
            
            if (isAccessibilityEnabled && !isOurServiceEnabled) {
                // Was enabled, now disabled
                Log.w(TAG, "❌ Accessibility service is NOW DISABLED!")
                isAccessibilityEnabled = false
                
                NotificationHelper.notifyAccessibilityDisabled(this)
                
                // Store in preferences that accessibility was disabled
                val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("accessibility_was_disabled", true).apply()
            } else if (!isAccessibilityEnabled && isOurServiceEnabled) {
                // Was disabled, now enabled
                Log.d(TAG, "✅ Accessibility service is NOW ENABLED")
                isAccessibilityEnabled = true
                
                // Clear the flag
                val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("accessibility_was_disabled", false).apply()
                
                // Cancel any previous notification
                NotificationHelper.cancelNotification(this, NotificationHelper.ID_ACCESSIBILITY_DISABLED)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accessibility status: ${e.message}")
        }
    }

    private fun isOurAccessibilityServiceEnabled(): Boolean {
        try {
            val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            
            val serviceName = AppAccessibilityService::class.simpleName ?: "AppAccessibilityService"
            val expectedServiceName = "${packageName}/${AppAccessibilityService::class.java.name}"
            return enabledServices.contains(serviceName) ||
                   enabledServices.contains(expectedServiceName)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if our service is enabled: ${e.message}")
            return false
        }
    }
}
