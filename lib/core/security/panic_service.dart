import 'package:hive/hive.dart';

class PanicService {
  static final _securityBox = Hive.box('securityBox');

  static void activate() {
    _securityBox.put('panicLock', true);
  }

  static void deactivate() {
    _securityBox.put('panicLock', false);
  }

  static bool isActive() {
    return _securityBox.get('panicLock', defaultValue: false);
  }
}
