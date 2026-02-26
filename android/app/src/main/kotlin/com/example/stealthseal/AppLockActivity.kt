package com.example.stealthseal

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.view.animation.AnimationUtils
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Standalone native PIN entry activity that appears on TOP of the locked app.
 * Does NOT redirect to StealthSeal/MainActivity.
 * Reads PINs from SharedPreferences (synced from Flutter).
 * On correct PIN → finishes itself, locked app is visible underneath.
 * On back press → goes to home screen (cannot bypass).
 */
class AppLockActivity : Activity() {

    companion object {
        private const val TAG = "AppLockActivity"
        const val EXTRA_LOCKED_PACKAGE = "locked_package"
        const val EXTRA_APP_NAME = "app_name"

        // ── Static flag: the ONLY reliable way to know if PIN screen is alive ──
        @Volatile
        var isShowing = false
            private set

        @Volatile
        var currentlyBlockedPackage: String? = null
            private set

        // ── Timestamp of when PIN was dismissed WITHOUT correct PIN ──
        @Volatile
        var dismissedAt: Long = 0L
            private set

        // ── Which package the PIN was dismissed for ──
        // Package-specific so that dismissing Chrome's PIN doesn't block
        // opening WhatsApp's PIN right after.
        @Volatile
        var dismissedPackage: String? = null
            private set
    }

    private var enteredPin = ""
    private var realPin: String? = null
    private var decoyPin: String? = null
    private var lockedPackage: String = ""
    private var appName: String = ""
    private var failedAttempts = 0
    private var pinCorrect = false  // Track whether user entered correct PIN

    private lateinit var dot1: View
    private lateinit var dot2: View
    private lateinit var dot3: View
    private lateinit var dot4: View
    private lateinit var errorText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen, show over lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        setContentView(R.layout.activity_app_lock)

        // Get locked app info
        lockedPackage = intent.getStringExtra(EXTRA_LOCKED_PACKAGE) ?: ""
        appName = intent.getStringExtra(EXTRA_APP_NAME) ?: lockedPackage.split(".").lastOrNull() ?: "App"

        Log.d(TAG, "PIN screen opened for: $appName ($lockedPackage)")

        // Mark PIN screen as active
        isShowing = true
        currentlyBlockedPackage = lockedPackage

        // Load PINs from SharedPreferences
        loadPins()

