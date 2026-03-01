import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late String _currentRealPin;
  late String _currentDecoyPin;
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPins();
  }

  Future<void> _loadCurrentPins() async {
    try {
      final securityBox = Hive.box('securityBox');
      _currentRealPin = securityBox.get('realPin', defaultValue: '');
      _currentDecoyPin = securityBox.get('decoyPin', defaultValue: '');

      if (_currentRealPin.isEmpty || _currentDecoyPin.isEmpty) {

        final userId = await UserIdentifierService.getUserId();
        final response = await Supabase.instance.client
            .from('user_security')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          _currentRealPin = response['real_pin'] ?? '';
          _currentDecoyPin = response['decoy_pin'] ?? '';
        }
      }
    } catch (error) {
      debugPrint('Error loading current pins: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading current password'),
            backgroundColor: ThemeConfig.errorColor(context),
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {

    if (_currentPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please enter your current password');
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please enter a new password');
      return;
    }

    if (_confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please confirm your new password');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 4) {
      _showErrorSnackBar('Password must be at least 4 characters');
      return;
    }

    if (_currentPasswordController.text != _currentRealPin &&
        _currentPasswordController.text != _currentDecoyPin) {
      _showErrorSnackBar('Current password is incorrect');
      return;
    }
    

    setState(() => _isLoading = true);

    try {
      final userId = await UserIdentifierService.getUserId();
      final newPassword = _newPasswordController.text;

      bool isUpdatingRealPin = _currentPasswordController.text == _currentRealPin;

      // Save to Hive FIRST (guaranteed local storage)
      final securityBox = Hive.box('securityBox');
      if (isUpdatingRealPin) {
        await securityBox.put('realPin', newPassword);
        _currentRealPin = newPassword;
      } else {
        await securityBox.put('decoyPin', newPassword);
        _currentDecoyPin = newPassword;
      }
      debugPrint('Password updated in Hive');

      // Sync to Supabase
      try {
        await Supabase.instance.client
            .from('user_security')
            .upsert(
              {
                'id': userId,
                'real_pin': isUpdatingRealPin ? newPassword : _currentRealPin,
                'decoy_pin': isUpdatingRealPin ? _currentDecoyPin : newPassword,
              },
              onConflict: 'id',
            );
        debugPrint('Password synced to Supabase');
      } catch (supabaseError) {
        debugPrint('WARNING: Supabase sync failed: $supabaseError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Warning: Password saved locally but cloud sync failed. '
                'Check Supabase RLS policies.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (isUpdatingRealPin) {
        _showSuccessSnackBar('Real password changed successfully');
      } else {
        _showSuccessSnackBar('Decoy password changed successfully');
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (error) {
      debugPrint('Error changing password: $error');
      _showErrorSnackBar('Failed to change password: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.errorColor(context),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeConfig.infoColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ThemeConfig.infoColor(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: ThemeConfig.infoColor(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For security, you can change either your real or decoy password.',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Current Password',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                hintText: 'Enter current password',
                hintStyle: TextStyle(color: ThemeConfig.textSecondary(context)),
                filled: true,
                fillColor: ThemeConfig.inputBackground(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: ThemeConfig.accentColor(context),
                  ),
                  onPressed: () => setState(
                      () => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
              style: TextStyle(color: ThemeConfig.textPrimary(context)),
            ),
            const SizedBox(height: 20),
            Text(
              'New Password',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                hintText: 'Enter new password',
                hintStyle: TextStyle(color: ThemeConfig.textSecondary(context)),
                filled: true,
                fillColor: ThemeConfig.inputBackground(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility : Icons.visibility_off,
                    color: ThemeConfig.accentColor(context),
                  ),
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              style: TextStyle(color: ThemeConfig.textPrimary(context)),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm New Password',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                hintStyle: TextStyle(color: ThemeConfig.textSecondary(context)),
                filled: true,
                fillColor: ThemeConfig.inputBackground(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: ThemeConfig.accentColor(context),
                  ),
                  onPressed: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              style: TextStyle(color: ThemeConfig.textPrimary(context)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.accentColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConfig.textPrimary(context),
                          ),
                        ),
                      )
                    : Text(
                        'Change Password',
                        style: TextStyle(
                          color: ThemeConfig.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
