package com.example.stealthseal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

/**
 * Helper class for managing StealthSeal notifications.
 */
object NotificationHelper {
    private const val TAG = "NotificationHelper"
    
    // Notification channels
    const val CHANNEL_SECURITY = "stealthseal_security_alerts"
    const val CHANNEL_APP_LOCK = "stealthseal_applock_channel"
    
    // Notification IDs
    const val ID_ACCESSIBILITY_DISABLED = 2001
    const val ID_APP_REMOVED_FROM_ACTIVE = 2002
    const val ID_ACCESSIBILITY_PROMPT = 2003

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java)
            
            // Security alerts channel
            val securityChannel = NotificationChannel(
                CHANNEL_SECURITY,
                "Security Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Important security notifications for StealthSeal"
                enableVibration(true)
                enableLights(true)
            }
            manager.createNotificationChannel(securityChannel)
            Log.d(TAG, "Security alerts channel created")
        }
    }

    /**
     * Show notification when accessibility service is disabled.
     */
    fun notifyAccessibilityDisabled(context: Context) {
        createNotificationChannels(context)
        
        val openAccessibilityIntent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
        openAccessibilityIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        val pendingIntent = PendingIntent.getActivity(
            context,
            ID_ACCESSIBILITY_DISABLED,
            openAccessibilityIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_SECURITY)
            .setContentTitle("⚠️ App Lock Disabled")
            .setContentText("StealthSeal Accessibility Service is OFF. Your apps are no longer protected.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_lock_lock,
                "Re-enable",
                pendingIntent
            )
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(ID_ACCESSIBILITY_DISABLED, notification)
        Log.d(TAG, "Accessibility disabled notification sent")
    }

    /**
     * Show notification when user tries to remove app from active apps.
     */
    fun notifyAppRemovedFromActive(context: Context) {
        createNotificationChannels(context)
        
        val openManageAppsIntent = Intent(android.provider.Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS)
        openManageAppsIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        val pendingIntent = PendingIntent.getActivity(
            context,
            ID_APP_REMOVED_FROM_ACTIVE,
            openManageAppsIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_SECURITY)
            .setContentTitle("🚨 App Lock Stopping")
            .setContentText("You tried to remove StealthSeal from active apps. App lock has stopped.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(ID_APP_REMOVED_FROM_ACTIVE, notification)
        Log.d(TAG, "App removed from active notification sent")
    }

    /**
     * Cancel notifications.
     */
    fun cancelNotification(context: Context, notificationId: Int) {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.cancel(notificationId)
        Log.d(TAG, "Notification $notificationId cancelled")
    }
}
