import 'package:hive/hive.dart';

/// Manages panic mode state.
///
/// When panic mode is active, only the real PIN can unlock the app.
/// All other PINs (including decoy) are rejected silently.
class PanicService {
  /// Hive box used for persisting security-related state.
  static final _securityBox = Hive.box('securityBox');

  /// Activates panic mode, restricting access to the real PIN only.
  static void activate() {
    _securityBox.put('panicLock', true);
  }

  /// Deactivates panic mode, restoring normal PIN behavior.
  static void deactivate() {
    _securityBox.put('panicLock', false);
  }

  /// Returns `true` if panic mode is currently active.
  static bool isActive() {
    return _securityBox.get('panicLock', defaultValue: false);
  }
}
