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
import android.view.accessibility.AccessibilityManager
import android.view.animation.AnimationUtils
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import com.example.stealthseal.BiometricService

/**
 * Standalone native PIN entry activity that appears on TOP of the locked app.
 * Does NOT redirect to StealthSeal/MainActivity.
 * Reads PINs from SharedPreferences (synced from Flutter).
 * On correct PIN → finishes itself, locked app is visible underneath.
 * On back press → goes to home screen (cannot bypass).
 */
class AppLockActivity : FragmentActivity() {

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
    private lateinit var patternView: PatternView
    private lateinit var keypadGrid: View
    private lateinit var fingerprintButtonContainer: FrameLayout
    private lateinit var fingerprintHelpText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen, show over lock screen AND prevent bypass via recents/home
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        )
        
        // Prevent system overlays from appearing
        window.setType(WindowManager.LayoutParams.TYPE_APPLICATION)
        
        // Disable screenshot to prevent bypass
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
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
        patternView = findViewById(R.id.patternView)
        keypadGrid = findViewById(R.id.keypadGrid)
        fingerprintButtonContainer = findViewById(R.id.fingerprintButtonContainer)
        fingerprintHelpText = findViewById(R.id.fingerprintHelpText)

        // Enable touch events for custom views
        patternView.isFocusable = true
        patternView.isClickable = true

        // Set up biometric icon
        val lockIcon = findViewById<ImageView>(R.id.lockIcon)
        lockIcon.setColorFilter(Color.WHITE)
        // Change icon to biometric
        lockIcon.setImageResource(android.R.drawable.ic_dialog_info)

        // Set up pattern view callbacks
        patternView.onPatternCompleted = { pattern ->
            Log.d(TAG, "Pattern completed: $pattern, comparing with realPin: $realPin")
            validatePattern(pattern)
        }

        // Set up fingerprint button
        setupFingerprintButton()
    }

    private fun showUnlockMethodUI() {
        // Hide all
        patternLockContainer.visibility = View.GONE
        keypadGrid.visibility = View.VISIBLE

        // Use generic title to keep UI consistent across all apps
        titleText.text = "Unlock Your App"
        
        when {
            unlockPattern == "pattern" -> {
                keypadGrid.visibility = View.GONE
                patternLockContainer.visibility = View.VISIBLE
                patternView.reset()
            }
            else -> {
                updateDots()
            }
        }
    }

    /**
     * Setup fingerprint button - always show regardless of device capability
     * User will see error if device doesn't support biometric
     */
    private fun setupFingerprintButton() {
        Log.d(TAG, "📱 Setting up fingerprint button (always visible)")
        fingerprintButtonContainer.visibility = View.VISIBLE
        fingerprintHelpText.visibility = View.VISIBLE
        
        // Set click listener
        fingerprintButtonContainer.setOnClickListener {
            showBiometricPrompt()
        }
    }

    /**
     * Show biometric authentication prompt (fingerprint/face)
     */
    private fun showBiometricPrompt() {
        Log.d(TAG, "📋 Biometric button tapped - starting authentication...")
        CoroutineScope(Dispatchers.Main).launch {
            try {
                Log.d(TAG, "Calling BiometricService.authenticate()...")
                val isAuthenticated = BiometricService.authenticate(this@AppLockActivity)
                
                Log.d(TAG, "Biometric result: $isAuthenticated")
                
                if (isAuthenticated) {
                    Log.d(TAG, "✅ Biometric authentication successful - unlocking app")
                    
                    // Enable biometric for future use
                    BiometricService.enable(this@AppLockActivity)
                    
                    // Mark as session-unlocked (same as PIN unlock)
                    failedAttempts = 0
                    pinCorrect = true
                    
                    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                    val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
                    val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
                    unlockedSet.add(lockedPackage)
                    prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()
                    
                    Log.d(TAG, "✅ Session-unlocked via biometric: $lockedPackage")
                    
                    // Check if accessibility setup needed
                    val accessibilityEnabled = isAccessibilityServiceEnabled()
                    val hasShownAccessibilityPrompt = prefs.getBoolean("accessibility_prompt_shown", false)
                    
                    if (!accessibilityEnabled && !hasShownAccessibilityPrompt) {
                        Log.d(TAG, "Accessibility is OFF and first login - showing setup prompt")
                        prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()
                        showAccessibilitySetupDialog()
                    } else {
                        onAccessibilitySetupComplete()
                    }
                } else {
                    Log.d(TAG, "❌ Biometric authentication failed - user can still try PIN")
                    // User can still try PIN
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error during biometric authentication: ${e.message}")
                e.printStackTrace()
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

    /**
     * Check if the accessibility service is currently enabled.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        try {
            val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabledServices = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            
            val serviceName = AppAccessibilityService::class.simpleName ?: "AppAccessibilityService"
            val expectedServiceName = "${packageName}/${AppAccessibilityService::class.java.name}"
            return enabledServices.contains(serviceName) ||
                   enabledServices.contains(expectedServiceName)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accessibility status: ${e.message}")
            return false
        }
    }

    /**
     * Show dialog to prompt user to enable accessibility service on first login.
     */
    private fun showAccessibilitySetupDialog() {
        android.app.AlertDialog.Builder(this)
            .setTitle("Enable App Lock Protection")
            .setMessage(
                "To protect your apps, StealthSeal needs Accessibility Service permissions.\n\n" +
                "This allows the app to lock/unlock your selected apps automatically.\n\n" +
                "You can enable this in Settings → Accessibility → StealthSeal"
            )
            .setPositiveButton("Open Settings") { _, _ ->
                openAccessibilitySettings()
                // Finish after opening settings
                Handler(Looper.getMainLooper()).postDelayed({
                    onAccessibilitySetupComplete()
                }, 500)
            }
            .setNegativeButton("Skip for Now") { _, _ ->
                onAccessibilitySetupComplete()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Open device accessibility settings.
     */
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening accessibility settings: ${e.message}")
        }
    }

    /**
     * Called when accessibility setup is complete (either skipped or done).
     */
    private fun onAccessibilitySetupComplete() {
        Log.d(TAG, "Accessibility setup complete")
        
        // Start foreground service to keep app running in background
        AppLockForegroundService.start(this)
        
        // Clear static flags and finish to unlock the app
        isShowing = false
        currentlyBlockedPackage = null
        finish()
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

            // Check if accessibility is currently disabled and first prompt hasn't been shown
            val accessibilityEnabled = isAccessibilityServiceEnabled()
            val hasShownAccessibilityPrompt = prefs.getBoolean("accessibility_prompt_shown", false)
            
            if (!accessibilityEnabled && !hasShownAccessibilityPrompt) {
                Log.d(TAG, "Accessibility is OFF and first login - showing accessibility setup prompt")
                prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()
                
                // Show accessibility permission dialog
                showAccessibilitySetupDialog()
            } else {
                // Accessibility already on or already shown prompt - just unlock
                if (accessibilityEnabled) {
                    Log.d(TAG, "Accessibility already enabled - skipping setup prompt")
                }
                onAccessibilitySetupComplete()
            }
        } else if (enteredPin == decoyPin) {
            // Decoy PIN handling
            failedAttempts = 0
            pinCorrect = true
            Log.d(TAG, "Decoy PIN entered for: $lockedPackage")
            errorText.visibility = View.GONE

            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Decoy dashboard shown for: $lockedPackage")

            // Clear flags and finish
            isShowing = false
            currentlyBlockedPackage = null
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

            // Check if accessibility is currently disabled and first prompt hasn't been shown
            val accessibilityEnabled = isAccessibilityServiceEnabled()
            val hasShownAccessibilityPrompt = prefs.getBoolean("accessibility_prompt_shown", false)
            
            if (!accessibilityEnabled && !hasShownAccessibilityPrompt && realMatch) {  // Only on real PIN first login
                Log.d(TAG, "Accessibility is OFF and first login - showing accessibility setup prompt")
                prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()
                
                showAccessibilitySetupDialog()
            } else {
                // Not first login or decoy pattern or accessibility already on - just unlock
                if (accessibilityEnabled) {
                    Log.d(TAG, "Accessibility already enabled - skipping setup prompt")
                }
                onAccessibilitySetupComplete()
            }
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



    override fun onBackPressed() {
        // Send user to home; mark as dismissed (no unlock) and finish
        if (pinCorrect || isFinishing || isDestroyed) return
        Log.d(TAG, "Back pressed on lock screen - going home and keeping locked")
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        // Mark dismissal without unlock so accessibility can relaunch when returning
        isShowing = false
        currentlyBlockedPackage = null
        dismissedAt = System.currentTimeMillis()
        dismissedPackage = lockedPackage
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle re-launch — only reset UI if it's a DIFFERENT locked app
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
            loadPins()  // Reload pins to get latest unlock_pattern
            showUnlockMethodUI()
            currentlyBlockedPackage = lockedPackage
            Log.d(TAG, "Unlock screen switched to: $appName ($lockedPackage)")
        } else {
                // Same app — reload PINs in case settings changed, then check if UI needs refresh
                val oldPattern = unlockPattern
                loadPins()
                if (oldPattern != unlockPattern) {
                    Log.d(TAG, "Unlock pattern changed from '$oldPattern' to '$unlockPattern', refreshing UI")
                    enteredPin = ""
                    failedAttempts = 0
                    errorText.visibility = View.GONE
                    patternView.reset()
                    showUnlockMethodUI()
                } else {
                    Log.d(TAG, "Unlock screen re-focused for same app: $lockedPackage")
                }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "Lock screen resumed, ensuring it stays active")
        
        // Reload unlock pattern in case it changed
        val oldPattern = unlockPattern
        loadPins()
        if (oldPattern != unlockPattern) {
            Log.d(TAG, "Unlock pattern changed from '$oldPattern' to '$unlockPattern' on resume, refreshing UI")
            enteredPin = ""
            failedAttempts = 0
            errorText.visibility = View.GONE
            patternView.reset()
            showUnlockMethodUI()
        }
    }

    /**
     * Called ONLY when user explicitly presses Home button.
     * NOT called for incoming calls, notifications, or system overlays.
     * This is the correct place to finish the PIN screen on Home press.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // User hit home/recents while entering PIN. Do NOT unlock; simply go home.
        if (pinCorrect || isFinishing || isDestroyed) return

        Log.d(TAG, "User left lock screen (home/recents) - sending to home, keeping app locked")
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        // Do not finish; let accessibility relaunch lock instantly when app returns
    }

    override fun onPause() {
        super.onPause()
        // If not unlocked, keep activity alive; accessibility will re-show if needed
        if (!pinCorrect) {
            Log.d(TAG, "Lock screen paused without unlock - staying alive (no auto-finish)")
        }
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
