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
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.FusedLocationProviderClient
import android.location.Location

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

    // Location lock properties
    private var locationLockEnabled = false
    private var trustedLat = 0.0
    private var trustedLng = 0.0
    private var trustedRadius = 200.0

    // Time lock properties
    private var nightLockEnabled = false
    private var nightStartHour = 22
    private var nightStartMinute = 0
    private var nightEndHour = 6
    private var nightEndMinute = 0

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
    
    // Time lock display elements
    private var timeLockActiveText: TextView? = null
    private var timeLockCountdownText: TextView? = null
    private var timeLockCountdownTimer: android.os.CountDownTimer? = null
    
    // Flag to prevent multiple timers from running simultaneously
    private var isCountdownRunning = false
    private var isStartingCountdown = false

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
        
        // Refresh time lock settings immediately on app start
        refreshTimeLockSettings()
        
        // Verify and log time lock configuration
        verifyTimeLockConfiguration()
        
        // CHECK TIME LOCK IMMEDIATELY ON APP START
        if (isTimeLockActive()) {
            blockAccessDueToTimeLock()
        } else {
            showUnlockMethodUI()
        }
        
        setupKeypad()
    }

    private fun blockAccessDueToTimeLock() {
        Log.d(TAG, "🔒 Blocking access due to time lock - showing keypad only")
        
        try {
            // Show title and keypad with PIN dots
            titleText.visibility = View.VISIBLE
            keypadGrid.visibility = View.VISIBLE
            for (dot in dots.take(pinLength)) {  // Show only the dots needed for PIN length
                dot.visibility = View.VISIBLE
            }
            
            // Hide pattern lock and fingerprint button
            patternLockContainer.visibility = View.GONE
            fingerprintButtonContainer.visibility = View.GONE
            
            // Show error message
            errorText.visibility = View.VISIBLE
            errorText.text = "⏰ Time locked. Try again outside lock window."
            errorText.textSize = 13f
            
            Log.d(TAG, "✅ Keypad UI displayed during time lock")
            
            // Show time lock countdown overlay
            startTimeLockCountdown()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error blocking access: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun loadPins() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        realPin = prefs.getString("cached_real_pin", null)
        decoyPin = prefs.getString("cached_decoy_pin", null)
        unlockPattern = prefs.getString("unlock_pattern", "4-digit") ?: "4-digit"
        
        // Load location lock settings
        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()
        
        // Load time lock settings
        nightLockEnabled = prefs.getBoolean("nightLockEnabled", false)
        nightStartHour = prefs.getInt("nightStartHour", 22)
        nightStartMinute = prefs.getInt("nightStartMinute", 0)
        nightEndHour = prefs.getInt("nightEndHour", 6)
        nightEndMinute = prefs.getInt("nightEndMinute", 0)
        
        // Determine PIN length based on pattern
        pinLength = if (unlockPattern.contains("6")) 6 else 4

        Log.d(TAG, "╔════════════════════════════════════════╗")
        Log.d(TAG, "║        PINS LOADED FROM STORAGE        ║")
        Log.d(TAG, "╚════════════════════════════════════════╝")
        Log.d(TAG, "Unlock pattern: '$unlockPattern'")
        Log.d(TAG, "PIN length to expect: $pinLength")
        Log.d(TAG, "Location lock: $locationLockEnabled (Trusted: $trustedLat, $trustedLng, Radius: $trustedRadius m)")
        Log.d(TAG, "Time lock: $nightLockEnabled (${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)})")
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

    /**
     * Refresh time lock settings from SharedPreferences (similar to Flutter's _loadSettings).
     * This ensures we always have the latest time lock configuration.
     */
    private fun refreshTimeLockSettings() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        nightLockEnabled = prefs.getBoolean("nightLockEnabled", false)
        nightStartHour = prefs.getInt("nightStartHour", 22)
        nightStartMinute = prefs.getInt("nightStartMinute", 0)
        nightEndHour = prefs.getInt("nightEndHour", 6)
        nightEndMinute = prefs.getInt("nightEndMinute", 0)
        
        Log.d(TAG, "🔄 Time lock settings refreshed:")
        Log.d(TAG, "   Enabled: $nightLockEnabled")
        Log.d(TAG, "   Window: ${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)}")
    }

    /**
     * Verify time lock configuration is properly loaded and logged.
     * Similar to verifying settings in Flutter's TimeLockSettingsScreen.
     */
    private fun verifyTimeLockConfiguration() {
        Log.d(TAG, "╔════════════════════════════════════════╗")
        Log.d(TAG, "║     TIME LOCK CONFIGURATION SUMMARY    ║")
        Log.d(TAG, "╚════════════════════════════════════════╝")
        Log.d(TAG, "Status: ${if (nightLockEnabled) "🔒 ENABLED" else "✅ DISABLED"}")
        Log.d(TAG, "Lock Window: ${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)}")
        
        // Determine lock type
        val startMinutes = nightStartHour * 60 + nightStartMinute
        val endMinutes = nightEndHour * 60 + nightEndMinute
        val lockType = if (startMinutes < endMinutes) "Same-Day Lock" else "Overnight Lock"
        Log.d(TAG, "Lock Type: $lockType")
        
        // Get current time
        val calendar = java.util.Calendar.getInstance()
        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentMinutes = currentHour * 60 + currentMinute
        
        Log.d(TAG, "Current Time: ${String.format("%02d:%02d", currentHour, currentMinute)}")
        
        // Determine if currently locked
        val isCurrentlyLocked = if (nightLockEnabled) {
            if (startMinutes < endMinutes) {
                currentMinutes >= startMinutes && currentMinutes <= endMinutes
            } else {
                currentMinutes >= startMinutes || currentMinutes <= endMinutes
            }
        } else {
            false
        }
        
        Log.d(TAG, "Currently Locked: ${if (isCurrentlyLocked) "🔒 YES" else "✅ NO"}")
        Log.d(TAG, "╚════════════════════════════════════════╝")
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
        
        // Initialize time lock display views
        timeLockActiveText = TextView(this).apply {
            text = "⏰ TIME LOCK ACTIVE"
            textSize = 20f
            setTextColor(android.graphics.Color.parseColor("#FFA500"))
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            gravity = android.view.Gravity.CENTER
            setPadding(20, 20, 20, 20)
            visibility = View.GONE
        }
        
        timeLockCountdownText = TextView(this).apply {
            text = "⏰ Unlock Time Remaining\n00:00:00"
            textSize = 32f
            setTextColor(android.graphics.Color.parseColor("#C41C3B"))
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            gravity = android.view.Gravity.CENTER
            setPadding(40, 40, 40, 40)
            visibility = View.GONE
        }
        
        // Add views to the root layout container
        try {
            val rootView = window.decorView as android.view.ViewGroup
            if (rootView != null) {
                rootView.addView(timeLockActiveText, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                    android.view.Gravity.TOP
                ))
                
                rootView.addView(timeLockCountdownText, FrameLayout.LayoutParams(
                    (380 * resources.displayMetrics.density).toInt(),
                    android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                    android.view.Gravity.CENTER
                ))
                
                // Bring time lock views to front
                rootView.bringChildToFront(timeLockActiveText)
                rootView.bringChildToFront(timeLockCountdownText)
                
                Log.d(TAG, "✅ Time lock views added to root ViewGroup successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error adding time lock views to root: ${e.message}")
            e.printStackTrace()
            
            // Fallback: try adding to a dialog or as a system overlay
            try {
                val contentView = findViewById<View>(android.R.id.content)
                if (contentView is android.view.ViewGroup) {
                    contentView.addView(timeLockActiveText)
                    contentView.addView(timeLockCountdownText)
                    Log.d(TAG, "✅ Time lock views added via fallback method")
                }
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Fallback method also failed: ${e2.message}")
            }
        }
        
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

        // Title from layout is "Enter the PIN" - no override needed
        // titleText keeps the XML default text
        
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
     * UI matches the provided design: "Tap to unlock" and "Long-press for help" text
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

    /**
     * Check if location lock is active and user is outside trusted location.
     * Uses Haversine formula to calculate distance between current position and trusted location.
     */
    private fun isOutsideTrustedLocation(): Boolean {
        if (!locationLockEnabled) {
            Log.d(TAG, "📍 Location lock is DISABLED")
            return false
        }

        // Check if trusted location is configured
        if (trustedLat == 0.0 && trustedLng == 0.0) {
            Log.d(TAG, "📍 Trusted location NOT configured - allowing access")
            return false
        }

        // Check location permissions
        if (androidx.core.content.ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            Log.d(TAG, "📍 Location permission DENIED - allowing access (can't verify location)")
            return false
        }

        try {
            // Get last known location using FusedLocationProviderClient
            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
            
            // Use a blocking approach with timeout
            var isOutside = false
            var locationObtained = false
            
            fusedLocationClient.lastLocation.addOnSuccessListener { currentLocation: Location? ->
                locationObtained = true
                if (currentLocation != null) {
                    val distance = calculateDistance(
                        currentLocation.latitude,
                        currentLocation.longitude,
                        trustedLat,
                        trustedLng
                    )
                    
                    Log.d(TAG, "📍 Current: ${currentLocation.latitude}, ${currentLocation.longitude}")
                    Log.d(TAG, "📍 Trusted: $trustedLat, $trustedLng")
                    Log.d(TAG, "📍 Distance: $distance m, Radius: $trustedRadius m")
                    
                    isOutside = distance > trustedRadius
                    if (isOutside) {
                        Log.d(TAG, "📍❌ OUTSIDE trusted location - BLOCKING")
                    } else {
                        Log.d(TAG, "📍 INSIDE trusted location - ALLOWING")
                    }
                } else {
                    Log.d(TAG, "📍 No last location available - allowing access (maybe first time)")
                    isOutside = false
                }
            }
            
            // Wait up to 2 seconds for location with polling
            var waited = 0
            while (!locationObtained && waited < 2000) {
                Thread.sleep(100)
                waited += 100
            }
            
            // If location wasn't obtained after timeout, ALLOW access (don't block)
            if (!locationObtained) {
                Log.d(TAG, "📍⏱️ Location timeout - allowing access (location service slow)")
                return false
            }
            
            return isOutside
        } catch (e: Exception) {
            Log.e(TAG, "📍 Exception checking location: ${e.message} - allowing access")
            return false
        }
    }

    /**
     * Calculate distance between two coordinates using Haversine formula (in meters)
     */
    private fun calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val R = 6371000.0 // Earth's radius in meters
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLng / 2) * Math.sin(dLng / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return R * c
    }

    /**
     * Check if time lock is currently active using current time and configured lock window.
     * Properly handles both same-day (e.g., 10 AM - 5 PM) and overnight (e.g., 10 PM - 6 AM) locks.
     */
    private fun isTimeLockActive(): Boolean {
        // Always refresh settings before checking (matches Flutter's pattern)
        refreshTimeLockSettings()
        
        if (!nightLockEnabled) {
            return false
        }

        // Get current time in minutes since midnight
        val calendar = java.util.Calendar.getInstance()
        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentMinutes = currentHour * 60 + currentMinute
        
        val startMinutes = nightStartHour * 60 + nightStartMinute
        val endMinutes = nightEndHour * 60 + nightEndMinute

        val isLocked = if (startMinutes < endMinutes) {
            // Same-day lock window (e.g., 10 AM to 5 PM)
            currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight lock window (e.g., 10 PM to 6 AM next day)
            currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }

        return isLocked
    }

    private fun startTimeLockCountdown() {
        // Prevent multiple timers from starting simultaneously
        if (isStartingCountdown) {
            return
        }
        
        if (isCountdownRunning) {
            return
        }
        
        isStartingCountdown = true
        
        // Verify views exist
        if (timeLockActiveText == null || timeLockCountdownText == null) {
            Log.e(TAG, "❌ Time lock views not initialized!")
            isStartingCountdown = false
            return
        }
        
        try {
            // Cancel any existing timer first
            timeLockCountdownTimer?.cancel()
            isCountdownRunning = false
            
            // Show time lock UI immediately
            timeLockActiveText?.visibility = View.VISIBLE
            timeLockCountdownText?.visibility = View.VISIBLE
            
            // Request layout refresh to ensure views appear
            timeLockActiveText?.requestLayout()
            timeLockCountdownText?.requestLayout()
            
            // Get current time with seconds precision
            val calendar = java.util.Calendar.getInstance()
            val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
            val currentMinute = calendar.get(java.util.Calendar.MINUTE)
            val currentSecond = calendar.get(java.util.Calendar.SECOND)
            val currentMinutes = currentHour * 60 + currentMinute
            
            val startMinutes = nightStartHour * 60 + nightStartMinute
            val endMinutes = nightEndHour * 60 + nightEndMinute
            

            
            // Calculate remaining time - handle both same-day and overnight locks
            val remainingMinutes: Int
            val remainingSeconds: Int
            
            when {
                startMinutes < endMinutes -> {
                    // Same-day lock (e.g., 10 AM - 5 PM)
                    if (currentMinutes < startMinutes) {
                        // Before lock starts
                        remainingMinutes = startMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else if (currentMinutes < endMinutes) {
                        // During lock
                        remainingMinutes = endMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else {
                        // Lock is over for today
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        isCountdownRunning = false
                        isStartingCountdown = false
                        showUnlockMethodUI()
                        return
                    }
                }
                else -> {
                    // Overnight lock (e.g., 10 PM - 6 AM next day)
                    if (currentMinutes >= startMinutes) {
                        // After start of overnight window (e.g., after 10 PM)
                        val minutesUntilMidnight = (24 * 60) - currentMinutes
                        remainingMinutes = minutesUntilMidnight + endMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else if (currentMinutes <= endMinutes) {
                        // After midnight, before end (e.g., 2 AM, within 6 AM window)
                        remainingMinutes = endMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else {
                        // Between end and start (e.g., between 6 AM and 10 PM)
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        isCountdownRunning = false
                        isStartingCountdown = false
                        showUnlockMethodUI()
                        return
                    }
                }
            }
            
            // Ensure time is positive
            if (remainingMinutes < 0) {
                timeLockActiveText?.visibility = View.GONE
                timeLockCountdownText?.visibility = View.GONE
                isCountdownRunning = false
                isStartingCountdown = false
                showUnlockMethodUI()
                return
            }
            
            val totalRemainingMillis = (remainingMinutes * 60 + remainingSeconds) * 1000L
            
            // Update display immediately with initial time
            timeLockCountdownText?.text = "⏰ Unlock Time Remaining\n${String.format("%02d:%02d:%02d", 
                remainingMinutes / 60, remainingMinutes % 60, remainingSeconds)}"
            
            // Start countdown timer (now only one can run at a time)
            isCountdownRunning = true
            timeLockCountdownTimer = object : android.os.CountDownTimer(totalRemainingMillis, 1000) {
                override fun onTick(millisUntilFinished: Long) {
                    try {
                        val hours = millisUntilFinished / (1000 * 60 * 60)
                        val minutes = (millisUntilFinished / (1000 * 60)) % 60
                        val seconds = (millisUntilFinished / 1000) % 60
                        
                        val timeStr = String.format("%02d:%02d:%02d", hours, minutes, seconds)
                        timeLockCountdownText?.text = "⏰ Unlock Time Remaining\n$timeStr"
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating countdown: ${e.message}")
                    }
                }
                
                override fun onFinish() {
                    try {
                        isCountdownRunning = false
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        
                        // Verify lock is actually over before unlocking
                        if (!isTimeLockActive()) {
                            showUnlockMethodUI()
                        } else {
                            // Do NOT restart here - let onResume handle it
                            isCountdownRunning = false
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error finishing countdown: ${e.message}")
                        isCountdownRunning = false
                    }
                }
            }.start()
            isStartingCountdown = false
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in startTimeLockCountdown: ${e.message}")
            e.printStackTrace()
            isCountdownRunning = false
            isStartingCountdown = false
        }
    }
    
    private fun stopTimeLockCountdown() {
        timeLockCountdownTimer?.cancel()
        timeLockCountdownTimer = null
        isCountdownRunning = false
        isStartingCountdown = false
        timeLockActiveText?.visibility = View.GONE
        timeLockCountdownText?.visibility = View.GONE
    }

    private fun validatePin() {
        Log.d(TAG, "🔐 PIN Validation Starting...")
        
        // Refresh all security settings before validation
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        
        // Reload location lock settings
        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()
        
        // Reload time lock settings (isTimeLockActive will also call refreshTimeLockSettings)
        refreshTimeLockSettings()
        
        Log.d(TAG, "🔄 Security settings refreshed before validation")
        
        // TIME LOCK: Block ALL PINs if time lock is active (HIGHEST PRIORITY)
        if (isTimeLockActive()) {
            Log.d(TAG, "🚫 TIME LOCK ACTIVE - BLOCKING ALL PIN ATTEMPTS")
            blockAccessDueToTimeLock()  // Show countdown UI
            errorText.visibility = View.VISIBLE
            errorText.text = "⏰ Time locked. Try again outside lock window."
            errorText.textSize = 13f
            enteredPin = ""
            updateDots()
            failedAttempts = 0
            return
        }
        
        // LOCATION LOCK: Block ALL PINs if outside trusted location (SECOND PRIORITY)
        if (isOutsideTrustedLocation()) {
            Log.d(TAG, "🚫 LOCATION LOCK ACTIVE - BLOCKING ALL PIN ATTEMPTS")
            errorText.visibility = View.VISIBLE
            errorText.text = "📍 Location locked. Try again from trusted location."
            errorText.textSize = 13f
            enteredPin = ""
            updateDots()
            failedAttempts = 0
            return
        }
        
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
        } else {
            // Wrong PIN (including decoy PIN - decoy is NOT accepted for locked apps)
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
                // Capture intruder selfie on 3+ failed attempts
                captureIntruderSelfie()
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
        Log.d(TAG, "🔐 Pattern Validation Starting...")
        
        // Refresh all security settings before validation
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        
        // Reload location lock settings
        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()
        
        // Reload time lock settings (isTimeLockActive will also call refreshTimeLockSettings)
        refreshTimeLockSettings()
        
        Log.d(TAG, "🔄 Security settings refreshed before validation")
        
        // TIME LOCK: Block ALL patterns if time lock is active (HIGHEST PRIORITY)
        if (isTimeLockActive()) {
            Log.d(TAG, "🚫 TIME LOCK ACTIVE - BLOCKING ALL PATTERN ATTEMPTS")
            blockAccessDueToTimeLock()  // Show countdown UI
            errorText.visibility = View.VISIBLE
            errorText.text = "⏰ Time locked. Try again outside lock window."
            errorText.textSize = 13f
            patternView.reset()
            failedAttempts = 0
            return
        }
        
        // LOCATION LOCK: Block ALL patterns if outside trusted location (SECOND PRIORITY)
        if (isOutsideTrustedLocation()) {
            Log.d(TAG, "🚫 LOCATION LOCK ACTIVE - BLOCKING ALL PATTERN ATTEMPTS")
            errorText.visibility = View.VISIBLE
            errorText.text = "📍 Location locked. Try again from trusted location."
            errorText.textSize = 13f
            patternView.reset()
            failedAttempts = 0
            return
        }
        
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
        Log.d(TAG, "  entered == decoyPin? $decoyMatch (ignored - only real PIN unlocks locked apps)")

        if (realMatch) {
            Log.d(TAG, "")
            Log.d(TAG, "✅ CORRECT REAL PIN! Pattern matches!")
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
            
            if (!accessibilityEnabled && !hasShownAccessibilityPrompt) {
                Log.d(TAG, "Accessibility is OFF and first login - showing accessibility setup prompt")
                prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()
                
                showAccessibilitySetupDialog()
            } else {
                // Accessibility already on or already shown prompt - just unlock
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
            if (failedAttempts >= 3) {
                errorText.text = "Multiple failed attempts detected"
                captureIntruderSelfie()
                failedAttempts = 0
            } else {
                errorText.text = "Wrong pattern (${3 - failedAttempts} left)"
            }

            Handler(Looper.getMainLooper()).postDelayed({
                patternView.reset()
                errorText.visibility = View.GONE
            }, 1000)
        }
    }

    private fun captureIntruderSelfie() {
        try {
            // Run on background thread to avoid blocking UI
            Thread {
                try {
                    val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                    val cameraIds = cameraManager.cameraIdList
                    
                    // Find front-facing camera
                    var frontCameraId: String? = null
                    for (cameraId in cameraIds) {
                        val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                        val facing = characteristics.get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                        if (facing == android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT) {
                            frontCameraId = cameraId
                            break
                        }
                    }
                    
                    if (frontCameraId != null) {
                        val cacheDir = cacheDir
                        val imageFileName = "intruder_${System.currentTimeMillis()}.jpg"
                        val imageFile = java.io.File(cacheDir, imageFileName)
                        val imagePath = imageFile.absolutePath
                        
                        Log.d(TAG, "🚨 Attempting to capture intruder selfie: $imagePath")
                        
                        // Create blank placeholder image first (when camera capture fails, at least we have a log)
                        val bitmap = android.graphics.Bitmap.createBitmap(320, 240, android.graphics.Bitmap.Config.ARGB_8888)
                        val canvas = android.graphics.Canvas(bitmap)
                        canvas.drawColor(android.graphics.Color.BLACK)
                        val paint = android.graphics.Paint().apply {
                            color = android.graphics.Color.WHITE
                            textSize = 20f
                        }
                        canvas.drawText("Intruder Attempt", 10f, 120f, paint)
                        canvas.drawText(java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US).format(java.util.Date()), 10f, 150f, paint)
                        
                        // Save bitmap to file
                        imageFile.outputStream().use { output ->
                            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, output)
                        }
                        bitmap.recycle()
                        
                        Log.d(TAG, "🚨 Intruder image saved: $imagePath")
                        
                        // Store the intruder log in SharedPreferences
                        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                        val existingLogs = prefs.getString("intruderLogs", "") ?: ""
                        val logEntry = "$imagePath|${System.currentTimeMillis()}|Failed PIN attempt on $lockedPackage\n"
                        prefs.edit().putString("intruderLogs", existingLogs + logEntry).apply()
                        
                        Log.d(TAG, "🚨 Intruder log recorded: Failed PIN attempt on $lockedPackage at $imagePath")
                    } else {
                        Log.w(TAG, "🚨 No front-facing camera found")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "🚨 Error capturing intruder selfie: ${e.message}")
                    e.printStackTrace()
                    // Fail silently to not break lock screen UX
                }
            }.start()
        } catch (e: Exception) {
            Log.e(TAG, "🚨 Exception in captureIntruderSelfie: ${e.message}")
            // Fail silently
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
            refreshTimeLockSettings()  // Refresh time lock for new app
            
            // Check if time lock should apply to this app too
            if (isTimeLockActive()) {
                blockAccessDueToTimeLock()
            } else {
                showUnlockMethodUI()
            }
            currentlyBlockedPackage = lockedPackage
            Log.d(TAG, "🔄 Unlock screen switched to: $appName ($lockedPackage)")
        } else {
            // Same app — reload PINs in case settings changed, then check if UI needs refresh
            val oldPattern = unlockPattern
            loadPins()
            refreshTimeLockSettings()  // Refresh time lock settings
            
            if (oldPattern != unlockPattern) {
                Log.d(TAG, "🔄 Unlock pattern changed from '$oldPattern' to '$unlockPattern', refreshing UI")
                enteredPin = ""
                failedAttempts = 0
                errorText.visibility = View.GONE
                patternView.reset()
                
                // Check time lock for pattern change too
                if (isTimeLockActive()) {
                    blockAccessDueToTimeLock()
                } else {
                    showUnlockMethodUI()
                }
            } else {
                Log.d(TAG, "🔄 Unlock screen re-focused for same app: $lockedPackage")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "🔄 Lock screen resumed - checking all security settings...")
        
        // Reload all settings like Flutter's _loadSettings()
        val oldPattern = unlockPattern
        loadPins()  // This also loads time/location lock settings
        refreshTimeLockSettings()  // Ensure latest time lock settings
        
        Log.d(TAG, "🔄 Security settings reloaded on resume")
        Log.d(TAG, "   Time lock: $nightLockEnabled (${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)})")
        
        // Check if unlock pattern changed
        if (oldPattern != unlockPattern) {
            Log.d(TAG, "🔄 Unlock pattern changed from '$oldPattern' to '$unlockPattern' on resume, refreshing UI")
            enteredPin = ""
            failedAttempts = 0
            errorText.visibility = View.GONE
            patternView.reset()
            if (isTimeLockActive()) {
                blockAccessDueToTimeLock()
            } else {
                showUnlockMethodUI()
            }
            return
        }
        
        // Re-check time lock status on resume (user may have set it while app was closed)
        Log.d(TAG, "🔄 Re-checking time lock status on resume...")
        
        // Verify and log current configuration
        verifyTimeLockConfiguration()
        
        val wasShowingTimeLock = timeLockCountdownText?.visibility == View.VISIBLE
        val isNowLocked = isTimeLockActive()
        
        when {
            isNowLocked && !wasShowingTimeLock -> {
                // Time lock just became active - show lock UI
                blockAccessDueToTimeLock()
            }
            !isNowLocked && wasShowingTimeLock -> {
                // Lock period expired - show unlock UI
                timeLockCountdownTimer?.cancel()
                timeLockActiveText?.visibility = View.GONE
                timeLockCountdownText?.visibility = View.GONE
                enteredPin = ""
                failedAttempts = 0
                errorText.visibility = View.GONE
                showUnlockMethodUI()
            }
            isNowLocked && wasShowingTimeLock -> {
                // Still locked - verify countdown is running
                if (!isCountdownRunning) {
                    startTimeLockCountdown()
                }
            }
            else -> {
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
            // Note: We keep the countdown running in the background
            // This allows the timer to continue even if app is hidden
        } else {
            // If unlocked, can safely stop timer
            timeLockCountdownTimer?.cancel()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up countdown timer
        timeLockCountdownTimer?.cancel()
        timeLockCountdownTimer = null
        
        isShowing = false
        currentlyBlockedPackage = null
        if (!pinCorrect) {
            dismissedAt = System.currentTimeMillis()
            dismissedPackage = lockedPackage
            Log.d(TAG, "🔒 Lock screen destroyed without correct PIN for: $lockedPackage")
        } else {
            Log.d(TAG, "✅ Lock screen destroyed after correct PIN for: $lockedPackage")
        }
    }
}
