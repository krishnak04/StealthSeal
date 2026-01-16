import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';

import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/dashboard/real_dashboard.dart';
import 'screens/dashboard/fake_dashboard.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true, // turn off for production
      builder: (context) => const StealthSealApp(),
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
