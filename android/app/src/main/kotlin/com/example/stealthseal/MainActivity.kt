package com.example.stealthseal

import android.app.usage.UsageStatsManager
import android.content.ComponentName
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
                    "removeIntruderLog" -> {
                        val imagePath = call.argument<String>("imagePath") ?: ""
                        val timestamp = call.argument<String>("timestamp") ?: ""
                        handleRemoveIntruderLog(imagePath, timestamp, result)
                    }
                    "setStealthDisguise" -> {
                        val mode = call.argument<String>("mode") ?: "normal"
                        val packageName = call.argument<String>("packageName") ?: ""
                        handleSetStealthDisguise(mode, packageName, result)
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
            val validLogEntries = mutableListOf<String>()
            
            if (logsString.isNotEmpty()) {
                // Parse the logs from SharedPreferences format: "imagePath|timestamp|reason|pin\n"
                val logEntries = logsString.trim().split("\n").filter { it.isNotEmpty() }
                
                for (entry in logEntries) {
                    val parts = entry.split("|")
                    if (parts.size >= 3) {
                        val imagePath = parts[0]
                        val timestamp = parts.getOrNull(1)?.toLongOrNull() ?: System.currentTimeMillis()
                        val reason = parts.getOrNull(2) ?: "Failed Attempt"
                        val enteredPin = parts.getOrNull(3) ?: "***"  // Extract PIN from new format
                        
                        // Check if image file exists - only include valid logs
                        val imageFile = java.io.File(imagePath)
                        if (!imageFile.exists()) {
                            Log.w("MainActivity", "⚠️ Skipping log with missing image: $imagePath")
                            // Don't add to validLogEntries - effectively deletes it
                            continue
                        }
                        
                        // Convert timestamp to ISO format using device local timezone (matches image time)
                        val iso8601 = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).apply {
                            timeZone = java.util.TimeZone.getDefault()
                        }.format(java.util.Date(timestamp))
                        
                        val logMap = mapOf<String, Any>(
                            "imagePath" to imagePath,
                            "timestamp" to iso8601,
                            "reason" to reason,
                            "enteredPin" to enteredPin  // Use extracted PIN
                        )
                        logs.add(logMap)
                        validLogEntries.add(entry)  // Keep this entry
                    }
                }
                
                // If we found invalid entries, clean up SharedPreferences
                if (validLogEntries.size < logEntries.size) {
                    Log.d("MainActivity", "🧹 Cleaning up ${logEntries.size - validLogEntries.size} invalid log entries from SharedPreferences")
                    val cleanedLogsString = if (validLogEntries.isNotEmpty()) {
                        validLogEntries.joinToString("\n") + "\n"
                    } else {
                        ""
                    }
                    prefs.edit().putString("intruderLogs", cleanedLogsString).apply()
                    Log.d("MainActivity", "✅ SharedPreferences cleaned up. Remaining logs: ${validLogEntries.size}")
                }
            }
            
            Log.d("MainActivity", "Returning ${logs.size} valid intruder logs")
            result.success(logs)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting intruder logs: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleRemoveIntruderLog(imagePath: String, timestamp: String, result: MethodChannel.Result) {
        try {
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val logsString = prefs.getString("intruderLogs", "") ?: ""
            
            if (logsString.isNotEmpty()) {
                // Parse all log entries and filter out the one to remove
                val logEntries = logsString.trim().split("\n").filter { it.isNotEmpty() }
                
                // Convert timestamp ISO format back to milliseconds for comparison
                val timestampMillis = try {
                    java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).apply {
                        timeZone = java.util.TimeZone.getTimeZone("UTC")
                    }.parse(timestamp)?.time ?: System.currentTimeMillis().toString().toLong()
                } catch (e: Exception) {
                    timestamp.toLongOrNull() ?: System.currentTimeMillis()
                }
                
                Log.d("MainActivity", "Removing log: imagePath=$imagePath, timestamp=$timestamp (millis=$timestampMillis)")
                
                // Filter out the log entry that matches both imagePath and timestamp
                val updatedEntries = logEntries.filter { entry ->
                    val parts = entry.split("|")
                    if (parts.size >= 2) {
                        val entryPath = parts[0]
                        val entryTimestamp = parts[1].toLongOrNull() ?: 0L
                        !(entryPath == imagePath && (entryTimestamp.toString() == timestamp || java.util.Date(entryTimestamp).time.toString() == timestamp))
                    } else {
                        true
                    }
                }
                
                Log.d("MainActivity", "Filtered ${logEntries.size} entries to ${updatedEntries.size} entries")
                
                // Save updated logs back to SharedPreferences
                val updatedLogsString = if (updatedEntries.isNotEmpty()) {
                    updatedEntries.joinToString("\n") + "\n"
                } else {
                    ""
                }
                
                prefs.edit().putString("intruderLogs", updatedLogsString).apply()
                
                Log.d("MainActivity", "✅ Intruder log removed successfully")
                result.success(true)
            } else {
                Log.d("MainActivity", "Logs are already empty")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error removing intruder log: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleSetStealthDisguise(mode: String, packageName: String, result: MethodChannel.Result) {
        try {
            when (mode) {
                "normal" -> {
                    // Remove disguise preference
                    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                    prefs.edit().remove("disguisePackage").apply()
                    
                    Log.d("MainActivity", "✅ App set to NORMAL mode")
                    result.success(true)
                }
                "disguise" -> {
                    // Create a fake shortcut with selected app's icon and name
                    createFakeAppShortcut(packageName, result)
                }
                else -> {
                    result.error("INVALID_MODE", "Unknown stealth mode: $mode", null)
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error setting stealth disguise: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun createFakeAppShortcut(targetPackageName: String, result: MethodChannel.Result) {
        try {
            val pm = packageManager
            
            // Get the target app's info (the app we're disguising as)
            val targetAppInfo = pm.getApplicationInfo(targetPackageName, 0)
            val targetAppLabel = pm.getApplicationLabel(targetAppInfo).toString()
            val targetAppIcon = pm.getApplicationIcon(targetPackageName)
            
            // Convert icon to bitmap
            val bitmap = drawableToBitmap(targetAppIcon)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val iconData = stream.toByteArray()
            
            // Create intent that opens StealthSeal (our real app)
            val launchIntent = Intent(Intent.ACTION_MAIN)
            launchIntent.setPackage(packageName)  // StealthSeal's package
            launchIntent.setClass(this, MainActivity::class.java)
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            
            // Create the shortcut
            val shortcutIntent = Intent("com.android.launcher.action.INSTALL_SHORTCUT")
            shortcutIntent.putExtra(Intent.EXTRA_SHORTCUT_INTENT, launchIntent)
            shortcutIntent.putExtra(Intent.EXTRA_SHORTCUT_NAME, targetAppLabel)
            shortcutIntent.putExtra(Intent.EXTRA_SHORTCUT_ICON, bitmap)
            shortcutIntent.putExtra("duplicate", false)  // Don't create duplicates
            
            // Send the shortcut creation request
            sendBroadcast(shortcutIntent)
            
            // Save preference
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("disguisePackage", targetPackageName).apply()
            
            Log.d("MainActivity", "✅ Fake shortcut created: '$targetAppLabel' points to StealthSeal")
            result.success(true)
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error creating fake shortcut: ${e.message}")
            e.printStackTrace()
            result.error("ERROR", "Failed to create shortcut: ${e.message}", null)
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
