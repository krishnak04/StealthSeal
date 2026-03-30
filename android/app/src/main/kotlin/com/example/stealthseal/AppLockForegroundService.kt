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

class AppLockForegroundService : Service() {

    companion object {
        private const val TAG = "AppLockFgService"
        private const val CHANNEL_ID = "stealthseal_applock_channel"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Foreground service start requested")
        }

        fun stop(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            context.stopService(intent)
            Log.d(TAG, "Foreground service stop requested")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Foreground service created")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        AccessibilityMonitorService.start(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Foreground service started")
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed (app swiped from recents) - service stays alive")
        
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Lock Protection",
                NotificationManager.IMPORTANCE_LOW  
            ).apply {
                description = "Keeps StealthSeal app lock running in the background"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET  
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    private fun buildNotification(): Notification {
        
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
            .setContentText("By turning off the app you are turning off the app lock")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)  
            .build()
    }
}
