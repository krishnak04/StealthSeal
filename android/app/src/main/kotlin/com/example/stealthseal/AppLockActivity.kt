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
    private var unlockPattern: String = "4-digit"
    private var pinLength: Int = 4

    private lateinit var dot1: View
    private lateinit var dot2: View
    private lateinit var dot3: View
    private lateinit var dot4: View
    private lateinit var dot5: View
    private lateinit var dot6: View
    private lateinit var errorText: TextView
    private val dots = mutableListOf<View>()

    private lateinit var titleText: TextView
    private lateinit var patternLockContainer: View
    private lateinit var knockCodeContainer: View
    private lateinit var patternView: PatternView
    private lateinit var knockCodeView: KnockCodeView
    private lateinit var keypadGrid: View

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
    }

    private fun loadPins() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        realPin = prefs.getString("cached_real_pin", null)
        decoyPin = prefs.getString("cached_decoy_pin", null)
        unlockPattern = prefs.getString("unlock_pattern", "4-digit") ?: "4-digit"
        
        // Determine PIN length based on pattern
        pinLength = if (unlockPattern.contains("6")) 6 else 4

        Log.d(TAG, "╔════════════════════════════════════════╗")
        Log.d(TAG, "║        PINS LOADED FROM STORAGE        ║")
        Log.d(TAG, "╚════════════════════════════════════════╝")
        Log.d(TAG, "Unlock pattern: '$unlockPattern'")
        Log.d(TAG, "PIN length to expect: $pinLength")
        Log.d(TAG, "Real PIN:   '$realPin'")
        if (realPin != null) {
            Log.d(TAG, "  └─ Length: ${realPin!!.length}, Bytes: ${realPin!!.toByteArray().joinToString(",")}")
        }
        Log.d(TAG, "Decoy PIN:  '$decoyPin'")
        if (decoyPin != null) {
            Log.d(TAG, "  └─ Length: ${decoyPin!!.length}, Bytes: ${decoyPin!!.toByteArray().joinToString(",")}")
        }

        if (realPin == null) {
            Log.e(TAG, "❌ No PINs found in SharedPreferences! App lock cannot validate.")
        }
    }

    private fun initViews() {
        dot1 = findViewById(R.id.dot1)
        dot2 = findViewById(R.id.dot2)
        dot3 = findViewById(R.id.dot3)
        dot4 = findViewById(R.id.dot4)
        dot5 = findViewById(R.id.dot5)
        dot6 = findViewById(R.id.dot6)
        errorText = findViewById(R.id.errorText)
        titleText = findViewById(R.id.titleText)
        
        // Add dots to list in order
        dots.addAll(listOf(dot1, dot2, dot3, dot4, dot5, dot6))
        
        // Initialize unlock method containers
        patternLockContainer = findViewById(R.id.patternLockContainer)
        knockCodeContainer = findViewById(R.id.knockCodeContainer)
        patternView = findViewById(R.id.patternView)
        knockCodeView = findViewById(R.id.knockCodeView)
        keypadGrid = findViewById(R.id.keypadGrid)

        // Enable touch events for custom views
        patternView.isFocusable = true
        patternView.isClickable = true
        knockCodeView.isFocusable = true
        knockCodeView.isClickable = true

        // Modern lock icon is already styled in the layout
        val lockIcon = findViewById<ImageView>(R.id.lockIcon)
        lockIcon.setColorFilter(Color.WHITE)

        // Set up pattern view callbacks
        patternView.onPatternCompleted = { pattern ->
            Log.d(TAG, "Pattern completed: $pattern, comparing with realPin: $realPin")
            validatePattern(pattern)
        }

        // Set up knock code view callbacks
        knockCodeView.onKnockCodeCompleted = { code ->
            Log.d(TAG, "Knock code completed: $code, comparing with realPin: $realPin")
            validateKnockCode(code)
        }

        // Show appropriate unlock method UI
        showUnlockMethodUI()
    }

    private fun showUnlockMethodUI() {
        // Hide all
        patternLockContainer.visibility = View.GONE
        knockCodeContainer.visibility = View.GONE
        keypadGrid.visibility = View.VISIBLE

        when {
            unlockPattern == "pattern" -> {
                titleText.text = "Draw Your Pattern"
                keypadGrid.visibility = View.GONE
                patternLockContainer.visibility = View.VISIBLE
                patternView.reset()
            }
            unlockPattern == "knock-code" -> {
                titleText.text = "Tap the Zones"
                keypadGrid.visibility = View.GONE
                knockCodeContainer.visibility = View.VISIBLE
                knockCodeView.reset()
            }
            else -> {
                titleText.text = "Enter the PIN"
                updateDots()
            }
        }
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
        if (enteredPin.length >= pinLength) return

        enteredPin += digit
        updateDots()

        if (enteredPin.length == pinLength) {
            validatePin()
        }
    }

    private fun onDelete() {
        if (enteredPin.isEmpty()) return
        enteredPin = enteredPin.substring(0, enteredPin.length - 1)
        updateDots()
    }

    private fun updateDots() {
        val filledColor = Color.parseColor("#00BCD4") // Cyan
        val emptyStroke = Color.parseColor("#8000BCD4")

        for (i in dots.indices) {
            val dot = dots[i]
            val bg = GradientDrawable()
            bg.shape = GradientDrawable.OVAL

            if (i < pinLength) {
                // Show this dot
                dot.visibility = View.VISIBLE
                
                if (i < enteredPin.length) {
                    bg.setColor(filledColor)
                    bg.setStroke(2, filledColor)
                } else {
                    bg.setColor(Color.TRANSPARENT)
                    bg.setStroke(2, emptyStroke)
                }
            } else {
                // Hide dots beyond pinLength
                dot.visibility = View.GONE
            }

            dot.background = bg
        }
    }

    private fun validatePin() {
        if (enteredPin == realPin) {
            // Correct PIN — only real PIN unlocks apps
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

    private fun validatePattern(pattern: String) {
        val entered = pattern.trim()
        
        Log.d(TAG, "╔════════════════════════════════════════╗")
        Log.d(TAG, "║       PATTERN VALIDATION CHECK        ║")
        Log.d(TAG, "╚════════════════════════════════════════╝")
        Log.d(TAG, "Entered: '$entered'")
        Log.d(TAG, "  Length: ${entered.length}")
        Log.d(TAG, "  Bytes: ${entered.toByteArray().joinToString(",")}")
        Log.d(TAG, "")
        Log.d(TAG, "Real PIN: '$realPin'")
        if (realPin != null) {
            Log.d(TAG, "  Length: ${realPin!!.length}")
            Log.d(TAG, "  Bytes: ${realPin!!.toByteArray().joinToString(",")}")
        }
        Log.d(TAG, "")
        Log.d(TAG, "Decoy PIN: '$decoyPin'")
        if (decoyPin != null) {
            Log.d(TAG, "  Length: ${decoyPin!!.length}")
            Log.d(TAG, "  Bytes: ${decoyPin!!.toByteArray().joinToString(",")}")
        }
        
        if (entered.isEmpty() || realPin == null) {
            Log.e(TAG, "❌ VALIDATION FAILED: Empty entered or no realPin!")
            errorText.visibility = View.VISIBLE
            errorText.text = "Invalid pattern"
            return
        }

        val realMatch = (entered == realPin)
        val decoyMatch = (entered == decoyPin)
        
        Log.d(TAG, "")
        Log.d(TAG, "Comparison:")
        Log.d(TAG, "  entered == realPin? $realMatch")
        Log.d(TAG, "  entered == decoyPin? $decoyMatch")

        if (realMatch || decoyMatch) {
            Log.d(TAG, "")
            Log.d(TAG, "✅ CORRECT! Pattern matches!")
            failedAttempts = 0
            errorText.visibility = View.GONE

            // Mark as session-unlocked in SharedPreferences
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Session-unlocked: $lockedPackage")

            finish()
        } else {
            failedAttempts++
            Log.d(TAG, "")
            Log.d(TAG, "❌ INCORRECT! Pattern does not match.")
            Log.d(TAG, "Attempt #$failedAttempts")

            try {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(200)
            } catch (e: Exception) { /* ignore */ }

            errorText.visibility = View.VISIBLE
            errorText.text = "Wrong pattern (${3 - failedAttempts} left)"

            Handler(Looper.getMainLooper()).postDelayed({
                patternView.reset()
                errorText.visibility = View.GONE
            }, 1000)
        }
    }

    private fun validateKnockCode(code: String) {
        val entered = code.trim()
        
        Log.d(TAG, "╔════════════════════════════════════════╗")
        Log.d(TAG, "║      KNOCK CODE VALIDATION CHECK      ║")
        Log.d(TAG, "╚════════════════════════════════════════╝")
        Log.d(TAG, "Entered: '$entered'")
        Log.d(TAG, "  Length: ${entered.length}")
        Log.d(TAG, "  Bytes: ${entered.toByteArray().joinToString(",")}")
        Log.d(TAG, "")
        Log.d(TAG, "Real PIN: '$realPin'")
        if (realPin != null) {
            Log.d(TAG, "  Length: ${realPin!!.length}")
            Log.d(TAG, "  Bytes: ${realPin!!.toByteArray().joinToString(",")}")
        }
        Log.d(TAG, "")
        Log.d(TAG, "Decoy PIN: '$decoyPin'")
        if (decoyPin != null) {
            Log.d(TAG, "  Length: ${decoyPin!!.length}")
            Log.d(TAG, "  Bytes: ${decoyPin!!.toByteArray().joinToString(",")}")
        }

        if (entered.isEmpty() || realPin == null) {
            Log.e(TAG, "❌ VALIDATION FAILED: Empty entered or no realPin!")
            errorText.visibility = View.VISIBLE
            errorText.text = "Invalid knock code"
            return
        }

        val realMatch = (entered == realPin)
        val decoyMatch = (entered == decoyPin)
        
        Log.d(TAG, "")
        Log.d(TAG, "Comparison:")
        Log.d(TAG, "  entered == realPin? $realMatch")
        Log.d(TAG, "  entered == decoyPin? $decoyMatch")

        if (realMatch || decoyMatch) {
            Log.d(TAG, "")
            Log.d(TAG, "✅ CORRECT! Knock code matches!")
            failedAttempts = 0
            errorText.visibility = View.GONE

            // Mark as session-unlocked in SharedPreferences
            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Session-unlocked: $lockedPackage")

            finish()
        } else {
            failedAttempts++
            Log.d(TAG, "")
            Log.d(TAG, "❌ INCORRECT! Knock code does not match.")
            Log.d(TAG, "Attempt #$failedAttempts")

            try {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(200)
            } catch (e: Exception) { /* ignore */ }

            errorText.visibility = View.VISIBLE
            errorText.text = "Wrong knock code (${3 - failedAttempts} left)"

            Handler(Looper.getMainLooper()).postDelayed({
                knockCodeView.reset()
                errorText.visibility = View.GONE
            }, 1000)
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
                patternView.reset()
                knockCodeView.reset()
                showUnlockMethodUI()
                currentlyBlockedPackage = lockedPackage
                Log.d(TAG, "Unlock screen switched to: $appName ($lockedPackage)")
            } else {
                // Same app — just bring to front, don't reset entry
                Log.d(TAG, "Unlock screen re-focused for same app: $lockedPackage")
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
