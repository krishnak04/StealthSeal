import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/security/biometric_service.dart';
import '../../core/theme/theme_service.dart';
import '../../core/theme/theme_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/user_identifier_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppThemeMode _selectedTheme;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = ThemeService.getThemeMode();
    _biometricEnabled = BiometricService.isEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppearanceSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildAdvancedFeaturesSection(context),
            const SizedBox(height: 24),
            _buildInformationSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeConfig.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildThemeOption(
                  icon: Icons.dark_mode,
                  label: 'Dark Mode',
                  value: AppThemeMode.dark,
                  context: context,
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  icon: Icons.light_mode,
                  label: 'Light Mode',
                  value: AppThemeMode.light,
                  context: context,
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  icon: Icons.brightness_auto,
                  label: 'System Default',
                  value: AppThemeMode.system,
                  context: context,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required AppThemeMode value,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () async {
        await ThemeService.setThemeMode(value);
        setState(() => _selectedTheme = value);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Theme changed to $label'),
              backgroundColor: ThemeConfig.accentColor(context),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _selectedTheme == value 
              ? ThemeConfig.accentColor(context).withOpacity(0.2)
              : ThemeConfig.inputBackground(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedTheme == value ? ThemeConfig.accentColor(context) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThemeConfig.accentColor(context), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: ThemeConfig.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_selectedTheme == value)
              Icon(Icons.check_circle, color: ThemeConfig.accentColor(context), size: 24)
            else
              Icon(Icons.radio_button_unchecked, color: ThemeConfig.borderColor(context), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeConfig.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.fingerprint, color: ThemeConfig.accentColor(context), size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric Unlock',
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Use fingerprint to unlock',
                          style: TextStyle(
                            color: ThemeConfig.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final supported = await BiometricService.isSupported();
                      if (!supported) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Biometric not supported on this device'),
                              backgroundColor: ThemeConfig.errorColor(context),
                            ),
                          );
                        }
                        return;
                      }
                      BiometricService.enable();
                    } else {
                      BiometricService.disable();
                    }
                    
                    // Update Supabase
                    try {
                      final userId = await UserIdentifierService.getUserId();
                      await Supabase.instance.client
                          .from('user_security')
                          .update({'biometric_enabled': value})
                          .eq('id', userId);
                      debugPrint(' Biometric updated in Supabase: $value');
                    } catch (e) {
                      debugPrint(' Error updating biometric in Supabase: $e');
                    }
                    
                    setState(() => _biometricEnabled = value);
                  },
                  activeColor: ThemeConfig.accentColor(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFeaturesSection(BuildContext context) {
    return Builder(
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeConfig.surfaceColor(ctx),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Features',
              style: TextStyle(
                color: ThemeConfig.textPrimary(ctx),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsItem(
              icon: Icons.schedule,
              label: 'Time-Based Locks',
              onTap: () => Navigator.pushNamed(context, AppRoutes.timeLockService),
              context: ctx,
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.location_on,
              label: 'Location-Based Locks',
              onTap: () {},
              context: ctx,
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.visibility_off,
              label: 'Stealth Mode',
              onTap: () {},
              context: ctx,
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.security,
              label: 'Permissions',
              onTap: () {},
              context: ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationSection(BuildContext context) {
    return Builder(
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeConfig.surfaceColor(ctx),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Information',
              style: TextStyle(
                color: ThemeConfig.textPrimary(ctx),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsItem(
              icon: Icons.info,
              label: 'About & Help',
              onTap: () {},
              context: ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeConfig.inputBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThemeConfig.accentColor(context), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: ThemeConfig.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward, color: ThemeConfig.accentColor(context), size: 18),
          ],
        ),
      ),
    );
  }
}
