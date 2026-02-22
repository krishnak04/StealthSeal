package com.example.stealthseal

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.LayoutInflater
import android.widget.Button
import android.widget.Switch
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomsheet.BottomSheetDialog

/**
 * Permission dialog helper for showing professional bottom sheet permission requests.
 * Shows Display over other apps + Usage access permissions.
 */
class PermissionBottomSheetHelper(private val activity: Activity) {
    private val TAG = "PermissionBottomSheet"

    /**
     * Show the permission bottom sheet dialog
     * @param onGrantClick Lambda called when user taps "Go to set" button
     */
    fun showPermissionDialog(onGrantClick: (() -> Unit)? = null) {
        try {
            // Create bottom sheet dialog with transparent background
            val bottomSheetDialog = BottomSheetDialog(activity)
            bottomSheetDialog.setContentView(R.layout.permission_bottom_sheet)

            // Get views
            val displayOverAppsToggle = bottomSheetDialog.findViewById<Switch>(R.id.displayOverAppsToggle)
            val usageAccessToggle = bottomSheetDialog.findViewById<Switch>(R.id.usageAccessToggle)
            val goToSettingsButton = bottomSheetDialog.findViewById<Button>(R.id.goToSettingsButton)

            // Set toggle listeners (visual only, disabled state)
            displayOverAppsToggle?.setOnClickListener {
                Log.d(TAG, "Display over apps toggle clicked")
            }

            usageAccessToggle?.setOnClickListener {
                Log.d(TAG, "Usage access toggle clicked")
            }

            // "Go to set" button click handler
            goToSettingsButton?.setOnClickListener {
                Log.d(TAG, "User clicked 'Go to set' button")
                openAppLockSettings()
                bottomSheetDialog.dismiss()
                onGrantClick?.invoke()
            }

            // Configure bottom sheet behavior
            bottomSheetDialog.behavior.isDraggable = false

            // Show with animation
            bottomSheetDialog.show()

            Log.d(TAG, "Permission bottom sheet dialog shown")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing permission dialog: ${e.message}", e)
        }
    }

    /**
     * Open app lock settings (Display over other apps + Usage access)
     */
    private fun openAppLockSettings() {
        try {
            // Open Display over other apps settings
            openDisplayOverAppsSettings()

            // Note: Usage access settings will be handled by the app lock activity
            // or can be triggered separately if needed
            Log.d(TAG, "Opening app lock settings...")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app lock settings: ${e.message}", e)
        }
    }

    /**
     * Open Display over other apps permission settings
     */
    private fun openDisplayOverAppsSettings() {
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            activity.startActivity(intent)
            Log.d(TAG, "Display over other apps settings opened")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening overlay settings: ${e.message}")
            // Fallback: open general settings
            openGeneralSettings()
        }
    }

    /**
     * Open Usage access settings
     */
    fun openUsageAccessSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            activity.startActivity(intent)
            Log.d(TAG, "Usage access settings opened")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening usage access settings: ${e.message}")
            openGeneralSettings()
        }
    }

    /**
     * Fallback: Open general app settings
     */
    private fun openGeneralSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            activity.startActivity(intent)
            Log.d(TAG, "General app settings opened (fallback)")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app settings: ${e.message}")
        }
    }

    /**
     * Check if Display over other apps permission is granted
     */
    fun isDisplayOverAppsGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(activity)
        } else {
            true
        }
    }

    /**
     * Check if Usage access permission is granted
     * Note: This requires checking via the AccessibilityService
     */
    fun isUsageAccessGranted(): Boolean {
        // This would require parsing app usage stats permission
        // For now, return false to prompt user
        return false
    }
}
