import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:stealthseal/core/security/time_lock_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'core/routes/app_routes.dart';
import 'core/services/user_identifier_service.dart';
import 'core/security/app_lock_service.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/auth/biometric_setup_screen.dart';
import 'screens/dashboard/real_dashboard.dart';
import 'screens/dashboard/fake_dashboard.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/debug/debug_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('securityBox');
  await Hive.openBox('security');
  await Hive.openBox('userBox');

  await UserIdentifierService.initialize();
  AppLockService().initialize();

  await Supabase.initialize(
    url: 'https://kzrctgdgjgbvakdzcmrr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6cmN0Z2RnamdidmFrZHpjbXJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMDM0ODAsImV4cCI6MjA4NzY3OTQ4MH0.8vAQ6P9l3dJ2dJ3TxfMZ3EpG3IoPewZcfaG___D52Xc',
  );

  runApp(
    DevicePreview(
      enabled: false,
      builder: (_) => const StealthSealApp(),
    ),
  );
}

class StealthSealApp extends StatefulWidget {
  const StealthSealApp({super.key});

  @override
  State<StealthSealApp> createState() => _StealthSealAppState();
}

class _StealthSealAppState extends State<StealthSealApp> {
  @override
  void initState() {
    super.initState();

    ThemeService.themeNotifier.value = ThemeService.getThemeMode();

    ThemeService.themeNotifier.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ThemeService.themeNotifier.value;

    final flutterThemeMode = switch (currentTheme) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp(
      navigatorKey: AppLockService.navigatorKey,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      themeMode: flutterThemeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.setup: (_) => const SetupScreen(),
        AppRoutes.biometricSetup: (_) => const BiometricSetupScreen(),
        AppRoutes.lock: (_) => const LockScreen(),
        AppRoutes.realDashboard: (_) => const RealDashboard(),
        AppRoutes.fakeDashboard: (_) => const FakeDashboard(),
        AppRoutes.timeLockService: (_) => const TimeLockScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.debug: (_) => const DebugScreen(),
      },
    );
  }
}
