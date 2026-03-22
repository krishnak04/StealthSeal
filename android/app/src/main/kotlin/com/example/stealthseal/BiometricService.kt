package com.example.stealthseal

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
import androidx.biometric.BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED
import androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS
import androidx.biometric.BiometricManager.Authenticators
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Biometric authentication service wrapper around AndroidX BiometricPrompt.
 * Handles fingerprint/face recognition on supported devices.
 * Thread-safe with SharedPreferences storage for enable/disable state.
 */
object BiometricService {
    private const val TAG = "BiometricService"
    private const val PREF_NAME = "stealthseal_prefs"
    private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"

    /**
     * Check if device supports biometric authentication (fingerprint or face).
     * Returns true if hardware is available; false otherwise.
     */
    fun isSupported(context: Context): Boolean {
        return try {
            val biometricManager = BiometricManager.from(context)
            when (biometricManager.canAuthenticate(Authenticators.BIOMETRIC_STRONG or Authenticators.BIOMETRIC_WEAK)) {
                BIOMETRIC_SUCCESS -> {
                    Log.d(TAG, "✅ Biometric is supported on this device")
                    true
                }
                BIOMETRIC_ERROR_NO_HARDWARE -> {
                    Log.d(TAG, "❌ No biometric hardware found")
                    false
                }
                BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> {
                    Log.d(TAG, "⚠️ Biometric requires security update")
                    false
                }
                else -> {
                    Log.d(TAG, "❌ Biometric not supported")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking biometric support: ${e.message}")
            false
        }
    }

    /**
     * Check if biometric is enabled in SharedPreferences (user has registered).
     */
    fun isEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            prefs.getBoolean(KEY_BIOMETRIC_ENABLED, false)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking biometric enabled state: ${e.message}")
            false
        }
    }

    /**
     * Enable biometric (user registered) in SharedPreferences.
     */
    fun enable(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, true).apply()
            Log.d(TAG, "✅ Biometric enabled in preferences")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error enabling biometric: ${e.message}")
        }
    }

    /**
     * Disable biometric in SharedPreferences.
     */
    fun disable(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, false).apply()
            Log.d(TAG, "✅ Biometric disabled in preferences")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error disabling biometric: ${e.message}")
        }
    }

    /**
     * Authenticate user with biometric (fingerprint/face).
     * Suspend function that shows BiometricPrompt and returns true on success, false otherwise.
     * Handles all error cases gracefully.
     */
    suspend fun authenticate(activity: FragmentActivity): Boolean = suspendCancellableCoroutine { continuation ->
        Log.d(TAG, "🔐 Starting biometric authentication...")
        
        try {
            // Check if device supports biometric BEFORE showing prompt
            if (!isSupported(activity)) {
                Log.d(TAG, "⚠️ Device does not support biometric - showing error dialog")
                // Show error dialog to user
                androidx.appcompat.app.AlertDialog.Builder(activity)
                    .setTitle("Biometric Not Available")
                    .setMessage("Your device does not have fingerprint or face recognition hardware.")
                    .setPositiveButton("OK") { _, _ ->
                        Log.d(TAG, "User acknowledged no biometric hardware")
                        continuation.resume(false)
                    }
                    .setCancelable(false)
                    .show()
                return@suspendCancellableCoroutine
            }

            val executor = ContextCompat.getMainExecutor(activity)
            
            val callback = object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    Log.d(TAG, "✅ Biometric authentication successful!")
                    continuation.resume(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.d(TAG, "❌ Biometric error ($errorCode): $errString")
                    continuation.resume(false)
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.d(TAG, "❌ Biometric authentication failed - wrong fingerprint/face")
                    continuation.resume(false)
                }
            }

            val biometricPrompt = BiometricPrompt(
                activity,
                executor,
                callback
            )

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Unlock Your App")
                .setSubtitle("Use your fingerprint or face")
                .setNegativeButtonText("Cancel")
                .build()

            Log.d(TAG, "📋 Showing biometric prompt to user...")
            biometricPrompt.authenticate(promptInfo)

        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception during biometric authentication: ${e.message}")
            e.printStackTrace()
            continuation.resume(false)
        }
    }
}
