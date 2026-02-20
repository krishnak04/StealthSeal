import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class AppLockService {
  static const MethodChannel _channel =
      MethodChannel('app_lock_channel');

  static final AppLockService _instance =
      AppLockService._internal();

  factory AppLockService() => _instance;

  AppLockService._internal();

  Function(String packageName)? _callback;

  void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onAppDetected") {
        final packageName = call.arguments as String;
        _handleAppDetected(packageName);
      }
    });
  }

  void setOnLockedAppDetectedCallback(
      Function(String packageName) callback) {
    _callback = callback;
  }

  void _handleAppDetected(String packageName) {
    final box = Hive.box('securityBox');
    final lockedApps =
        List<String>.from(box.get('lockedApps', defaultValue: []));

    if (lockedApps.contains(packageName)) {
      _callback?.call(packageName);
    }
  }
}
