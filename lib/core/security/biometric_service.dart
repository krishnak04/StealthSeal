import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // 🔐 Get box safely (no static crash)
  static Box _box() => Hive.box('security');

  // ===== Enable / Disable =====
  /// Synchronously enable biometric for immediate effect
  static void enable() {
    try {
      _box().put('biometricEnabled', true);
      print('✅ Biometric enabled in Hive');
    } catch (e) {
      print('❌ Error enabling biometric: $e');
    }
  }

  /// Synchronously disable biometric for immediate effect
  static void disable() {
    try {
      _box().put('biometricEnabled', false);
      print('❌ Biometric disabled in Hive');
    } catch (e) {
      print('❌ Error disabling biometric: $e');
    }
  }

  /// Check if biometric is enabled
  static bool isEnabled() {
    try {
      return _box().get('biometricEnabled', defaultValue: false);
    } catch (e) {
      print('❌ Error checking biometric status: $e');
      return false;
    }
  }

  // ===== Device Support =====
  static Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final hasAvailable = await _auth.getAvailableBiometrics();
      
      print('🔍 Biometric Check:');
      print('   - canCheckBiometrics: $canCheck');
      print('   - isDeviceSupported: $isSupported');
      print('   - availableBiometrics: $hasAvailable');
      
      // Return true if device can check biometrics AND has any biometric type available
      return canCheck && hasAvailable.isNotEmpty;
    } catch (e) {
      print('❌ BiometricService: Device support check error = $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      print('📱 Available biometric types:');
      for (var biometric in available) {
        print('   - $biometric');
      }
      
      // Check specifically for fingerprint (covers in-display, side-mounted, etc.)
      final hasFingerprint = available.contains(BiometricType.fingerprint);
      final hasFace = available.contains(BiometricType.face);
      
      print('   Has Fingerprint: $hasFingerprint, Has Face: $hasFace');
      
      return available;
    } catch (e) {
      print('❌ Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if face recognition is available on device
  static Future<bool> isFaceSupported() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      final hasFace = available.contains(BiometricType.face);
      print('🔍 Face Recognition Check: $hasFace');
      if (hasFace) {
        print('   ✅ FaceID/Face Unlock is available on this device');
      } else {
        print('   ❌ Face recognition not available');
        print('      Available: $available');
      }
      return hasFace;
    } catch (e) {
      print('❌ Error checking face support: $e');
      return false;
    }
  }

  /// Check if fingerprint is available on device
  static Future<bool> isFingerprintSupported() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      final hasFingerprint = available.contains(BiometricType.fingerprint);
      print('🔍 Fingerprint Check: $hasFingerprint');
      if (hasFingerprint) {
        print('   ✅ Fingerprint is available on this device');
      } else {
        print('   ❌ Fingerprint not available');
      }
      return hasFingerprint;
    } catch (e) {
      print('❌ Error checking fingerprint support: $e');
      return false;
    }
  }

  // ===== Authenticate =====
  static Future<Map<String, dynamic>> authenticate() async {
    try {
      print('🔐 Starting Biometric Authentication...');
      
      // Step 1: Check if device can check biometrics
      final canCheck = await _auth.canCheckBiometrics;
      print('Step 1 - Can check biometrics: $canCheck');
      
      if (!canCheck) {
        print('❌ BiometricService: Device cannot check biometrics');
        return {
          'success': false,
          'message': 'Device cannot check biometrics. Use PIN instead.',
          'code': 'NO_BIOMETRIC_HARDWARE'
        };
      }

      // Step 2: Get available biometric types
      final availableBiometrics = await _auth.getAvailableBiometrics();
      print('Step 2 - Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        print('❌ BiometricService: No biometric types available on device');
        return {
          'success': false,
          'message': 'No biometric enrolled on your device. Please enroll fingerprint/face in device settings.',
          'code': 'NO_BIOMETRIC_ENROLLED'
        };
      }

      // Step 3: Check if device is supported
      final isSupported = await _auth.isDeviceSupported();
      print('Step 3 - Device is supported: $isSupported');

      // Step 3.5: Determine what biometrics are available
      final hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint);
      final hasFace = availableBiometrics.contains(BiometricType.face);
      
      print('Step 3.5 - Has Fingerprint: $hasFingerprint, Has Face: $hasFace');
      
      // Create appropriate reason message based on available biometrics
      String reasonMessage = 'Authenticate with ';
      if (hasFingerprint && hasFace) {
        reasonMessage += 'your fingerprint or face';
      } else if (hasFace) {
        reasonMessage += 'your face';
      } else if (hasFingerprint) {
        reasonMessage += 'your fingerprint';
      } else {
        reasonMessage += 'biometric';
      }
      reasonMessage += ' to unlock StealthSeal';

      // Step 4: Attempt authentication with optimized settings for all biometric types
      print('✅ Step 4 - Attempting biometric authentication...');
      print('   Reason: $reasonMessage');
      
      final result = await _auth.authenticate(
        localizedReason: reasonMessage,
        options: const AuthenticationOptions(
          stickyAuth: false,           // Don't keep auth dialog open
          useErrorDialogs: true,       // Show native error dialogs
          sensitiveTransaction: true,  // Explicit user confirmation
          biometricOnly: false,        // Allow both biometric and device credentials
        ),
      );
      
      print('✅ BiometricService: Authentication result = $result');
      
      if (result) {
        return {
          'success': true,
          'message': 'Biometric authentication successful',
          'code': 'SUCCESS'
        };
      } else {
        return {
          'success': false,
          'message': 'Biometric authentication cancelled or failed. Try again or use PIN.',
          'code': 'AUTH_FAILED'
        };
      }
    } on Exception catch (e) {
      print('❌ BiometricService: Authentication exception = $e');
      
      String errorMessage = 'Biometric authentication failed';
      String errorCode = 'UNKNOWN_ERROR';
      String exceptionStr = e.toString().toLowerCase();
      
      // Detailed error handling for common biometric issues
      if (exceptionStr.contains('no_biometrics') || 
          exceptionStr.contains('no biometric') ||
          exceptionStr.contains('not enrolled')) {
        errorMessage = 'No biometric enrolled. Go to device settings and register your fingerprint/face.';
        errorCode = 'NO_BIOMETRIC_ENROLLED';
      } else if (exceptionStr.contains('hw_unavailable') || 
                 exceptionStr.contains('hardware unavailable') ||
                 exceptionStr.contains('sensor not available')) {
        errorMessage = 'Biometric sensor unavailable. Check if your device has a working biometric sensor (fingerprint/face).';
        errorCode = 'HW_UNAVAILABLE';
      } else if (exceptionStr.contains('user_canceled') || 
                 exceptionStr.contains('cancelled')) {
        errorMessage = 'Authentication cancelled. Try again.';
        errorCode = 'USER_CANCELLED';
      } else if (exceptionStr.contains('lockout')) {
        errorMessage = 'Too many failed attempts. Try again later or use PIN.';
        errorCode = 'LOCKOUT';
      } else if (exceptionStr.contains('timeout')) {
        errorMessage = 'Authentication timed out. Try again.';
        errorCode = 'TIMEOUT';
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'code': errorCode,
        'error': e.toString()
      };
    }
  }

  /// Force re-initialization of biometric (useful if sensor needs reset)
  static Future<void> reinitializeBiometric() async {
    try {
      print('🔄 Reinitializing biometric...');
      // Get biometrics again to refresh
      await _auth.getAvailableBiometrics();
      print('✅ Biometric reinitialized');
    } catch (e) {
      print('❌ Error reinitializing biometric: $e');
    }
  }
}
