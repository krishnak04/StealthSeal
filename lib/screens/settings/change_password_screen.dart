import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_config.dart';
import '../../core/services/user_identifier_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../widgets/pattern_lock_widget.dart';

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
  late String _currentUnlockPattern; // 4-digit, 6-digit, or pattern
  
  String _selectedPasswordType = 'Real PIN (4-digit)'; // Default selection
  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  
  // Pattern-related variables
  String _newPattern = '';
  String _patternStatus = '';
  Color _patternStatusColor = Colors.white70;
  bool _isVerifyingPattern = true; // true = verify current, false = set new

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
      _currentUnlockPattern = securityBox.get('unlockPattern', defaultValue: '4-digit');

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
      
      // Set default based on current pattern
      if (mounted) {
        setState(() {
          if (_currentUnlockPattern == 'pattern') {
            _selectedPasswordType = 'Real Pattern';
          } else {
            final pinLength = _currentRealPin.length;
            _selectedPasswordType = pinLength == 6 ? 'Real PIN (6-digit)' : 'Real PIN (4-digit)';
          }
        });
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

  List<String> _getPasswordTypeOptions() {
    return [
      'Real PIN (4-digit)',
      'Real PIN (6-digit)',
      'Real Pattern',
      'Decoy PIN (4-digit)',
      'Decoy PIN (6-digit)',
      'Decoy Pattern',
    ];
  }

  String _getPasswordTypeLabel(String type) {
    if (type.contains('Pattern')) {
      return type; // "Real Pattern" or "Decoy Pattern"
    } else if (type.contains('4-digit')) {
      return type; // "Real PIN (4-digit)" or "Decoy PIN (4-digit)"
    } else {
      return type; // "Real PIN (6-digit)" or "Decoy PIN (6-digit)"
    }
  }

  bool _isPatternType() {
    return _selectedPasswordType.contains('Pattern');
  }

  bool _isRealPin() {
    return _selectedPasswordType.startsWith('Real');
  }

  int _getExpectedPinLength() {
    if (_selectedPasswordType.contains('6-digit')) {
      return 6;
    }
    return 4;
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

    // Validate PIN length
    final expectedLength = _getExpectedPinLength();
    if (_newPasswordController.text.length != expectedLength) {
      _showErrorSnackBar('Password must be exactly $expectedLength digits');
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

      // Determine if updating real or decoy PIN based on selection
      bool isUpdatingRealPin = _isRealPin();

      final securityBox = Hive.box('securityBox');
      if (isUpdatingRealPin) {
        await securityBox.put('realPin', newPassword);
        _currentRealPin = newPassword;
      } else {
        await securityBox.put('decoyPin', newPassword);
        _currentDecoyPin = newPassword;
      }
      debugPrint('Password updated in Hive');

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
              'Select Password Type',
              style: TextStyle(
                color: ThemeConfig.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.inputBackground(context),
                border: Border.all(color: ThemeConfig.borderColor(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: _selectedPasswordType,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: ThemeConfig.surfaceColor(context),
                style: TextStyle(color: ThemeConfig.textPrimary(context)),
                items: _getPasswordTypeOptions()
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(_getPasswordTypeLabel(value)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPasswordType = newValue;
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                      // Reset pattern state when switching password types
                      _newPattern = '';
                      _patternStatus = '';
                      _patternStatusColor = Colors.white70;
                      _isVerifyingPattern = true;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            if (!_isPatternType())
              ..._buildPinChangeForm()
            else
              _buildPatternChangeForm(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPinChangeForm() {
    return [
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
    ];
  }

  Widget _buildPatternChangeForm() {
    // Show initial instruction if no status is set
    String displayStatus = _patternStatus;
    if (_patternStatus.isEmpty && _isVerifyingPattern) {
      displayStatus = 'Draw your current pattern to verify';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status message
        if (displayStatus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _patternStatusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _patternStatusColor),
            ),
            child: Row(
              children: [
                Icon(
                  _patternStatus.contains('successfully') ? Icons.check_circle : 
                  _patternStatus.contains('verified') ? Icons.verified :
                  Icons.info,
                  size: 18,
                  color: _patternStatusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: _patternStatusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        if (displayStatus.isNotEmpty) const SizedBox(height: 20),

        // Title
        Text(
          _isVerifyingPattern ? 'Verify Current Pattern' : (_newPattern.isEmpty ? 'Draw New Pattern' : 'Confirm Pattern'),
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isVerifyingPattern
              ? 'Draw your current pattern to verify access'
              : (_newPattern.isEmpty
                  ? 'Draw your new pattern (connect at least 4 dots)'
                  : 'Draw the same pattern again to confirm'),
          style: TextStyle(
            color: ThemeConfig.textSecondary(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),

        // Pattern widget
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 320,
              maxHeight: 320,
            ),
            child: PatternLockWidget(
              onPatternCompleted: _onPatternCompleted,
              dotColor: ThemeConfig.textSecondary(context),
              selectedColor: ThemeConfig.accentColor(context),
              showLines: true,
              minDots: 4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Reset/back button
        if (!_isVerifyingPattern)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _newPattern = '';
                _isVerifyingPattern = true;
                _patternStatus = '';
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Back to Verify',
                style: TextStyle(
                  color: ThemeConfig.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onPatternCompleted(String pattern) {
    // Get the current pattern to verify against based on selected type
    String currentPatternToVerify = '';
    if (_isRealPin()) {
      currentPatternToVerify = _currentRealPin;
    } else {
      currentPatternToVerify = _currentDecoyPin;
    }

    if (_isVerifyingPattern) {
      // Verify current pattern
      if (pattern == currentPatternToVerify) {
        setState(() {
          _isVerifyingPattern = false;
          _newPattern = '';
          _patternStatus = 'Pattern verified! Now draw your new pattern.';
          _patternStatusColor = Colors.green;
        });
      } else {
        setState(() {
          _patternStatus = 'Wrong pattern. Please try again.';
          _patternStatusColor = Colors.red;
        });
      }
    } else {
      // Set new pattern
      if (_newPattern.isEmpty) {
        setState(() {
          _newPattern = pattern;
          _patternStatus = 'Pattern saved. Draw it again to confirm.';
          _patternStatusColor = Colors.blue;
        });
      } else {
        // Confirm pattern
        if (pattern == _newPattern) {
          _saveNewPattern(pattern);
        } else {
          setState(() {
            _patternStatus = 'Patterns do not match. Draw again.';
            _patternStatusColor = Colors.red;
            _newPattern = '';
          });
        }
      }
    }
  }

  Future<void> _saveNewPattern(String pattern) async {
    setState(() => _isLoading = true);

    try {
      final userId = await UserIdentifierService.getUserId();
      final securityBox = Hive.box('securityBox');
      
      // Determine which PIN to update
      bool isUpdatingRealPin = _isRealPin();
      
      if (isUpdatingRealPin) {
        await securityBox.put('realPin', pattern);
        _currentRealPin = pattern;
      } else {
        await securityBox.put('decoyPin', pattern);
        _currentDecoyPin = pattern;
      }

      try {
        await Supabase.instance.client
            .from('user_security')
            .upsert(
              {
                'id': userId,
                'real_pin': isUpdatingRealPin ? pattern : _currentRealPin,
                'decoy_pin': isUpdatingRealPin ? _currentDecoyPin : pattern,
              },
              onConflict: 'id',
            );
      } catch (supabaseError) {
        debugPrint('WARNING: Supabase sync failed: $supabaseError');
      }

      if (mounted) {
        setState(() {
          _patternStatus = 'Pattern changed successfully!';
          _patternStatusColor = Colors.green;
          _newPattern = '';
        });
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (error) {
      debugPrint('Error saving pattern: $error');
      if (mounted) {
        setState(() {
          _patternStatus = 'Failed to save pattern: $error';
          _patternStatusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
