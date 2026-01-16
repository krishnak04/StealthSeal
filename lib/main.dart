import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/dashboard/real_dashboard.dart';
import 'screens/dashboard/fake_dashboard.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('securityBox');

  await Supabase.initialize(
    url: 'https://aixxkzjrxqwnriygxaev.supabase.co',
    anonKey:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpeHhrempyeHF3bnJpeWd4YWV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1NTY1NDcsImV4cCI6MjA4NDEzMjU0N30.6JuYjvtebNe5ojy9zuEK4T_TnyDsnw48rWr-1a8g3VI',
  );

  runApp(
    DevicePreview(
      enabled: true,
      builder: (_) => const StealthSealApp(),
    ),
  );
}

class StealthSealApp extends StatelessWidget {
  const StealthSealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true, // REQUIRED
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.setup: (_) => const SetupScreen(),
        AppRoutes.lock: (_) => const LockScreen(),
        AppRoutes.realDashboard: (_) => const RealDashboard(),
        AppRoutes.fakeDashboard: (_) => const FakeDashboard(),
      },
    );
  }
}
