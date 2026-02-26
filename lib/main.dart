import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:stealthseal/core/security/time_lock_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'core/routes/app_routes.dart';
import 'core/services/user_identifier_service.dart';
import 'core/security/app_lock_service.dart';

// Screens
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

  // Initialize local storage boxes
  await Hive.initFlutter();
  await Hive.openBox('securityBox'); // Intruder logs, locked apps, panic state
  await Hive.openBox('security');    // Night lock, biometric flags
  await Hive.openBox('userBox');     // User identification

  // Initialize services
  await UserIdentifierService.initialize();
  AppLockService().initialize(); // Listens for native app-lock events

  // Connect to Supabase backend
  await Supabase.initialize(
    url: 'https://aixxkzjrxqwnriygxaev.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpeHhrempyeHF3bnJpeWd4YWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NTY1NDcsImV4cCI6MjA4NDEzMjU0N30.6JuYjvtebNe5ojy9zuEK4T_TnyDsnw48rWr-1a8g3VI',
  );

  runApp(
    DevicePreview(
      enabled: false, // Set true to enable DevicePreview for testing
      builder: (_) => const StealthSealApp(),
    ),
  );
}

/// Root widget — manages theme switching and route registration.
class StealthSealApp extends StatefulWidget {
  const StealthSealApp({super.key});

  @override
  State<StealthSealApp> createState() => _StealthSealAppState();
}

class _StealthSealAppState extends State<StealthSealApp> {
  @override
  void initState() {
    super.initState();

    // Sync the theme notifier with the persisted preference
    ThemeService.themeNotifier.value = ThemeService.getThemeMode();

    // Rebuild the app whenever the user switches themes
    ThemeService.themeNotifier.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ThemeService.themeNotifier.value;

    // Map our custom enum to Flutter's built-in ThemeMode
    final flutterThemeMode = switch (currentTheme) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp(
      navigatorKey: AppLockService.navigatorKey, // Global nav for app-lock overlay
      useInheritedMediaQuery: true,
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