package com.example.stealthseal

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.WindowManager

class LockScreenOverlayActivity : Activity() {

    companion object {
        private const val TAG = "🔐LockOverlay"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "✅ Lock Screen Overlay Activity Created")
        
        // Make window transparent and always on top
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
        
        // Get locked app info
        val lockedPackage = intent.getStringExtra("locked_package") ?: "Unknown"
        Log.d(TAG, "🔒 Showing lock overlay for: $lockedPackage")
        
        // Launch MainActivity with special flag to show overlay
        val mainIntent = Intent(this, MainActivity::class.java)
        mainIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        mainIntent.putExtra("locked_package", lockedPackage)
        mainIntent.putExtra("show_lock_overlay", true)
        
        startActivity(mainIntent)
        
        // Close this overlay activity
        finish()
    }
}
