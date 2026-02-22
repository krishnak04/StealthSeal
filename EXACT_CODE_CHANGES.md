# 🔧 INTEGRATION - Step-by-Step for AppLockActivity.kt

## What Was Fixed

✅ **Removed** `AppLockActivity_Updated_Example.kt` (was causing redeclaration errors)  
✅ **Verified** `PermissionBottomSheetHelper.kt` imports (already correct)  
✅ **Ready** for integration into actual `AppLockActivity.kt`

---

## ⚡ EXACT CODE CHANGES FOR AppLockActivity.kt

### Change 1: Add Variable Declarations
**Location:** In the `class AppLockActivity` body, with other private variables

```kotlin
private var permissionHelper: PermissionBottomSheetHelper? = null
private var isPermissionDialogShowing = false
```

**Full Example:**
```kotlin
class AppLockActivity : Activity() {
    // ... existing variables ...
    private var failedAttempts = 0
    private var pinCorrect = false
    
    // ADD THESE TWO:
    private var permissionHelper: PermissionBottomSheetHelper? = null
    private var isPermissionDialogShowing = false
    
    // ... rest of code ...
}
```

---

### Change 2: Initialize in onCreate()
**Location:** End of `onCreate()` method, after `setupKeypad()` call

```kotlin
// Initialize permission helper
permissionHelper = PermissionBottomSheetHelper(this)
```

**Full Context:**
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // ... existing setup code ...
    
    loadPins()
    initViews()
    setupKeypad()
    updateDots()
    
    // ADD THIS:
    permissionHelper = PermissionBottomSheetHelper(this)
}
```

---

### Change 3: Add Two New Helper Methods
**Location:** At end of class, before final closing brace

```kotlin
private fun shouldShowPermissionDialog(): Boolean {
    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
    val permissionDialogShown = prefs.getBoolean("permission_dialog_shown", false)
    
    if (permissionDialogShown) {
        Log.d(TAG, "permission_dialog_shown=true, skipping")
        return false
    }

    val overlayGranted = permissionHelper?.isDisplayOverAppsGranted() ?: false
    val usageGranted = permissionHelper?.isUsageAccessGranted() ?: false
    
    if (overlayGranted && usageGranted) {
        Log.d(TAG, "Both permissions already granted")
        prefs.edit().putBoolean("permission_dialog_shown", true).apply()
        return false
    }

    return true
}

