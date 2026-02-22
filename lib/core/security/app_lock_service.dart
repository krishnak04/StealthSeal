import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';

class AppLockService {
  static const MethodChannel _channel =
      MethodChannel('com.stealthseal.app/applock');

  static final AppLockService _instance = AppLockService._internal();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


  factory AppLockService() => _instance;

  AppLockService._internal();

  Function(String packageName)? _callback;
  Timer? _monitoringTimer;
  String? _lastDetectedApp;

  void initialize() {
    debugPrint('🚀 AppLockService initializing...');

    // ✅ Listen for INCOMING method calls from native code
    _channel.setMethodCallHandler((call) async {
      debugPrint(
          '📥 Incoming method: ${call.method} | Args: ${call.arguments}');

      if (call.method == "onAppDetected") {
        final packageName = call.arguments as String;
        debugPrint('📱 Native event received: $packageName');
        _handleAppDetected(packageName);
      } else if (call.method == "showLockScreen") {
        final packageName = call.arguments as String;
        debugPrint('🔓 Native request to show lock screen: $packageName');
        _callback?.call(packageName);
      } else if (call.method == "showLockOverlay") {
        final packageName = call.arguments as String;
        debugPrint('🔓 Native request to show lock OVERLAY: $packageName');
        _callback?.call(packageName);
      }
    });

    // Start active monitoring as fallback
    _startActiveMonitoring();
  }

  /// Start active monitoring to check foreground app
  void _startActiveMonitoring() {
    _monitoringTimer?.cancel();
    debugPrint('⏱️ Starting active monitoring (every 500ms)...');

    _monitoringTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final currentApp =
            await _channel.invokeMethod<String>('getCurrentForegroundApp');

        if (currentApp != null) {
          if (currentApp != _lastDetectedApp) {
            _lastDetectedApp = currentApp;
            debugPrint('📡 Polling detected app: $currentApp');
            _handleAppDetected(currentApp);
          }
        }
      } catch (e) {
        debugPrint('❌ Error in active monitoring: $e');
      }
    });
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('ℹ️ Could not check accessibility service: $e');
      return false;
    }
  }

  void setOnLockedAppDetectedCallback(Function(String packageName) callback) {

    _callback = callback;
  }

  void _handleAppDetected(String packageName) {
    final box = Hive.box('securityBox');
    final lockedApps =
        List<String>.from(box.get('lockedApps', defaultValue: []));

    // Check if app is temporarily unlocked
    final tempUnlocked =
        List<String>.from(box.get('tempUnlockedApps', defaultValue: []));

    debugPrint(
        '🔍 App detected: $packageName | Locked: ${lockedApps.contains(packageName)} | TempUnlocked: ${tempUnlocked.contains(packageName)}');

    if (lockedApps.contains(packageName) &&
        !tempUnlocked.contains(packageName)) {
      debugPrint('🔒 LOCKED APP DETECTED (Flutter): $packageName');
      _callback?.call(packageName);
    }
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }
}

