import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';

class AppLockService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const MethodChannel _channel =
      MethodChannel('com.stealthseal.app/applock');

  static final AppLockService _instance = AppLockService._internal();

  factory AppLockService() => _instance;

  AppLockService._internal();

  Function(String packageName)? _callback;
  Timer? _monitoringTimer;
  String? _lastDetectedApp;

  void initialize() {
    debugPrint('AppLockService initializing...');

    _channel.setMethodCallHandler((call) async {
      debugPrint(
          'Incoming method: ${call.method} | Args: ${call.arguments}');

      if (call.method == "onAppDetected") {
        final packageName = call.arguments as String;
        debugPrint('Native event received: $packageName');
        _handleAppDetected(packageName);
      } else if (call.method == "showLockScreen") {
        final packageName = call.arguments as String;
        debugPrint('Native request to show lock screen: $packageName');
        _callback?.call(packageName);
      } else if (call.method == "showLockOverlay") {
        final packageName = call.arguments as String;
        debugPrint('Native request to show lock overlay: $packageName');
        _callback?.call(packageName);
      }
    });

    _startActiveMonitoring();
  }

  void _startActiveMonitoring() {
    _monitoringTimer?.cancel();
    debugPrint('Starting active monitoring (every 500ms)...');

    _monitoringTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final currentApp =
            await _channel.invokeMethod<String>('getCurrentForegroundApp');

        if (currentApp != null) {
          if (currentApp != _lastDetectedApp) {
            _lastDetectedApp = currentApp;
            debugPrint('Polling detected app: $currentApp');
            _handleAppDetected(currentApp);
          }
        }
      } catch (error) {
        debugPrint('Error in active monitoring: $error');
      }
    });
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (error) {
      debugPrint('Could not check accessibility service: $error');
      return false;
    }
  }

  void setOnLockedAppDetectedCallback(Function(String packageName) callback) {
    _callback = callback;
  }

  void _handleAppDetected(String packageName) {
    final securityBox = Hive.box('securityBox');
    final lockedApps =
        List<String>.from(securityBox.get('lockedApps', defaultValue: []));

    final temporarilyUnlockedApps =
        List<String>.from(securityBox.get('tempUnlockedApps', defaultValue: []));

    debugPrint(
        'App detected: $packageName | '
        'Locked: ${lockedApps.contains(packageName)} | '
        'TempUnlocked: ${temporarilyUnlockedApps.contains(packageName)}');

    if (lockedApps.contains(packageName) &&
        !temporarilyUnlockedApps.contains(packageName)) {
      debugPrint('Locked app detected (Flutter): $packageName');
      _callback?.call(packageName);
    }
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }
}
