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
import android.hardware.camera2.CaptureRequest
import android.Manifest
import android.content.pm.PackageManager

class AppLockActivity : FragmentActivity() {

    companion object {
        private const val TAG = "AppLockActivity"
        const val EXTRA_LOCKED_PACKAGE = "locked_package"
        const val EXTRA_APP_NAME = "app_name"

        @Volatile
        var isShowing = false
            private set

        @Volatile
        var currentlyBlockedPackage: String? = null
            private set

        @Volatile
        var dismissedAt: Long = 0L
            private set

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
    private var pinCorrect = false  
    private var unlockPattern: String = "4-digit"
    private var pinLength: Int = 4

    private var locationLockEnabled = false
    private var trustedLat = 0.0
    private var trustedLng = 0.0
    private var trustedRadius = 200.0

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

    private var timeLockActiveText: TextView? = null
    private var timeLockCountdownText: TextView? = null
    private var timeLockCountdownTimer: android.os.CountDownTimer? = null

    private var isCountdownRunning = false
    private var isStartingCountdown = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

    if (checkSelfPermission(android.Manifest.permission.CAMERA)
        != android.content.pm.PackageManager.PERMISSION_GRANTED) {

        requestPermissions(
            arrayOf(android.Manifest.permission.CAMERA),
            101
        )
    }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        )

        window.setType(WindowManager.LayoutParams.TYPE_APPLICATION)

        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        setContentView(R.layout.activity_app_lock)

        lockedPackage = intent.getStringExtra(EXTRA_LOCKED_PACKAGE) ?: ""
        appName = intent.getStringExtra(EXTRA_APP_NAME) ?: lockedPackage.split(".").lastOrNull() ?: "App"

        Log.d(TAG, "PIN screen opened for: $appName ($lockedPackage)")

        isShowing = true
        currentlyBlockedPackage = lockedPackage

        loadPins()

        initViews()

        refreshTimeLockSettings()

        verifyTimeLockConfiguration()

        if (isTimeLockActive()) {
            blockAccessDueToTimeLock()
        } else {
            showUnlockMethodUI()
        }
        