        // Initialize views
        initViews()
        setupKeypad()
        updateDots()
    }

    private fun loadPins() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        realPin = prefs.getString("cached_real_pin", null)
        decoyPin = prefs.getString("cached_decoy_pin", null)

        Log.d(TAG, "PINs loaded: real=${realPin != null}, decoy=${decoyPin != null}")

        if (realPin == null) {
            Log.e(TAG, "No PINs found in SharedPreferences! App lock cannot validate.")
        }
    }

    private fun initViews() {
        dot1 = findViewById(R.id.dot1)
        dot2 = findViewById(R.id.dot2)
        dot3 = findViewById(R.id.dot3)
        dot4 = findViewById(R.id.dot4)
        errorText = findViewById(R.id.errorText)
        
        // Modern lock icon is already styled in the layout
        val lockIcon = findViewById<ImageView>(R.id.lockIcon)
        lockIcon.setColorFilter(Color.WHITE)
    }

    private fun setupKeypad() {
        val buttons = listOf(
            findViewById<Button>(R.id.btn0),
            findViewById<Button>(R.id.btn1),
            findViewById<Button>(R.id.btn2),
            findViewById<Button>(R.id.btn3),
            findViewById<Button>(R.id.btn4),
            findViewById<Button>(R.id.btn5),
            findViewById<Button>(R.id.btn6),
            findViewById<Button>(R.id.btn7),
            findViewById<Button>(R.id.btn8),
            findViewById<Button>(R.id.btn9)
        )

        for (button in buttons) {
            button.setOnClickListener {
                onKeyPress(button.text.toString())
            }
        }

        findViewById<ImageButton>(R.id.btnDelete).setOnClickListener {
            onDelete()
        }
    }

    private fun onKeyPress(digit: String) {
        if (realPin == null) return
        if (enteredPin.length >= 4) return

        enteredPin += digit
        updateDots()

        if (enteredPin.length == 4) {
            validatePin()
        }
    }

    private fun onDelete() {
        if (enteredPin.isEmpty()) return
        enteredPin = enteredPin.substring(0, enteredPin.length - 1)
        updateDots()
    }

    private fun updateDots() {
        val dots = listOf(dot1, dot2, dot3, dot4)
        val filledColor = Color.parseColor("#00BCD4") // Cyan
        val emptyStroke = Color.parseColor("#8000BCD4")

        for (i in dots.indices) {
            val bg = GradientDrawable()
            bg.shape = GradientDrawable.OVAL

            if (i < enteredPin.length) {
                bg.setColor(filledColor)
                bg.setStroke(2, filledColor)
            } else {
                bg.setColor(Color.TRANSPARENT)
                bg.setStroke(2, emptyStroke)
            }

            dots[i].background = bg
        }
    }

    private fun validatePin() {
        if (enteredPin == realPin || enteredPin == decoyPin) {
            // Correct PIN
            failedAttempts = 0
            pinCorrect = true
            Log.d(TAG, "Correct PIN entered for: $lockedPackage")

            errorText.visibility = View.GONE

            // Mark as session-unlocked in SharedPreferences
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Session-unlocked: $lockedPackage (total: ${unlockedSet.size})")

            // Finish this activity — the locked app is still underneath
            finish()
        } else {
            // Wrong PIN
            failedAttempts++
            Log.d(TAG, "Wrong PIN attempt #$failedAttempts for: $lockedPackage")

            // Vibrate
            try {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(200)
            } catch (e: Exception) { /* ignore */ }

            // Show error
            errorText.visibility = View.VISIBLE
            if (failedAttempts >= 3) {
                errorText.text = "Multiple failed attempts detected"
                // Reset counter but keep showing warning  
                failedAttempts = 0
            } else {
                errorText.text = "Wrong PIN (${3 - failedAttempts} attempts left)"
            }

            // Shake the dots
            val dotsContainer = findViewById<LinearLayout>(R.id.pinDotsContainer)
            try {
                val shake = AnimationUtils.loadAnimation(this, android.R.anim.fade_in)
                dotsContainer.startAnimation(shake)
            } catch (e: Exception) { /* ignore */ }

            // Clear PIN after a short delay
            Handler(Looper.getMainLooper()).postDelayed({
                enteredPin = ""
                updateDots()
            }, 300)
        }
    }

    override fun onBackPressed() {
        // Don't allow back to bypass — go to home screen instead
        val homeIntent = Intent(Intent.ACTION_MAIN)
        homeIntent.addCategory(Intent.CATEGORY_HOME)
        homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(homeIntent)
        finish()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Handle re-launch — only reset UI if it's a DIFFERENT locked app
        if (intent != null) {
            val newPackage = intent.getStringExtra(EXTRA_LOCKED_PACKAGE) ?: ""
            val newAppName = intent.getStringExtra(EXTRA_APP_NAME) ?: newPackage.split(".").lastOrNull() ?: "App"
            if (newPackage.isNotEmpty() && newPackage != lockedPackage) {
                // Different app — reset everything
                lockedPackage = newPackage
                appName = newAppName
                enteredPin = ""
                failedAttempts = 0
                pinCorrect = false
                errorText.visibility = View.GONE
                updateDots()
                currentlyBlockedPackage = lockedPackage
                Log.d(TAG, "PIN screen switched to: $appName ($lockedPackage)")
            } else {
                // Same app — just bring to front, don't reset PIN entry
                Log.d(TAG, "PIN screen re-focused for same app: $lockedPackage")
            }
        }
    }

    /**
     * Called ONLY when user explicitly presses Home button.
     * NOT called for incoming calls, notifications, or system overlays.
     * This is the correct place to finish the PIN screen on Home press.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d(TAG, "User pressed Home from PIN screen, finishing")
        // Go Home explicitly BEFORE finish to minimize the window where
        // the locked app is briefly foreground
        val homeIntent = Intent(Intent.ACTION_MAIN)
        homeIntent.addCategory(Intent.CATEGORY_HOME)
        homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(homeIntent)
        finish()
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "PIN screen paused, keeping alive")
    }

    override fun onDestroy() {
        super.onDestroy()
        isShowing = false
        currentlyBlockedPackage = null
        if (!pinCorrect) {
            dismissedAt = System.currentTimeMillis()
            dismissedPackage = lockedPackage
            Log.d(TAG, "PIN dismissed without correct PIN for: $lockedPackage")
        } else {
            Log.d(TAG, "PIN destroyed after correct PIN for: $lockedPackage")
        }
    }
}