private fun showPermissionDialogAfterUnlock() {
    if (isPermissionDialogShowing) {
        Log.d(TAG, "Permission dialog already showing")
        finish()
        return
    }

    isPermissionDialogShowing = true
    Log.d(TAG, "Showing permission bottom sheet dialog...")

    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
    
    permissionHelper?.showPermissionDialog(onGrantClick = {
        Log.d(TAG, "User clicked 'Go to set' button")
        prefs.edit().putBoolean("permission_dialog_shown", true).apply()
        
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isDestroyed) {
                finish()
            }
        }, 500)
    })

    Handler(Looper.getMainLooper()).postDelayed({
        if (!isDestroyed && isPermissionDialogShowing) {
            prefs.edit().putBoolean("permission_dialog_shown", true).apply()
            isPermissionDialogShowing = false
            if (!isDestroyed) {
                finish()
            }
        }
    }, 5000)
}
```

---

### Change 4: Modify validatePin() Method
**Location:** In the `validatePin()` method, find this section:

**FIND THIS:**
```kotlin
if (enteredPin == realPin || enteredPin == decoyPin) {
    // ✅ Correct PIN
    failedAttempts = 0
    pinCorrect = true
    Log.d(TAG, "✅ Correct PIN entered for: $lockedPackage")

    errorText.visibility = View.GONE

    // Mark as session-unlocked in SharedPreferences
    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
    val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
    val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
    unlockedSet.add(lockedPackage)
    prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

    Log.d(TAG, "🔓 Session-unlocked: $lockedPackage (total: ${unlockedSet.size})")

    // Finish this activity — the locked app is still underneath
    finish()
}
```

**REPLACE WITH:**
```kotlin
if (enteredPin == realPin || enteredPin == decoyPin) {
    // ✅ Correct PIN
    failedAttempts = 0
    pinCorrect = true
    Log.d(TAG, "✅ Correct PIN entered for: $lockedPackage")

    errorText.visibility = View.GONE

    // Mark as session-unlocked in SharedPreferences
    val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
    val currentUnlocked = prefs.getString("sessionUnlockedApps", "") ?: ""
    val unlockedSet = currentUnlocked.split(",").filter { it.isNotEmpty() }.toMutableSet()
    unlockedSet.add(lockedPackage)
    prefs.edit().putString("sessionUnlockedApps", unlockedSet.joinToString(",")).apply()

    Log.d(TAG, "🔓 Session-unlocked: $lockedPackage (total: ${unlockedSet.size})")

    // ✨ NEW: Check if we should show permission dialog
    if (!isPermissionDialogShowing && shouldShowPermissionDialog()) {
        showPermissionDialogAfterUnlock()
    } else {
        // Finish normally
        finish()
    }
}
```

---

### Change 5: Update onBackPressed()
**Location:** In `onBackPressed()` method

**FIND THIS:**
```kotlin
override fun onBackPressed() {
    // Don't allow back to bypass — go to home screen instead
    val homeIntent = Intent(Intent.ACTION_MAIN)
    homeIntent.addCategory(Intent.CATEGORY_HOME)
    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(homeIntent)
    finish()
}
```

**REPLACE WITH:**
```kotlin
override fun onBackPressed() {
    // If permission dialog is showing, don't allow back
    if (isPermissionDialogShowing) {
        Log.d(TAG, "Back pressed during permission dialog - ignoring")
        return
    }

    // Otherwise, go to home screen
    val homeIntent = Intent(Intent.ACTION_MAIN)
    homeIntent.addCategory(Intent.CATEGORY_HOME)
    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(homeIntent)
    finish()
}
```

---

### Change 6: Update onNewIntent()
**Location:** In `onNewIntent()` method, where you reset variables

**FIND THIS:**
```kotlin
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
```

**ADD THIS LINE:**
```kotlin
if (newPackage.isNotEmpty() && newPackage != lockedPackage) {
    // Different app — reset everything
    lockedPackage = newPackage
    appName = newAppName
    enteredPin = ""
    failedAttempts = 0
    pinCorrect = false
    isPermissionDialogShowing = false  // ADD THIS LINE
    errorText.visibility = View.GONE
    updateDots()
    currentlyBlockedPackage = lockedPackage
```

---

### Change 7: Update onUserLeaveHint()
**Location:** In `onUserLeaveHint()` method

**FIND THIS:**
```kotlin
override fun onUserLeaveHint() {
    super.onUserLeaveHint()
    Log.d(TAG, "🏠 User pressed Home from PIN screen, finishing")
    // Go Home explicitly BEFORE finish to minimize the window where
    // the locked app is briefly foreground
    val homeIntent = Intent(Intent.ACTION_MAIN)
    homeIntent.addCategory(Intent.CATEGORY_HOME)
    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(homeIntent)
    finish()
}
```

**REPLACE WITH:**
```kotlin
override fun onUserLeaveHint() {
    super.onUserLeaveHint()
    
    if (isPermissionDialogShowing) {
        Log.d(TAG, "User pressed Home during permission dialog")
        // Mark dialog as shown and let it finish naturally
        val prefs = getSharedPreferences("stealthseal_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("permission_dialog_shown", true).apply()
    }
    
    Log.d(TAG, "🏠 User pressed Home from PIN screen, finishing")
    val homeIntent = Intent(Intent.ACTION_MAIN)
    homeIntent.addCategory(Intent.CATEGORY_HOME)
    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(homeIntent)
    finish()
}
```

---

### Change 8: Update onDestroy()
**Location:** In `onDestroy()` method

**FIND THIS:**
```kotlin
override fun onDestroy() {
    super.onDestroy()
    isShowing = false
    currentlyBlockedPackage = null
    if (!pinCorrect) {
        dismissedAt = System.currentTimeMillis()
        dismissedPackage = lockedPackage
        Log.d(TAG, "🗑 PIN dismissed WITHOUT correct PIN for: $lockedPackage")
    } else {
        Log.d(TAG, "🗑 PIN destroyed after correct PIN for: $lockedPackage")
    }
}
```

**REPLACE WITH:**
```kotlin
override fun onDestroy() {
    super.onDestroy()
    isShowing = false
    currentlyBlockedPackage = null
    isPermissionDialogShowing = false  // ADD THIS LINE
    
    if (!pinCorrect) {
        dismissedAt = System.currentTimeMillis()
        dismissedPackage = lockedPackage
        Log.d(TAG, "🗑 PIN dismissed WITHOUT correct PIN for: $lockedPackage")
    } else {
        Log.d(TAG, "🗑 PIN destroyed after correct PIN for: $lockedPackage")
    }
}
```

---

## ✅ SUMMARY OF CHANGES

| Change | Type | Lines |
|--------|------|-------|
| 1. Add variables | Declaration | 2 lines |
| 2. Initialize in onCreate() | Initialization | 1 line |
| 3. Add two methods | New methods | 40+ lines |
| 4. Modify validatePin() | Logic change | 3 lines |
| 5. Update onBackPressed() | Logic change | 2 lines |
| 6. Update onNewIntent() | Add flag reset | 1 line |
| 7. Update onUserLeaveHint() | Logic change | 4 lines |
| 8. Update onDestroy() | Add flag reset | 1 line |

**Total: 8 changes, ~50 lines of code**

---

## 🔍 VERIFY YOUR CHANGES

After making all 8 changes, your file should:
- ✅ Compile without errors
- ✅ Have all references to `permissionHelper` resolved
- ✅ Have all references to `isPermissionDialogShowing` resolved
- ✅ Have `shouldShowPermissionDialog()` method defined
- ✅ Have `showPermissionDialogAfterUnlock()` method defined

---

## 🚀 NEXT STEP

After making these changes:
1. Save the file
2. Run: `flutter clean`
3. Run: `flutter build apk --debug`
4. Verify build succeeds ✅

---

**Ready to integrate? Make these 8 changes now!**