        setupKeypad()
    }

    private fun blockAccessDueToTimeLock() {
        Log.d(TAG, " Blocking access due to time lock - showing keypad only")
        
        try {
            
            titleText.visibility = View.VISIBLE
            keypadGrid.visibility = View.VISIBLE
            for (dot in dots.take(pinLength)) {  
                dot.visibility = View.VISIBLE
            }

            patternLockContainer.visibility = View.GONE
            fingerprintButtonContainer.visibility = View.GONE

            errorText.visibility = View.VISIBLE
            errorText.text = "⏰ Time locked. Try again outside lock window."
            errorText.textSize = 13f
            
            Log.d(TAG, " Keypad UI displayed during time lock")

            startTimeLockCountdown()
        } catch (e: Exception) {
            Log.e(TAG, " Error blocking access: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun loadPins() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        realPin = prefs.getString("cached_real_pin", null)
        decoyPin = prefs.getString("cached_decoy_pin", null)
        unlockPattern = prefs.getString("unlock_pattern", "4-digit") ?: "4-digit"

        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()

        nightLockEnabled = prefs.getBoolean("nightLockEnabled", false)
        nightStartHour = prefs.getInt("nightStartHour", 22)
        nightStartMinute = prefs.getInt("nightStartMinute", 0)
        nightEndHour = prefs.getInt("nightEndHour", 6)
        nightEndMinute = prefs.getInt("nightEndMinute", 0)

        pinLength = if (unlockPattern.contains("6")) 6 else 4

        Log.d(TAG, "")
        Log.d(TAG, "        PINS LOADED FROM STORAGE        ")
        Log.d(TAG, "")
        Log.d(TAG, "Unlock pattern: '$unlockPattern'")
        Log.d(TAG, "PIN length to expect: $pinLength")
        Log.d(TAG, "Location lock: $locationLockEnabled (Trusted: $trustedLat, $trustedLng, Radius: $trustedRadius m)")
        Log.d(TAG, "Time lock: $nightLockEnabled (${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)})")
        Log.d(TAG, "Real PIN:   '$realPin'")
        if (realPin != null) {
            Log.d(TAG, "   Length: ${realPin!!.length}, Bytes: ${realPin!!.toByteArray().joinToString(",")}")
        }
        Log.d(TAG, "Decoy PIN:  '$decoyPin'")
        if (decoyPin != null) {
            Log.d(TAG, "   Length: ${decoyPin!!.length}, Bytes: ${decoyPin!!.toByteArray().joinToString(",")}")
        }

        if (realPin == null) {
            Log.e(TAG, " No PINs found in SharedPreferences! App lock cannot validate.")
        }
    }

    private fun refreshTimeLockSettings() {
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        nightLockEnabled = prefs.getBoolean("nightLockEnabled", false)
        nightStartHour = prefs.getInt("nightStartHour", 22)
        nightStartMinute = prefs.getInt("nightStartMinute", 0)
        nightEndHour = prefs.getInt("nightEndHour", 6)
        nightEndMinute = prefs.getInt("nightEndMinute", 0)
        
        Log.d(TAG, " Time lock settings refreshed:")
        Log.d(TAG, "   Enabled: $nightLockEnabled")
        Log.d(TAG, "   Window: ${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)}")
    }

    private fun verifyTimeLockConfiguration() {
        Log.d(TAG, "")
        Log.d(TAG, "     TIME LOCK CONFIGURATION SUMMARY    ")
        Log.d(TAG, "")
        Log.d(TAG, "Status: ${if (nightLockEnabled) " ENABLED" else " DISABLED"}")
        Log.d(TAG, "Lock Window: ${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)}")

        val startMinutes = nightStartHour * 60 + nightStartMinute
        val endMinutes = nightEndHour * 60 + nightEndMinute
        val lockType = if (startMinutes < endMinutes) "Same-Day Lock" else "Overnight Lock"
        Log.d(TAG, "Lock Type: $lockType")

        val calendar = java.util.Calendar.getInstance()
        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentMinutes = currentHour * 60 + currentMinute
        
        Log.d(TAG, "Current Time: ${String.format("%02d:%02d", currentHour, currentMinute)}")

        val isCurrentlyLocked = if (nightLockEnabled) {
            if (startMinutes < endMinutes) {
                currentMinutes >= startMinutes && currentMinutes <= endMinutes
            } else {
                currentMinutes >= startMinutes || currentMinutes <= endMinutes
            }
        } else {
            false
        }
        
        Log.d(TAG, "Currently Locked: ${if (isCurrentlyLocked) " YES" else " NO"}")
        Log.d(TAG, "")
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

        timeLockActiveText = findViewById(R.id.timeLockActiveText)
        timeLockCountdownText = findViewById(R.id.timeLockCountdownText)
        
        Log.d(TAG, " Time lock views initialized from XML layout")

        dots.addAll(listOf(dot1, dot2, dot3, dot4, dot5, dot6))

        patternLockContainer = findViewById(R.id.patternLockContainer)
        patternView = findViewById(R.id.patternView)
        keypadGrid = findViewById(R.id.keypadGrid)
        fingerprintButtonContainer = findViewById(R.id.fingerprintButtonContainer)
        fingerprintHelpText = findViewById(R.id.fingerprintHelpText)

        patternView.isFocusable = true
        patternView.isClickable = true

        val lockIcon = findViewById<ImageView>(R.id.lockIcon)
        if (lockIcon != null) {
            lockIcon.setColorFilter(Color.WHITE)
            
            lockIcon.setImageResource(android.R.drawable.ic_dialog_info)
        }

        patternView.onPatternCompleted = { pattern ->
            Log.d(TAG, "Pattern completed: $pattern, comparing with realPin: $realPin")
            validatePattern(pattern)
        }

        setupFingerprintButton()
    }

    private fun showUnlockMethodUI() {
        
        patternLockContainer.visibility = View.GONE
        keypadGrid.visibility = View.VISIBLE

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

    private fun setupFingerprintButton() {
        Log.d(TAG, " Setting up fingerprint button (always visible)")
        fingerprintButtonContainer.visibility = View.VISIBLE
        fingerprintHelpText.visibility = View.VISIBLE

        fingerprintButtonContainer.setOnClickListener {
            showBiometricPrompt()
        }
    }

    private fun showBiometricPrompt() {
        Log.d(TAG, " Biometric button tapped - starting authentication...")
        CoroutineScope(Dispatchers.Main).launch {
            try {
                Log.d(TAG, "Calling BiometricService.authenticate()...")
                val isAuthenticated = BiometricService.authenticate(this@AppLockActivity)
                
                Log.d(TAG, "Biometric result: $isAuthenticated")
                
                if (isAuthenticated) {
                    Log.d(TAG, " Biometric authentication successful - unlocking app")

                    BiometricService.enable(this@AppLockActivity)

                    failedAttempts = 0
                    pinCorrect = true
                    
                    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
                    val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
                    val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
                    unlockedSet.add(lockedPackage)
                    prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()
                    
                    Log.d(TAG, " Session-unlocked via biometric: $lockedPackage")

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
                    Log.d(TAG, " Biometric authentication failed - user can still try PIN")
                    
                }
            } catch (e: Exception) {
                Log.e(TAG, " Error during biometric authentication: ${e.message}")
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

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening accessibility settings: ${e.message}")
        }
    }

    private fun onAccessibilitySetupComplete() {
        Log.d(TAG, "🔓 onAccessibilitySetupComplete() called - UNLOCKING AND CLOSING LOCK SCREEN")

        AppLockForegroundService.start(this)

        isShowing = false
        currentlyBlockedPackage = null
        
        Log.d(TAG, "📵 Calling finish() to close lock screen")
        finish()
    }

    private fun updateDots() {
        val filledColor = Color.parseColor("#00BCD4") 
        val emptyStroke = Color.parseColor("#8000BCD4")

        for (i in dots.indices) {
            val dot = dots[i]
            val bg = GradientDrawable()
            bg.shape = GradientDrawable.OVAL

            if (i < pinLength) {
                
                dot.visibility = View.VISIBLE
                
                if (i < enteredPin.length) {
                    bg.setColor(filledColor)
                    bg.setStroke(2, filledColor)
                } else {
                    bg.setColor(Color.TRANSPARENT)
                    bg.setStroke(2, emptyStroke)
                }
            } else {
                
                dot.visibility = View.GONE
            }

            dot.background = bg
        }
    }

    private fun isOutsideTrustedLocation(): Boolean {
        if (!locationLockEnabled) {
            Log.d(TAG, " Location lock is DISABLED")
            return false
        }

        if (trustedLat == 0.0 && trustedLng == 0.0) {
            Log.d(TAG, " Trusted location NOT configured - allowing access")
            return false
        }

        if (androidx.core.content.ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            Log.d(TAG, " Location permission DENIED - allowing access (can't verify location)")
            return false
        }

        try {
            
            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

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
                    
                    Log.d(TAG, " Current: ${currentLocation.latitude}, ${currentLocation.longitude}")
                    Log.d(TAG, " Trusted: $trustedLat, $trustedLng")
                    Log.d(TAG, " Distance: $distance m, Radius: $trustedRadius m")
                    
                    isOutside = distance > trustedRadius
                    if (isOutside) {
                        Log.d(TAG, " OUTSIDE trusted location - BLOCKING")
                    } else {
                        Log.d(TAG, " INSIDE trusted location - ALLOWING")
                    }
                } else {
                    Log.d(TAG, " No last location available - allowing access (maybe first time)")
                    isOutside = false
                }
            }

            var waited = 0
            while (!locationObtained && waited < 2000) {
                Thread.sleep(100)
                waited += 100
            }

            if (!locationObtained) {
                Log.d(TAG, "⏱ Location timeout - allowing access (location service slow)")
                return false
            }
            
            return isOutside
        } catch (e: Exception) {
            Log.e(TAG, " Exception checking location: ${e.message} - allowing access")
            return false
        }
    }

    private fun calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val R = 6371000.0 
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLng / 2) * Math.sin(dLng / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return R * c
    }

    private fun isTimeLockActive(): Boolean {
        
        refreshTimeLockSettings()
        
        if (!nightLockEnabled) {
            return false
        }

        val calendar = java.util.Calendar.getInstance()
        val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val currentMinute = calendar.get(java.util.Calendar.MINUTE)
        val currentMinutes = currentHour * 60 + currentMinute
        
        val startMinutes = nightStartHour * 60 + nightStartMinute
        val endMinutes = nightEndHour * 60 + nightEndMinute

        val isLocked = if (startMinutes < endMinutes) {
            
            currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            
            currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }

        return isLocked
    }

    private fun startTimeLockCountdown() {
        
        if (isStartingCountdown) {
            return
        }
        
        if (isCountdownRunning) {
            return
        }
        
        isStartingCountdown = true

        if (timeLockActiveText == null || timeLockCountdownText == null) {
            Log.e(TAG, " Time lock views not initialized!")
            isStartingCountdown = false
            return
        }
        
        try {
            
            timeLockCountdownTimer?.cancel()
            isCountdownRunning = false

            timeLockActiveText?.visibility = View.VISIBLE
            timeLockCountdownText?.visibility = View.VISIBLE
            val timeLockCountdownContainer = findViewById<View>(R.id.timeLockCountdownContainer)
            timeLockCountdownContainer?.visibility = View.VISIBLE

            timeLockActiveText?.requestLayout()
            timeLockCountdownText?.requestLayout()
            timeLockCountdownContainer?.requestLayout()

            val calendar = java.util.Calendar.getInstance()
            val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
            val currentMinute = calendar.get(java.util.Calendar.MINUTE)
            val currentSecond = calendar.get(java.util.Calendar.SECOND)
            val currentMinutes = currentHour * 60 + currentMinute
            
            val startMinutes = nightStartHour * 60 + nightStartMinute
            val endMinutes = nightEndHour * 60 + nightEndMinute

            val remainingMinutes: Int
            val remainingSeconds: Int
            
            when {
                startMinutes < endMinutes -> {
                    
                    if (currentMinutes < startMinutes) {
                        
                        remainingMinutes = startMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else if (currentMinutes < endMinutes) {
                        
                        remainingMinutes = endMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else {
                        
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        timeLockCountdownContainer?.visibility = View.GONE
                        isCountdownRunning = false
                        isStartingCountdown = false
                        showUnlockMethodUI()
                        return
                    }
                }
                else -> {
                    
                    if (currentMinutes >= startMinutes) {
                        
                        val minutesUntilMidnight = (24 * 60) - currentMinutes
                        remainingMinutes = minutesUntilMidnight + endMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else if (currentMinutes <= endMinutes) {
                        
                        remainingMinutes = endMinutes - currentMinutes - 1
                        remainingSeconds = 60 - currentSecond
                    } else {
                        
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        timeLockCountdownContainer?.visibility = View.GONE
                        isCountdownRunning = false
                        isStartingCountdown = false
                        showUnlockMethodUI()
                        return
                    }
                }
            }

            if (remainingMinutes < 0) {
                timeLockActiveText?.visibility = View.GONE
                timeLockCountdownText?.visibility = View.GONE
                timeLockCountdownContainer?.visibility = View.GONE
                isCountdownRunning = false
                isStartingCountdown = false
                showUnlockMethodUI()
                return
            }
            
            val totalRemainingMillis = (remainingMinutes * 60 + remainingSeconds) * 1000L

            timeLockCountdownText?.text = String.format("%02d:%02d:%02d", 
                remainingMinutes / 60, remainingMinutes % 60, remainingSeconds)

            isCountdownRunning = true
            timeLockCountdownTimer = object : android.os.CountDownTimer(totalRemainingMillis, 1000) {
                override fun onTick(millisUntilFinished: Long) {
                    try {
                        val hours = millisUntilFinished / (1000 * 60 * 60)
                        val minutes = (millisUntilFinished / (1000 * 60)) % 60
                        val seconds = (millisUntilFinished / 1000) % 60
                        
                        val timeStr = String.format("%02d:%02d:%02d", hours, minutes, seconds)
                        timeLockCountdownText?.text = timeStr
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating countdown: ${e.message}")
                    }
                }
                
                override fun onFinish() {
                    try {
                        isCountdownRunning = false
                        timeLockActiveText?.visibility = View.GONE
                        timeLockCountdownText?.visibility = View.GONE
                        val timeLockCountdownContainer = findViewById<View>(R.id.timeLockCountdownContainer)
                        timeLockCountdownContainer?.visibility = View.GONE

                        if (!isTimeLockActive()) {
                            showUnlockMethodUI()
                        } else {
                            
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
            Log.e(TAG, " Error in startTimeLockCountdown: ${e.message}")
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
        val timeLockCountdownContainer = findViewById<View>(R.id.timeLockCountdownContainer)
        timeLockCountdownContainer?.visibility = View.GONE
    }

    private fun validatePin() {
        Log.d(TAG, " PIN Validation Starting...")

        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)

        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()

        refreshTimeLockSettings()
        
        Log.d(TAG, " Security settings refreshed before validation")

        if (isTimeLockActive()) {
            Log.d(TAG, " TIME LOCK ACTIVE - BLOCKING ALL PIN ATTEMPTS")
            blockAccessDueToTimeLock()  
            errorText.visibility = View.VISIBLE
            errorText.text = "⏰ Time locked. Try again outside lock window."
            errorText.textSize = 13f
            enteredPin = ""
            updateDots()
            failedAttempts = 0
            return
        }

        if (isOutsideTrustedLocation()) {
            Log.d(TAG, " LOCATION LOCK ACTIVE - BLOCKING ALL PIN ATTEMPTS")
            errorText.visibility = View.VISIBLE
            errorText.text = " Location locked. Try again from trusted location."
            errorText.textSize = 13f
            enteredPin = ""
            updateDots()
            failedAttempts = 0
            return
        }
        
        if (enteredPin == realPin) {
            
            failedAttempts = 0
            pinCorrect = true
            Log.d(TAG, "✅ CORRECT REAL PIN MATCHED - Preparing to unlock app: $lockedPackage")

            errorText.visibility = View.GONE

            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Session-unlocked: $lockedPackage (total: ${unlockedSet.size})")

            val accessibilityEnabled = isAccessibilityServiceEnabled()
            val hasShownAccessibilityPrompt = prefs.getBoolean("accessibility_prompt_shown", false)
            
            if (!accessibilityEnabled && !hasShownAccessibilityPrompt) {
                Log.d(TAG, "Accessibility is OFF and first login - showing accessibility setup prompt")
                prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()

                showAccessibilitySetupDialog()
            } else {
                
                if (accessibilityEnabled) {
                    Log.d(TAG, "Accessibility already enabled - skipping setup prompt")
                }
                onAccessibilitySetupComplete()
            }
        } else {
            
            failedAttempts++
            Log.d(TAG, "Wrong PIN attempt #$failedAttempts for: $lockedPackage")

            try {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(200)
            } catch (e: Exception) {  }

            errorText.visibility = View.VISIBLE
            if (failedAttempts >= 3) {
                Log.d(TAG, " *** INTRUDER ALERT: 3+ failed attempts - Capturing image ***")
                errorText.text = "Multiple failed attempts detected"
                
                captureIntruderSelfie(enteredPin)
                
                Log.d(TAG, " *** Image capture initiated - Resetting attempt counter ***")
                failedAttempts = 0
            } else {
                errorText.text = "Wrong PIN (${3 - failedAttempts} attempts left)"
            }

            val dotsContainer = findViewById<LinearLayout>(R.id.pinDotsContainer)
            try {
                val shake = AnimationUtils.loadAnimation(this, android.R.anim.fade_in)
                dotsContainer.startAnimation(shake)
            } catch (e: Exception) {  }

            Handler(Looper.getMainLooper()).postDelayed({
                enteredPin = ""
                updateDots()
                Log.d(TAG, " *** PIN cleared - App remains LOCKED awaiting next attempt ***")
            }, 300)
        }
    }

    private fun validatePattern(pattern: String) {
        Log.d(TAG, " Pattern Validation Starting...")

        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)

        locationLockEnabled = prefs.getBoolean("locationLockEnabled", false)
        trustedLat = prefs.getFloat("trustedLat", 0f).toDouble()
        trustedLng = prefs.getFloat("trustedLng", 0f).toDouble()
        trustedRadius = prefs.getFloat("trustedRadius", 200f).toDouble()

        refreshTimeLockSettings()
        
        Log.d(TAG, " Security settings refreshed before validation")

        if (isTimeLockActive()) {
            Log.d(TAG, " TIME LOCK ACTIVE - BLOCKING ALL PATTERN ATTEMPTS")
            blockAccessDueToTimeLock()  
            errorText.visibility = View.VISIBLE
            errorText.text = " Time locked. Try again outside lock window."
            errorText.textSize = 13f
            patternView.reset()
            failedAttempts = 0
            return
        }

        if (isOutsideTrustedLocation()) {
            Log.d(TAG, " LOCATION LOCK ACTIVE - BLOCKING ALL PATTERN ATTEMPTS")
            errorText.visibility = View.VISIBLE
            errorText.text = " Location locked. Try again from trusted location."
            errorText.textSize = 13f
            patternView.reset()
            failedAttempts = 0
            return
        }
        
        val entered = pattern.trim()
        
        Log.d(TAG, "")
        Log.d(TAG, "       PATTERN VALIDATION CHECK        ")
        Log.d(TAG, "")
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
            Log.e(TAG, " VALIDATION FAILED: Empty entered or no realPin!")
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
            Log.d(TAG, " CORRECT REAL PIN! Pattern matches!")
            failedAttempts = 0
            errorText.visibility = View.GONE

            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
            val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
            unlockedSet.add(lockedPackage)
            prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

            Log.d(TAG, "Session-unlocked: $lockedPackage")

            val accessibilityEnabled = isAccessibilityServiceEnabled()
            val hasShownAccessibilityPrompt = prefs.getBoolean("accessibility_prompt_shown", false)
            
            if (!accessibilityEnabled && !hasShownAccessibilityPrompt) {
                Log.d(TAG, "Accessibility is OFF and first login - showing accessibility setup prompt")
                prefs.edit().putBoolean("accessibility_prompt_shown", true).apply()
                
                showAccessibilitySetupDialog()
            } else {
                
                if (accessibilityEnabled) {
                    Log.d(TAG, "Accessibility already enabled - skipping setup prompt")
                }
                onAccessibilitySetupComplete()
            }
        } else {
            failedAttempts++
            Log.d(TAG, "")
            Log.d(TAG, " INCORRECT! Pattern does not match.")
            Log.d(TAG, "Attempt #$failedAttempts")

            try {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(200)
            } catch (e: Exception) {  }

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

    private fun captureIntruderSelfie(enteredPin: String = "***") {
        try {
            
           Handler(Looper.getMainLooper()).post {

    try {
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
        val cameraIds = cameraManager.cameraIdList

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

            val intruderDir = java.io.File(filesDir, "intruder_logs")
            if (!intruderDir.exists()) {
                val created = intruderDir.mkdirs()
                Log.d(TAG, " Intruder directory created: $created at ${intruderDir.absolutePath}")
            } else {
                Log.d(TAG, " Intruder directory already exists at ${intruderDir.absolutePath}")
            }

            val imageFileName = "intruder_${System.currentTimeMillis()}.jpg"
            val imageFile = java.io.File(intruderDir, imageFileName)
            val imagePath = imageFile.absolutePath
            
            Log.d(TAG, " Will save intruder image to: $imagePath")
            Log.d(TAG, " CAPTURING INTRUDER SELFIE - APP WILL REMAIN LOCKED")

            val captureComplete = java.util.concurrent.CountDownLatch(1)
            var imageCaptured = false

            val cameraStateCallback = object : android.hardware.camera2.CameraDevice.StateCallback() {

                override fun onOpened(camera: android.hardware.camera2.CameraDevice) {

                    try {
                        val characteristics = cameraManager.getCameraCharacteristics(frontCameraId)
                        val streamConfigMap = characteristics.get(
                            android.hardware.camera2.CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP
                        )

                        // Select highest resolution for best quality
                        val sizes = streamConfigMap!!.getOutputSizes(android.graphics.ImageFormat.JPEG)
                        val size = sizes.maxByOrNull { it.width * it.height } ?: sizes[0]
                        
                        Log.d(TAG, " Selected camera resolution: ${size.width}x${size.height}")

                        val imageReader = android.media.ImageReader.newInstance(
                            size.width,
                            size.height,
                            android.graphics.ImageFormat.JPEG,
                            2
                        )

                        imageReader.setOnImageAvailableListener({ reader ->
                            val image = reader.acquireLatestImage()
                            if (image != null) {

                                val buffer = image.planes[0].buffer
                                val bytes = ByteArray(buffer.remaining())
                                buffer.get(bytes)

                                imageFile.writeBytes(bytes)
                                imageFile.setReadable(true, false)  // Ensure readable

                                val savedSize = imageFile.length()
                                Log.d(TAG, " Camera image saved: ${imageFile.absolutePath}, Size: $savedSize bytes")

                                imageCaptured = true
                                image.close()
                            }

                            reader.close()
                            camera.close()
                            captureComplete.countDown()

                        }, Handler(Looper.getMainLooper()))

                        val captureRequestBuilder = camera.createCaptureRequest(
                            android.hardware.camera2.CameraDevice.TEMPLATE_STILL_CAPTURE
                        )

                        captureRequestBuilder.addTarget(imageReader.surface)
                        captureRequestBuilder.set(
                            android.hardware.camera2.CaptureRequest.CONTROL_AE_MODE,
                            android.hardware.camera2.CaptureRequest.CONTROL_AE_MODE_ON
                        )
                        // Enable autofocus for better image quality
                        captureRequestBuilder.set(
                            android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE,
                            android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE_AUTO
                        )
                        // Set exposure precapture trigger
                        captureRequestBuilder.set(
                            android.hardware.camera2.CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER,
                            android.hardware.camera2.CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_START
                        )
                        // Set JPEG quality to maximum (95) for best image
                        captureRequestBuilder.set(
                            android.hardware.camera2.CaptureRequest.JPEG_QUALITY,
                            95.toByte()
                        )
                        // Set thumbnail quality
                        captureRequestBuilder.set(
                            android.hardware.camera2.CaptureRequest.JPEG_THUMBNAIL_QUALITY,
                            90.toByte()
                        )

                        camera.createCaptureSession(
                            listOf(imageReader.surface),
                            object : android.hardware.camera2.CameraCaptureSession.StateCallback() {

                                override fun onConfigured(session: android.hardware.camera2.CameraCaptureSession) {

                                    // Build preview request first for autofocus
                                    val previewRequestBuilder = camera.createCaptureRequest(
                                        android.hardware.camera2.CameraDevice.TEMPLATE_PREVIEW
                                    )
                                    previewRequestBuilder.addTarget(imageReader.surface)
                                    previewRequestBuilder.set(
                                        android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE,
                                        android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE_AUTO
                                    )

                                    // Start preview to let camera autofocus
                                    try {
                                        session.setRepeatingRequest(
                                            previewRequestBuilder.build(),
                                            null,
                                            null
                                        )
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error setting preview request: ${e.message}")
                                    }

                                    // Wait longer for autofocus before capture
                                    Handler(Looper.getMainLooper()).postDelayed({

                                        session.capture(
                                            captureRequestBuilder.build(),
                                            object : android.hardware.camera2.CameraCaptureSession.CaptureCallback() {},
                                            null
                                        )

                                    }, 1500)  // Wait 1.5 seconds for proper autofocus and exposure
                                }

                                override fun onConfigureFailed(session: android.hardware.camera2.CameraCaptureSession) {
                                    camera.close()
                                    captureComplete.countDown()
                                }
                            },
                            null
                        )

                    } catch (e: Exception) {
                        camera.close()
                        captureComplete.countDown()
                    }
                }

                override fun onDisconnected(camera: android.hardware.camera2.CameraDevice) {
                    camera.close()
                    captureComplete.countDown()
                }

                override fun onError(camera: android.hardware.camera2.CameraDevice, error: Int) {
                    camera.close()
                    captureComplete.countDown()
                }
            }

            try {
                cameraManager.openCamera(frontCameraId, cameraStateCallback, Handler(Looper.getMainLooper()))

                captureComplete.await(8, java.util.concurrent.TimeUnit.SECONDS)

                if (!imageCaptured) {
                    createPlaceholderImage(imagePath, enteredPin)
                }

            } catch (e: Exception) {
                createPlaceholderImage(imagePath, enteredPin)
            }

        }

    } catch (e: Exception) {
        Log.e(TAG, "Error: ${e.message}")
    }
}
        Log.d(TAG, " ✓ captureIntruderSelfie COMPLETED - App remains LOCKED")
        } catch (e: Exception) {
            Log.e(TAG, " Exception in captureIntruderSelfie: ${e.message}")
        }
    }
    
    private fun createPlaceholderImage(imagePath: String, enteredPin: String) {
        val imageFile = java.io.File(imagePath)
        try {
            Log.d(TAG, " Creating placeholder image at: $imagePath")
            
            val bitmap = android.graphics.Bitmap.createBitmap(640, 480, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)
            canvas.drawColor(android.graphics.Color.BLACK)
            val paint = android.graphics.Paint().apply {
                color = android.graphics.Color.WHITE
                textSize = 20f
                isAntiAlias = true
            }
            val timeStr = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US).format(java.util.Date())
            canvas.drawText("⚠ Intruder Detected", 20f, 100f, paint)
            canvas.drawText("Unauthorized Access", 20f, 150f, paint)
            canvas.drawText("PIN: $enteredPin", 20f, 200f, paint)
            canvas.drawText("Time: $timeStr", 20f, 250f, paint)
            canvas.drawText("App: $lockedPackage", 20f, 300f, paint)
            
            // Write to file and flush
            imageFile.outputStream().use { output ->
                bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, output)
                output.flush()
            }
            bitmap.recycle()
            
            val fileSizeBytes = imageFile.length()
            Log.d(TAG, " Placeholder image created: $imagePath, Size: $fileSizeBytes bytes")

            val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
            val existingLogs = prefs.getString("intruderLogs", "") ?: ""
            val logEntry = "$imagePath|${System.currentTimeMillis()}|Failed PIN attempt on $lockedPackage|$enteredPin\n"
            prefs.edit().putString("intruderLogs", existingLogs + logEntry).apply()
        } catch (ex: Exception) {
            Log.e(TAG, " Error creating placeholder: ${ex.message}")
        }
    }

    override fun onBackPressed() {
        
        if (pinCorrect || isFinishing || isDestroyed) return
        Log.d(TAG, "Back pressed on lock screen - going home and keeping locked")
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        isShowing = false
        currentlyBlockedPackage = null
        dismissedAt = System.currentTimeMillis()
        dismissedPackage = lockedPackage
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        val newPackage = intent.getStringExtra(EXTRA_LOCKED_PACKAGE) ?: ""
        val newAppName = intent.getStringExtra(EXTRA_APP_NAME) ?: newPackage.split(".").lastOrNull() ?: "App"
        if (newPackage.isNotEmpty() && newPackage != lockedPackage) {
            
            lockedPackage = newPackage
            appName = newAppName
            enteredPin = ""
            failedAttempts = 0
            pinCorrect = false
            errorText.visibility = View.GONE
            patternView.reset()
            loadPins()  
            refreshTimeLockSettings()  

            if (isTimeLockActive()) {
                blockAccessDueToTimeLock()
            } else {
                showUnlockMethodUI()
            }
            currentlyBlockedPackage = lockedPackage
            Log.d(TAG, " Unlock screen switched to: $appName ($lockedPackage)")
        } else {
            
            val oldPattern = unlockPattern
            loadPins()
            refreshTimeLockSettings()  
            
            if (oldPattern != unlockPattern) {
                Log.d(TAG, " Unlock pattern changed from '$oldPattern' to '$unlockPattern', refreshing UI")
                enteredPin = ""
                failedAttempts = 0
                errorText.visibility = View.GONE
                patternView.reset()

                if (isTimeLockActive()) {
                    blockAccessDueToTimeLock()
                } else {
                    showUnlockMethodUI()
                }
            } else {
                Log.d(TAG, " Unlock screen re-focused for same app: $lockedPackage")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, " Lock screen resumed - checking all security settings...")

        val oldPattern = unlockPattern
        loadPins()  
        refreshTimeLockSettings()  
        
        Log.d(TAG, " Security settings reloaded on resume")
        Log.d(TAG, "   Time lock: $nightLockEnabled (${String.format("%02d:%02d", nightStartHour, nightStartMinute)} - ${String.format("%02d:%02d", nightEndHour, nightEndMinute)})")

        if (oldPattern != unlockPattern) {
            Log.d(TAG, " Unlock pattern changed from '$oldPattern' to '$unlockPattern' on resume, refreshing UI")
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

        Log.d(TAG, " Re-checking time lock status on resume...")

        verifyTimeLockConfiguration()
        
        val wasShowingTimeLock = timeLockCountdownText?.visibility == View.VISIBLE
        val isNowLocked = isTimeLockActive()
        
        when {
            isNowLocked && !wasShowingTimeLock -> {
                
                blockAccessDueToTimeLock()
            }
            !isNowLocked && wasShowingTimeLock -> {
                
                timeLockCountdownTimer?.cancel()
                timeLockActiveText?.visibility = View.GONE
                timeLockCountdownText?.visibility = View.GONE
                enteredPin = ""
                failedAttempts = 0
                errorText.visibility = View.GONE
                showUnlockMethodUI()
            }
            isNowLocked && wasShowingTimeLock -> {
                
                if (!isCountdownRunning) {
                    startTimeLockCountdown()
                }
            }
            else -> {
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        isShowing = false
currentlyBlockedPackage = null

Log.d(TAG, "User left app → reset lock state")
        
        if (pinCorrect || isFinishing || isDestroyed) return

        Log.d(TAG, "User left lock screen (home/recents) - sending to home, keeping app locked")
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        
    }

    override fun onPause() {
        super.onPause()
        
        if (!pinCorrect) {
            isShowing = false
        currentlyBlockedPackage = null

        Log.d(TAG, "AppLockActivity paused → reset isShowing = false")

        } else {
            
            timeLockCountdownTimer?.cancel()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        
        timeLockCountdownTimer?.cancel()
        timeLockCountdownTimer = null
        
        isShowing = false
        currentlyBlockedPackage = null
        if (!pinCorrect) {
            dismissedAt = System.currentTimeMillis()
            dismissedPackage = lockedPackage
            Log.d(TAG, " Lock screen destroyed without correct PIN for: $lockedPackage")
        } else {
            Log.d(TAG, " Lock screen destroyed after correct PIN for: $lockedPackage")
        }
    }
}
