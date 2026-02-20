package com.example.stealthseal

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache

class AppAccessibilityService : AccessibilityService() {

    companion object {
        private const val CHANNEL = "app_lock_channel"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            Log.d("AppLock", "Foreground App: $packageName")

            val engine = FlutterEngineCache.getInstance()
                .get("stealth_engine")

            engine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL)
                    .invokeMethod("onAppDetected", packageName)
            }
        }
    }

    override fun onInterrupt() {}
}
