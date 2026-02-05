# StealthSeal Copilot Instructions

## Project Overview
**StealthSeal** is a Flutter privacy app that implements a decoy interface with multiple security layers. It protects user data using fake dashboards when accessed under duress, combined with multi-factor authentication and environmental locks.

## User Registration Flow

The complete user onboarding flow is:

1. **Splash Screen** → initializes Hive and Supabase
2. **Setup Screen** (`lib/screens/auth/setup_screen.dart`):
   - User sets real PIN (unlocks real dashboard)
   - User confirms real PIN
   - User sets decoy PIN (unlocks fake dashboard)
   - User confirms decoy PIN
   - PINs saved to Supabase `user_security` table
3. **Biometric Setup Screen** (`lib/screens/auth/biometric_setup_screen.dart`):
   - Device checks if biometric is supported
   - User can register fingerprint/face biometric (optional)
   - Biometric flag stored in Supabase `user_security.biometric_enabled`
   - User can skip to lock screen if not desired
4. **Lock Screen** → authentication gateway

## Biometric Registration Integration

The biometric setup screen appears **after PIN confirmation** and is **optional**. Key features:

- **Device Support Check**: Uses `BiometricService.isSupported()` to detect if fingerprint/face auth is available
- **Registration Flow**: User taps "Register Biometric" → authenticates with their device's biometric sensor
- **Database Sync**: On success, updates Supabase `user_security.biometric_enabled = true`
- **Local Storage**: `BiometricService.enable()` saves the setting to Hive
- **Skip Option**: Users can bypass biometric setup; biometric is disabled in DB and local storage
- **Security Notes**:
  - Biometric does NOT bypass Panic/Time/Location locks—PIN still required when they're active
  - Biometric is a convenience feature, not a replacement for PIN auth

### Biometric Setup Screen State Management

```dart
// Check device capability
final isSupported = await BiometricService.isSupported();

// Attempt biometric auth
final isAuthenticated = await BiometricService.authenticate();

// Update database
await supabase.from('user_security').update({
  'biometric_enabled': true,
}).eq('id', user.id);

// Enable locally
BiometricService.enable();
```
These are **singleton-like, state-managing services** that back the lock mechanism:

- **`panic_service.dart`**: Toggle panic mode via Hive local storage (`securityBox`). When active, ONLY the real PIN unlocks the app; any other PIN is rejected.
- **`biometric_service.dart`**: Wraps `local_auth` plugin with Hive-backed enable/disable flag. Biometric auth is a fast path but still respects panic/time/location locks.
- **`intruder_service.dart`**: Uses `camera` package to capture front-camera selfies on 3+ failed PIN attempts. Stores images + timestamps in Hive logs. **Fails silently to not break lock screen UX.**
- **`time_lock_service.dart`**: Checks if current time falls within a night-lock window (e.g., 10 PM → 6 AM). Uses Hive keys like `nightLockEnabled`, `nightStartHour`. Uses time-in-minutes math to handle midnight crossing correctly.
- **`location_lock_service.dart`**: Uses `geolocator` to compare user's current position against a trusted location (lat/lng + radius in meters). Returns `true` if outside trusted zone.

**Critical pattern**: Services store state in Hive `securityBox`, read synchronously where possible (`isActive()`, `isEnabled()`), and use `Future` only for I/O (camera, location, biometrics).

### Lock Screen Priority & Bypass Logic (`lib/screens/auth/lock_screen.dart`)
The lock screen enforces a **priority hierarchy** in `_validatePin()`:

1. **Location Lock** (highest): If outside trusted location, only real PIN works.
2. **Time Lock**: If within locked hours, only real PIN works.
3. **Panic Mode**: If active, only real PIN works; others are silently rejected.
4. **Normal Mode**: Real PIN → real dashboard; Decoy PIN → fake dashboard.
5. **Failed attempts**: 3+ failures trigger `IntruderService.captureIntruderSelfie()`.

Biometric bypass respects all three environmental locks—success still requires PIN if any lock is active.

### Dashboard Duality (`lib/screens/dashboard/`)
- **`real_dashboard.dart`**: True app interface (not shown in attached code but referenced in routes).
- **`fake_dashboard.dart`**: Decoy interface shown when decoy PIN is entered.

## Data Storage

