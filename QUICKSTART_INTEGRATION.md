# ⚡ QUICK START - Permission Bottom Sheet Integration (5 Minutes)

## What You Have

✅ **9 production-ready files** for professional Android bottom sheet permission dialog
✅ **All XML layouts, drawables, animations** in place
✅ **Kotlin helper class** fully implemented
✅ **Example integration code** ready to use

---

## FASTEST PATH TO INTEGRATION

### Option 1: Copy-Paste Integration (2 minutes)

#### 1️⃣ Open Your AppLockActivity.kt
Current location: `android/app/src/main/kotlin/com/example/stealthseal/AppLockActivity.kt`

#### 2️⃣ Add These Imports (at the top, after existing imports)
```kotlin
// No new imports needed! PermissionBottomSheetHelper is in same package
```

#### 3️⃣ Add These Variable Declarations (in the `class AppLockActivity` body)
```kotlin
// Add with other private variables:
private var permissionHelper: PermissionBottomSheetHelper? = null
private var isPermissionDialogShowing = false
```

#### 4️⃣ Initialize in onCreate() (after `setupKeypad()` call)
```kotlin
// Add at end of onCreate():
permissionHelper = PermissionBottomSheetHelper(this)
```

#### 5️⃣ Add These Helper Methods (at end of class, before final closing brace)
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

#### 6️⃣ Modify validatePin() Method
Find the section where it says `✅ Correct PIN` and replace:

**OLD CODE:**
```kotlin
if (enteredPin == realPin || enteredPin == decoyPin) {
    // ✅ Correct PIN
    failedAttempts = 0
    pinCorrect = true
    Log.d(TAG, "✅ Correct PIN entered for: $lockedPackage")
    
    errorText.visibility = View.GONE
    
    // ... mark as session-unlocked ...
    
    // Finish this activity — the locked app is still underneath
    finish()
}
```

**NEW CODE:**
```kotlin
if (enteredPin == realPin || enteredPin == decoyPin) {
    // ✅ Correct PIN
    failedAttempts = 0
    pinCorrect = true
    Log.d(TAG, "✅ Correct PIN entered for: $lockedPackage")
    
    errorText.visibility = View.GONE
    
    // ... mark as session-unlocked ... (keep all existing code)
    
    // ✨ NEW: Check if we should show permission dialog
    if (!isPermissionDialogShowing && shouldShowPermissionDialog()) {
        showPermissionDialogAfterUnlock()
    } else {
        // Finish normally
        finish()
    }
}
```

#### 7️⃣ Update onNewIntent() 
Find the method and add this line in the section where you reset variables:
```kotlin
isPermissionDialogShowing = false  // ← Add this line
```

#### 8️⃣ Update onDestroy()
Add this line in the onDestroy method:
```kotlin
isPermissionDialogShowing = false  // ← Add this line
```

#### 9️⃣ Update onBackPressed()
Wrap the existing code in an if statement:
```kotlin
override fun onBackPressed() {
    if (isPermissionDialogShowing) {
        Log.d(TAG, "Back pressed during permission dialog - ignoring")
        return
    }
    
    // ... rest of existing code ...
}
```

---

## BUILD & TEST (3 minutes)

### Build the APK
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### Deploy to Device
```bash
flutter run --debug

# OR manually:
adb install -r build/app/outputs/apk/debug/app-debug.apk
```

### Quick Test
1. **Lock first app** → See bottom sheet appear after PIN ✅
2. **Tap "Go to set"** → Settings app opens ✅
3. **Return to app** → App opens normally ✅
4. **Lock second app** → No bottom sheet (already shown) ✅

---

## VERIFICATION CHECKLIST

- [ ] File `android/app/src/main/kotlin/com/example/stealthseal/PermissionBottomSheetHelper.kt` exists
- [ ] File `android/app/src/main/res/layout/permission_bottom_sheet.xml` exists
- [ ] File `android/app/src/main/res/drawable/permission_icon_background.xml` exists
- [ ] File `android/app/src/main/res/drawable/badge_background.xml` exists
- [ ] File `android/app/src/main/res/drawable/gradient_button_background.xml` exists
- [ ] File `android/app/src/main/res/anim/slide_up.xml` exists

All should exist ✅ See verification output above.

---

## TROUBLESHOOTING

| Issue | Solution |
|-------|----------|
| "Cannot find symbol: PermissionBottomSheetHelper" | Ensure file is in correct package: `com.example.stealthseal` |
| "Cannot find symbol: permission_bottom_sheet" | Ensure `permission_bottom_sheet.xml` is in `res/layout/` |
| Dialog doesn't appear | Check `shouldShowPermissionDialog()` - may already be marked as shown |
| Dialog appears twice | Check `isPermissionDialogShowing` flag initialization |
| "Go to set" button doesn't work | Verify your device/API level supports ACTION_MANAGE_OVERLAY_PERMISSION |

---

## ✨ RESULT AFTER INTEGRATION

```
User locks app → Enters PIN → Bottom sheet slides up ✨
Shows: Permission Required dialog
  - Blue icon with shield badge
  - Display over other apps toggle
  - Usage access toggle
  - "Go to set" button with gradient
→ User taps button → Settings opens
→ Returns to app → App continues normally
→ Locks another app → No dialog (already shown)
```

---

## 📚 MORE DOCUMENTATION

- **Full Implementation Guide**: `PERMISSION_BOTTOM_SHEET_IMPLEMENTATION.md`
- **Code Examples**: `android/app/src/main/kotlin/com/example/stealthseal/PERMISSION_DIALOG_INTEGRATION.md`
- **Complete Example**: `android/app/src/main/kotlin/com/example/stealthseal/AppLockActivity_Updated_Example.kt`
- **Phase Summary**: `PHASE_17_COMPLETE.md`

---

## 🎯 DONE!

After these 9 steps + build, you'll have a professional permission dialog working in your app.

**Time estimate**: 5-10 minutes total with testing on device.

Good luck! 🚀
