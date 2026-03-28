package com.example.stealthseal

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.provider.Settings
import android.util.Base64
import android.util.Log
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.stealthseal.app/applock"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Start foreground service to keep app lock alive when removed from recents
        AppLockForegroundService.start(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register engine for accessibility service (kept for future use)
        FlutterEngineCache.getInstance().put("stealth_engine", flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> handleGetInstalledApps(result)
                    "getCurrentForegroundApp" -> handleGetCurrentForegroundApp(result)
                    "isAccessibilityServiceEnabled" -> handleIsAccessibilityServiceEnabled(result)
                    "setLockedApps" -> {
                        val apps = call.argument<String>("apps") ?: ""
                        val sharedPref = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                        sharedPref.edit()
                            .putString("lockedApps", apps)
                            .putString("sessionUnlockedApps", "")  // Clear all session unlocks
                            .apply()
                        Log.d("MainActivity", "Locked apps synced: $apps (sessions cleared)")
                        result.success(true)
                    }
                    "cachePins" -> {
                        val realPin = call.argument<String>("real_pin") ?: ""
                        val decoyPin = call.argument<String>("decoy_pin") ?: ""
                        val unlockPattern = call.argument<String>("unlock_pattern") ?: "4-digit"
                        
                        // Get location lock settings if available
                        val locationLockEnabled = call.argument<Boolean>("location_lock_enabled") ?: false
                        val trustedLat = call.argument<Double>("trusted_lat") ?: 0.0
                        val trustedLng = call.argument<Double>("trusted_lng") ?: 0.0
                        val trustedRadius = call.argument<Double>("trusted_radius") ?: 200.0
                        
                        // Get time lock settings if available
                        val nightLockEnabled = call.argument<Boolean>("night_lock_enabled") ?: false
                        val nightStartHour = call.argument<Int>("night_start_hour") ?: 22
                        val nightStartMinute = call.argument<Int>("night_start_minute") ?: 0
                        val nightEndHour = call.argument<Int>("night_end_hour") ?: 6
                        val nightEndMinute = call.argument<Int>("night_end_minute") ?: 0
                        
                        val sharedPref = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                        sharedPref.edit()
                            .putString("cached_real_pin", realPin)
                            .putString("cached_decoy_pin", decoyPin)
                            .putString("unlock_pattern", unlockPattern)
                            .putBoolean("locationLockEnabled", locationLockEnabled)
                            .putFloat("trustedLat", trustedLat.toFloat())
                            .putFloat("trustedLng", trustedLng.toFloat())
                            .putFloat("trustedRadius", trustedRadius.toFloat())
                            .putBoolean("nightLockEnabled", nightLockEnabled)
                            .putInt("nightStartHour", nightStartHour)
                            .putInt("nightStartMinute", nightStartMinute)
                            .putInt("nightEndHour", nightEndHour)
                            .putInt("nightEndMinute", nightEndMinute)
                            .apply()
                        Log.d("MainActivity", "PINs cached to SharedPreferences with pattern: $unlockPattern")
                        Log.d("MainActivity", "Location lock cached: enabled=$locationLockEnabled, trusted=($trustedLat, $trustedLng), radius=$trustedRadius")
                        Log.d("MainActivity", "Time lock cached: enabled=$nightLockEnabled, ${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)}")
                        result.success(true)
                    }
                    "requestAccessibilityService" -> {
                        handleRequestAccessibilityService()
                        result.success(true)
                    }
                    "openAccessibilitySettings" -> {
                        handleOpenAccessibilitySettings()
                        result.success(true)
                    }
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName") ?: ""
                        handleLaunchApp(packageName, result)
                    }
                    "getIntruderLogs" -> {
                        handleGetIntruderLogs(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleGetInstalledApps(result: MethodChannel.Result) {
        try {
            Log.d("MainActivity", "Starting to fetch installed apps...")
            val pm = packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null)
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

            Log.d("MainActivity", "Querying intent activities for launcher apps...")
            val resolveInfoList = pm.queryIntentActivities(mainIntent, 0)
            Log.d("MainActivity", "Found ${resolveInfoList.size} installed apps")
            
            val appList = mutableListOf<Map<String, String>>()
            val addedPackages = mutableSetOf<String>()

            for (resolveInfo in resolveInfoList) {
                val packageName = resolveInfo.activityInfo.packageName
                if (addedPackages.contains(packageName)) continue
                addedPackages.add(packageName)

                try {
                    val name = resolveInfo.loadLabel(pm).toString()
                    val iconDrawable = resolveInfo.loadIcon(pm)
                    val bitmap = drawableToBitmap(iconDrawable)

                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    val byteArray = stream.toByteArray()
                    val base64Icon = Base64.encodeToString(byteArray, Base64.NO_WRAP)

                    appList.add(mapOf(
                        "name" to name,
                        "package" to packageName,
                        "icon" to base64Icon
                    ))
                    Log.d("MainActivity", "Added app: $name ($packageName)")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to process app $packageName: ${e.message}")
                }
            }

            Log.d("MainActivity", "Returning ${appList.size} apps to Flutter")
            result.success(appList)
        } catch (e: Exception) {
            Log.e("MainActivity", "ERROR fetching installed apps: ${e.message}")
            e.printStackTrace()
            result.error("ERROR", "Failed to fetch apps: ${e.message}", null)
        }
    }

    private fun handleGetCurrentForegroundApp(result: MethodChannel.Result) {
        try {
            val foregroundApp = getForegroundApp()
            result.success(foregroundApp)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleIsAccessibilityServiceEnabled(result: MethodChannel.Result) {
        try {
            val isEnabled = isAccessibilityServiceEnabled()
            result.success(isEnabled)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleOpenAccessibilitySettings() {
        try {
            Log.d("MainActivity", "Opening accessibility settings...")
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            Log.d("MainActivity", "Accessibility settings opened")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error opening accessibility settings: ${e.message}")
        }
    }

    private fun handleLaunchApp(packageName: String, result: MethodChannel.Result) {
        try {
            Log.d("MainActivity", "Launching app: $packageName")
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                result.success(true)
            } else {
                Log.e("MainActivity", "No launch intent for: $packageName")
                result.error("NO_INTENT", "Cannot launch $packageName", null)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error launching app: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleRequestAccessibilityService() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
            Log.d("MainActivity", "Opened Accessibility Settings")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error opening settings: ${e.message}")
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }

        if (drawable is AdaptiveIconDrawable) {
            val background = drawable.background
            val foreground = drawable.foreground
            val width = 200
            val height = 200

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            background.setBounds(0, 0, width, height)
            background.draw(canvas)

            foreground.setBounds(0, 0, width, height)
            foreground.draw(canvas)

            return bitmap
        }

        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 200
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 200

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)

        return bitmap
    }

    private fun getForegroundApp(): String? {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                currentTime - 1000 * 60,
                currentTime
            )

            if (stats.isNotEmpty()) {
                val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
                sortedStats[0].packageName
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun handleGetIntruderLogs(result: MethodChannel.Result) {
        try {
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val logsString = prefs.getString("intruderLogs", "") ?: ""
            
            val logs = mutableListOf<Map<String, Any>>()
            
            if (logsString.isNotEmpty()) {
                // Parse the logs from SharedPreferences format: "imagePath|timestamp|reason\n"
                val logEntries = logsString.trim().split("\n").filter { it.isNotEmpty() }
                
                for (entry in logEntries) {
                    val parts = entry.split("|")
                    if (parts.size >= 3) {
                        val imagePath = parts[0]
                        val timestamp = parts.getOrNull(1)?.toLongOrNull() ?: System.currentTimeMillis()
                        val reason = parts.getOrNull(2) ?: "Failed Attempt"
                        
                        // Convert timestamp to ISO format
                        val iso8601 = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).apply {
                            timeZone = java.util.TimeZone.getTimeZone("UTC")
                        }.format(java.util.Date(timestamp))
                        
                        val logMap = mapOf<String, Any>(
                            "imagePath" to imagePath,
                            "timestamp" to iso8601,
                            "reason" to reason,
                            "enteredPin" to "***"
                        )
                        logs.add(logMap)
                    }
                }
            }
            
            Log.d("MainActivity", "Returning ${logs.size} intruder logs")
            result.success(logs)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting intruder logs: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val accessibilityEnabled = Settings.Secure.getInt(
                contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                0
            )

            if (accessibilityEnabled == 1) {
                val enabledServices = Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                )
                enabledServices?.contains("com.example.stealthseal/com.example.stealthseal.AppAccessibilityService") ?: false
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
