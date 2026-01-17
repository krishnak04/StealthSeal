import 'package:hive/hive.dart';

class PanicService {
  static final _box = Hive.box('securityBox');

  static void activate() {
    _box.put('panicLock', true);
  }

  static void deactivate() {
    _box.put('panicLock', false);
  }

  static bool isActive() {
    return _box.get('panicLock', defaultValue: false);
  }
}