- **Hive (`securityBox`)**: Stores PIN pairs (real/decoy), panic state, intruder logs, biometric flag, location coordinates.
- **Supabase**: Primary PIN storage (`user_security` table with `real_pin`, `decoy_pin`, `created_at`).
  - Lock screen loads PINs on init via `_loadPins()` using `maybeSingle()` to avoid crashes.
  - Uses `order('created_at', desc) limit(1)` to get most recent PIN config.

## Key Patterns & Conventions

### PIN Validation Flow
```dart
// Always check locks in priority order; reset enteredPin after validation
if (enteredPin == realPin) {
  failedAttempts = 0; // reset counter
  Navigator.pushReplacementNamed(context, AppRoutes.realDashboard);
} else if (enteredPin == decoyPin) {
  failedAttempts = 0;
  Navigator.pushReplacementNamed(context, AppRoutes.fakeDashboard);
} else {
  failedAttempts++;
  if (failedAttempts >= 3) {
    await IntruderService.captureIntruderSelfie(); // async but awaited
  }
}
setState(() => enteredPin = '');
```

### Async + Widget Lifecycle Safety
Always check `if (mounted)` before `setState()` after async operations:
```dart
if (mounted) {
  setState(() {
    realPin = data['real_pin'];
    decoyPin = data['decoy_pin'];
  });
}
```

### Location/Biometric Futures in UI
Use `FutureBuilder` for one-time async checks, not repeated polling:
```dart
FutureBuilder<bool>(
  future: LocationLockService.isOutsideTrustedLocation(),
  builder: (context, snapshot) {
    if (snapshot.data == true) return Text('LOCATION LOCK ACTIVE');
    return SizedBox.shrink();
  },
)
```

### Error Handling
- **Lock screen errors**: Catch, log with `debugPrint()`, show `SnackBar`, gracefully continue.
- **Service errors**: Fail silently (e.g., `IntruderService` swallows exceptions) to not disrupt lock UX.

## Build & Run

### Development
```bash
flutter pub get
flutter run -d <device_id>
# or with DevicePreview (enabled by default in main.dart)
flutter run
```

### Device Setup
- **Android**: Ensure `camera`, `geolocator`, `local_auth` permissions declared in `AndroidManifest.xml`.
- **iOS**: Add `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSFaceIDUsageDescription` to `Info.plist`.

### Dependencies
- `supabase_flutter`: Backend PIN sync.
- `hive` + `hive_flutter`: Local encrypted state (panic, biometrics, intruder logs).
- `camera`: Front-camera selfie capture.
- `geolocator`: Location verification.
- `local_auth`: Biometric auth.
- `device_preview`: Responsive testing (toggle `enabled: false` in main.dart for release).

## Common Workflows

### Adding a New Security Lock
1. Create a new service in `lib/core/security/` with Hive backing.
2. Add a check in `lock_screen.dart`'s `_validatePin()` method (respect priority order).
3. Add a UI indicator using `FutureBuilder` or conditional widget if the check is async.
4. Ensure the service fails gracefully; never crash the lock screen.

### Modifying PIN Validation
Edit `lock_screen.dart` → `_validatePin()` method. Always:
- Reset `enteredPin = ''` at the end.
- Check `if (mounted)` after async calls.
- Log failures with `debugPrint()` for debugging.

### Storing Settings in Hive
Use the `securityBox` opened in `main.dart`. Example:
```dart
final box = Hive.box('securityBox');
box.put('key', value);
final value = box.get('key', defaultValue: fallback);
```

## Testing Notes
- **Lock screen UX is critical**: Any service error should log silently, not break the UI.
- Test panic mode, time lock, and location lock with actual devices/emulators (mocking is complex).
- Intruder capture is intentionally silent on error to not alert a would-be attacker.

## References
- [Lock Screen Logic](lib/screens/auth/lock_screen.dart): Main entry point; orchestrates all security checks.
- [Panic Service](lib/core/security/panic_service.dart): Simple Hive toggle; highest override.
- [Location Service](lib/core/security/location_lock_service.dart): Geolocator distance math; handles permission flow.
- [Time Lock Service](lib/core/security/time_lock_service.dart): Time-in-minutes logic; handles midnight crossing.
- [Intruder Service](lib/core/security/intruder_service.dart): Camera capture; fails silently.
- [Biometric Service](lib/core/security/biometric_service.dart): Thin wrapper around `local_auth`; respects all locks.
