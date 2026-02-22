package com.example.stealthseal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Foreground service that keeps StealthSeal alive in the background.
 * This ensures the AppLockActivity can launch without restarting the 
 * entire app process (which would show the StealthSeal lock screen first).
 * 
 * Shows a minimal persistent notification so Android doesn't kill the process.
 */
class AppLockForegroundService : Service() {

    companion object {
        private const val TAG = "🔐AppLockFgService"
        private const val CHANNEL_ID = "stealthseal_applock_channel"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "✅ Foreground service start requested")
        }

        fun stop(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            context.stopService(intent)
            Log.d(TAG, "🛑 Foreground service stop requested")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ Foreground service created")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "✅ Foreground service started")
        // Return START_STICKY so Android restarts the service if killed
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "📱 Task removed (app swiped from recents) — service stays alive")
        // Service continues running, no need to do anything special
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Lock Protection",
                NotificationManager.IMPORTANCE_LOW  // Low importance = no sound, minimal visibility
            ).apply {
                description = "Keeps StealthSeal app lock running in the background"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET  // Hidden on lock screen
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created")
        }
    }

    private fun buildNotification(): Notification {
        // Tapping notification opens StealthSeal
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("StealthSeal Active")
            .setContentText("App lock protection is running")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)  // Cannot be swiped away
            .build()
    }
}
