import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Box _securityBox() => Hive.box('security');

  static void enable() {
    try {
      _securityBox().put('biometricEnabled', true);
      debugPrint('Biometric enabled in Hive');
    } catch (error) {
      debugPrint('Error enabling biometric: $error');
    }
  }

  static void disable() {
    try {
      _securityBox().put('biometricEnabled', false);
      debugPrint('Biometric disabled in Hive');
    } catch (error) {
      debugPrint('Error disabling biometric: $error');
    }
  }

  static bool isEnabled() {
    try {
      return _securityBox().get('biometricEnabled', defaultValue: false);
    } catch (error) {
      debugPrint('Error checking biometric status: $error');
      return false;
    }
  }

  static Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      final availableBiometrics = await _auth.getAvailableBiometrics();

      debugPrint('Biometric Check:');
      debugPrint('   - canCheckBiometrics: $canCheck');
      debugPrint('   - isDeviceSupported: $deviceSupported');
      debugPrint('   - availableBiometrics: $availableBiometrics');

      return canCheck && availableBiometrics.isNotEmpty;
    } catch (error) {
      debugPrint('BiometricService: Device support check error = $error');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      debugPrint('Available biometric types:');
      for (var biometric in available) {
        debugPrint('   - $biometric');
      }

      final hasFingerprint = available.contains(BiometricType.fingerprint);
      final hasFace = available.contains(BiometricType.face);

      debugPrint('   Has Fingerprint: $hasFingerprint, Has Face: $hasFace');

      return available;
    } catch (error) {
      debugPrint('Error getting available biometrics: $error');
      return [];
    }
  }

  static Future<bool> isFaceSupported() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      final hasFace = available.contains(BiometricType.face);
      debugPrint('Face Recognition Check: $hasFace');
      if (hasFace) {
        debugPrint('   FaceID/Face Unlock is available on this device');
      } else {
        debugPrint('   Face recognition not available');
        debugPrint('      Available: $available');
      }
      return hasFace;
    } catch (error) {
      debugPrint('Error checking face support: $error');
      return false;
    }
  }

  static Future<bool> isFingerprintSupported() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      final hasFingerprint = available.contains(BiometricType.fingerprint);
      debugPrint('Fingerprint Check: $hasFingerprint');
      if (hasFingerprint) {
        debugPrint('   Fingerprint is available on this device');
      } else {
        debugPrint('   Fingerprint not available');
      }
      return hasFingerprint;
    } catch (error) {
      debugPrint('Error checking fingerprint support: $error');
      return false;
    }
  }

  static Future<Map<String, dynamic>> authenticate() async {
    try {
      debugPrint('Starting Biometric Authentication...');

      final canCheck = await _auth.canCheckBiometrics;
      debugPrint('Step 1 - Can check biometrics: $canCheck');

      if (!canCheck) {
        debugPrint('BiometricService: Device cannot check biometrics');
        return {
          'success': false,
          'message': 'Device cannot check biometrics. Use PIN instead.',
          'code': 'NO_BIOMETRIC_HARDWARE'
        };
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('Step 2 - Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        debugPrint('BiometricService: No biometric types available on device');
        return {
          'success': false,
          'message': 'No biometric enrolled on your device. '
              'Please enroll fingerprint/face in device settings.',
          'code': 'NO_BIOMETRIC_ENROLLED'
        };
      }

      final deviceSupported = await _auth.isDeviceSupported();
      debugPrint('Step 3 - Device is supported: $deviceSupported');

      final hasFingerprint =
          availableBiometrics.contains(BiometricType.fingerprint);
      final hasFace =
          availableBiometrics.contains(BiometricType.face);

      debugPrint(
          'Step 3.5 - Has Fingerprint: $hasFingerprint, Has Face: $hasFace');

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

      debugPrint('Step 4 - Attempting biometric authentication...');
      debugPrint('   Reason: $reasonMessage');

      final authResult = await _auth.authenticate(
        localizedReason: reasonMessage,
        options: const AuthenticationOptions(
          stickyAuth: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
          biometricOnly: false,
        ),
      );

      debugPrint('BiometricService: Authentication result = $authResult');

      if (authResult) {
        return {
          'success': true,
          'message': 'Biometric authentication successful',
          'code': 'SUCCESS'
        };
      } else {
        return {
          'success': false,
          'message': 'Biometric authentication cancelled or failed. '
              'Try again or use PIN.',
          'code': 'AUTH_FAILED'
        };
      }
    } on Exception catch (error) {
      debugPrint('BiometricService: Authentication exception = $error');

      String errorMessage = 'Biometric authentication failed';
      String errorCode = 'UNKNOWN_ERROR';
      String exceptionStr = error.toString().toLowerCase();

      if (exceptionStr.contains('no_biometrics') ||
          exceptionStr.contains('no biometric') ||
          exceptionStr.contains('not enrolled')) {
        errorMessage = 'No biometric enrolled. Go to device settings '
            'and register your fingerprint/face.';
        errorCode = 'NO_BIOMETRIC_ENROLLED';
      } else if (exceptionStr.contains('hw_unavailable') ||
                 exceptionStr.contains('hardware unavailable') ||
                 exceptionStr.contains('sensor not available')) {
        errorMessage = 'Biometric sensor unavailable. Check if your '
            'device has a working biometric sensor (fingerprint/face).';
        errorCode = 'HW_UNAVAILABLE';
      } else if (exceptionStr.contains('user_canceled') ||
                 exceptionStr.contains('cancelled')) {
        errorMessage = 'Authentication cancelled. Try again.';
        errorCode = 'USER_CANCELLED';
      } else if (exceptionStr.contains('lockout')) {
        errorMessage = 'Too many failed attempts. '
            'Try again later or use PIN.';
        errorCode = 'LOCKOUT';
      } else if (exceptionStr.contains('timeout')) {
        errorMessage = 'Authentication timed out. Try again.';
        errorCode = 'TIMEOUT';
      }

      return {
        'success': false,
        'message': errorMessage,
        'code': errorCode,
        'error': error.toString()
      };
    }
  }

  static Future<void> reinitializeBiometric() async {
    try {
      debugPrint('Reinitializing biometric...');

      await _auth.getAvailableBiometrics();
      debugPrint('Biometric reinitialized');
    } catch (error) {
      debugPrint('Error reinitializing biometric: $error');
    }
  }
}
