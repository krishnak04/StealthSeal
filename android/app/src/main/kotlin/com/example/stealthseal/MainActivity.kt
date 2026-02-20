package com.example.stealthseal

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.stealthseal.app/applock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method == "getInstalledApps") {

                    try {
                        val pm = packageManager
                        val mainIntent = Intent(Intent.ACTION_MAIN, null)
                        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

                        val resolveInfoList = pm.queryIntentActivities(mainIntent, 0)

                        val appList = mutableListOf<Map<String, String>>()
                        val addedPackages = mutableSetOf<String>()

                        for (resolveInfo in resolveInfoList) {

                            val packageName = resolveInfo.activityInfo.packageName

                            // Avoid duplicates
                            if (addedPackages.contains(packageName)) continue
                            addedPackages.add(packageName)

                            val name = resolveInfo.loadLabel(pm).toString()
                            val iconDrawable = resolveInfo.loadIcon(pm)

                            val bitmap = drawableToBitmap(iconDrawable)

                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            val byteArray = stream.toByteArray()
                            val base64Icon =
                                Base64.encodeToString(byteArray, Base64.NO_WRAP)

                            appList.add(
                                mapOf(
                                    "name" to name,
                                    "package" to packageName,
                                    "icon" to base64Icon
                                )
                            )
                        }

                        result.success(appList)

                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }

                } else {
                    result.notImplemented()
                }
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
}
