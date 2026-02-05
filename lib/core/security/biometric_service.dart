import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // 🔐 Get box safely (no static crash)
  static Box _box() => Hive.box('security');

  // ===== Enable / Disable =====
  static Future<void> enable() async {
    await _box().put('biometricEnabled', true);
  }

  static Future<void> disable() async {
    await _box().put('biometricEnabled', false);
  }

  static bool isEnabled() {
    return _box().get('biometricEnabled', defaultValue: false);
  }

  // ===== Device Support =====
  static Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  // ===== Authenticate =====
  static Future<bool> authenticate() async {
    try {
      // Check if biometric is available
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        print('❌ BiometricService: Device cannot check biometrics');
        return false;
      }

      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        print('❌ BiometricService: Device not supported');
        return false;
      }

      print('✅ BiometricService: Starting authentication...');
      final result = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock StealthSeal',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      print('✅ BiometricService: Authentication result = $result');
      return result;
    } on Exception catch (e) {
      print('❌ BiometricService: Authentication error = $e');
      return false;
    }
  }
}
