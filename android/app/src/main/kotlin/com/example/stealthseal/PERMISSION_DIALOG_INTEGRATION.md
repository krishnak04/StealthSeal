/**
 * Permission Bottom Sheet Integration Guide for StealthSeal
 * 
 * This file shows how to integrate the PermissionBottomSheetHelper
 * into your existing activities.
 */

// ============================================
// 1. IMPORT in Your Activity
// ============================================
import com.example.stealthseal.PermissionBottomSheetHelper


// ============================================
// 2. INSTANTIATE in onCreate() or when needed
// ============================================
class YourActivity : AppCompatActivity() {
    private lateinit var permissionHelper: PermissionBottomSheetHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.your_layout)

        // Initialize helper
        permissionHelper = PermissionBottomSheetHelper(this)
    }
}


// ============================================
// 3. SHOW DIALOG when user locks an app
// ============================================
// In AppLockManagementScreen or wherever apps are locked:

fun onAppLocked() {
    // Show the bottom sheet permission dialog
    permissionHelper.showPermissionDialog(onGrantClick = {
        // Optional: Called when user taps "Go to set"
        Log.d("AppLock", "User clicked to open settings")
        
        // Also open usage access settings if needed
        permissionHelper.openUsageAccessSettings()
    })
}


// ============================================
// 4. CHECK PERMISSIONS BEFORE PROCEEDING
// ============================================
fun checkPermissionsBeforeLocking(): Boolean {
    val overlayGranted = permissionHelper.isDisplayOverAppsGranted()
    val usageGranted = permissionHelper.isUsageAccessGranted()

    if (!overlayGranted || !usageGranted) {
        Log.w("AppLock", "Permissions not granted - showing dialog")
        permissionHelper.showPermissionDialog()
        return false
    }

    return true
}


// ============================================
// 5. From Flutter Integration
// ============================================
// In your AppLockService.dart or app_lock_management.dart:

Future<void> _showPermissionDialog() async {
    const platform = MethodChannel('com.stealthseal.app/applock');
    
    try {
        await platform.invokeMethod('showPermissionDialog');
        debugPrint('✅ Permission dialog shown');
    } catch (e) {
        debugPrint('❌ Error showing permission dialog: $e');
    }
}


// ============================================
// 6. KOTLIN METHOD CHANNEL HANDLER
// ============================================
// Add this to your MainActivity.kt or App Lock Activity:

private fun setupMethodChannels() {
    val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "com.stealthseal.app/applock")
    
    channel.setMethodCallHandler { call, result ->
        when (call.method) {
            "showPermissionDialog" -> {
                showPermissionDialog()
                result.success(true)
            }
            // ... other methods
            else -> result.notImplemented()
        }
    }
}

private fun showPermissionDialog() {
    val helper = PermissionBottomSheetHelper(this)
    helper.showPermissionDialog(onGrantClick = {
        Log.d("AppLock", "User confirmed permissions")
    })
}


// ============================================
// 7. LAYOUT INTEGRATION
// ============================================
// The permission_bottom_sheet.xml layout provides:
// - Icon container with blue background
// - "Display over other apps" toggle
// - "Usage access" toggle  
// - "Go to set" button with gradient
// - Smooth slide-up animation


// ============================================
// 8. CUSTOMIZATION
// ============================================
// To customize colors, edit:
// - android/app/src/main/res/drawable/permission_icon_background.xml (icon bg)
// - android/app/src/main/res/drawable/badge_background.xml (badge)
// - android/app/src/main/res/drawable/gradient_button_background.xml (button)
// - android/app/src/main/res/layout/permission_bottom_sheet.xml (layout)


// ============================================
// 9. FEATURES
// ============================================
// ✓ Bottom sheet dialog (smooth slide-up)
// ✓ Dark theme (#1E1E2E)
// ✓ Blue gradient button
// ✓ Two permission toggles
// ✓ Settings navigation
// ✓ Error handling & fallbacks
// ✓ Production-ready code
// ✓ Responsive layout
// ✓ Material Design compliant
