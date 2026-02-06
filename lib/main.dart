import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:stealthseal/core/security/time_lock_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core imports
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/services/user_identifier_service.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/auth/biometric_setup_screen.dart';
import 'screens/dashboard/real_dashboard.dart';
import 'screens/dashboard/fake_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Initialize Hive
  await Hive.initFlutter();

  // 🔹 OPEN boxes (this was the main bug)
  await Hive.openBox('securityBox'); // intruder logs
  await Hive.openBox('security');    // night lock, biometric, flags
  await Hive.openBox('userBox');     // user identification

  // 🔹 Initialize User Identifier Service
  await UserIdentifierService.initialize();

  // 🔹 Initialize Supabase
  await Supabase.initialize(
    url: 'https://aixxkzjrxqwnriygxaev.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpeHhrempyeHF3bnJpeWd4YWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NTY1NDcsImV4cCI6MjA4NDEzMjU0N30.6JuYjvtebNe5ojy9zuEK4T_TnyDsnw48rWr-1a8g3VI',
  );

  runApp(
    DevicePreview(
      enabled: false, // DISABLED FOR DEBUGGING - set true for release
      builder: (_) => const StealthSealApp(),
    ),
  );
}

class StealthSealApp extends StatelessWidget {
  const StealthSealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.setup: (_) => const SetupScreen(),
        AppRoutes.biometricSetup: (_) => const BiometricSetupScreen(),
        AppRoutes.lock: (_) => const LockScreen(),
        AppRoutes.realDashboard: (_) => const RealDashboard(),
        AppRoutes.fakeDashboard: (_) => const FakeDashboard(),
        AppRoutes.timeLockService: (_) => const TimeLockScreen(),
      },
    );
  }
  
}
