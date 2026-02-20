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

        val showLockOverlay = intent.getBooleanExtra("show_lock_overlay", false)
        val lockedPackage = intent.getStringExtra("locked_package")

        if (showLockOverlay && lockedPackage != null) {
            Log.d("MainActivity", "🔒 Lock overlay mode: $lockedPackage")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register engine for accessibility service
        FlutterEngineCache.getInstance().put("stealth_engine", flutterEngine)

        val showLockOverlay = intent.getBooleanExtra("show_lock_overlay", false)
        val lockedPackage = intent.getStringExtra("locked_package")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> handleGetInstalledApps(result)
                    "getCurrentForegroundApp" -> handleGetCurrentForegroundApp(result)
                    "isAccessibilityServiceEnabled" -> handleIsAccessibilityServiceEnabled(result)
                    "setLockedApps" -> {
                        val apps = call.argument<String>("apps") ?: ""
                        val sharedPref = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                        sharedPref.edit().putString("lockedApps", apps).apply()
                        Log.d("MainActivity", "✅ Locked apps synced: $apps")
                        result.success(true)
                    }
                    "requestAccessibilityService" -> handleRequestAccessibilityService()
                    else -> result.notImplemented()
                }
            }

        // If lock overlay, notify Flutter
        if (showLockOverlay && lockedPackage != null) {
            try {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("showLockOverlay", lockedPackage)
                Log.d("MainActivity", "✅ showLockOverlay sent: $lockedPackage")
            } catch (e: Exception) {
                Log.e("MainActivity", "❌ Error: ${e.message}")
            }
        }
    }

    private fun handleGetInstalledApps(result: MethodChannel.Result) {
        try {
            val pm = packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null)
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

            val resolveInfoList = pm.queryIntentActivities(mainIntent, 0)
            val appList = mutableListOf<Map<String, String>>()
            val addedPackages = mutableSetOf<String>()

            for (resolveInfo in resolveInfoList) {
                val packageName = resolveInfo.activityInfo.packageName
                if (addedPackages.contains(packageName)) continue
                addedPackages.add(packageName)

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
            }

            result.success(appList)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
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

    private fun handleRequestAccessibilityService() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
            Log.d("MainActivity", "✅ Opened Accessibility Settings")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error opening settings: ${e.message}")
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
                enabledServices?.contains("com.example.stealthseal/.AppAccessibilityService") ?: false
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
