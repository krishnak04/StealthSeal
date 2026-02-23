import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/theme_config.dart';

class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key});

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  late String _selectedPattern;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPattern();
  }

  Future<void> _loadCurrentPattern() async {
    try {
      final box = Hive.box('securityBox');
      final pattern = box.get('unlockPattern', defaultValue: '4-digit');
      
      if (mounted) {
        setState(() {
          _selectedPattern = pattern;
          _isLoading = false;
        });
      }
      debugPrint('Loaded pattern: $_selectedPattern');
    } catch (e) {
      debugPrint('Error loading pattern: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePattern(String pattern) async {
    setState(() => _isLoading = true);
    
    try {
      final box = Hive.box('securityBox');
      await box.put('unlockPattern', pattern);

      // Verify it was saved
      final saved = box.get('unlockPattern');
      debugPrint(' Pattern saved: $saved (requested: $pattern)');

      setState(() {
        _selectedPattern = pattern;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Pattern changed to $pattern'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint(' Error updating pattern: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update pattern'),
            backgroundColor: ThemeConfig.errorColor(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Type'),
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.accentColor(context),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password Type',
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your preferred password type',
                    style: TextStyle(
                      color: ThemeConfig.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPatternOption(
                    context: context,
                    title: '4-digit PIN',
                    description: 'Numeric PIN\nExample: 1234',
                    pattern: '4-digit',
                    icon: Icons.dialpad,
                  ),
                  const SizedBox(height: 12),
                  _buildPatternOption(
                    context: context,
                    title: '6-digit PIN',
                    description: 'Longer numeric PIN\nExample: 123456',
                    pattern: '6-digit',
                    icon: Icons.pin,
                  ),
                  const SizedBox(height: 12),
                  _buildPatternOption(
                    context: context,
                    title: 'Knock code',
                    description: 'Pattern-based unlock\nSequence of taps',
                    pattern: 'knock-code',
                    icon: Icons.gesture,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeConfig.infoColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ThemeConfig.infoColor(context),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info,
                                color: ThemeConfig.infoColor(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Current Pattern: $_selectedPattern',
                                style: TextStyle(
                                  color: ThemeConfig.textPrimary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Knock code is more secure. Your chosen pattern will be used for future authentication.',
                          style: TextStyle(
                            color: ThemeConfig.textPrimary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPatternOption({
    required BuildContext context,
    required String title,
    required String description,
    required String pattern,
    required IconData icon,
  }) {
    final isSelected = _selectedPattern == pattern;

    return GestureDetector(
      onTap: _isLoading ? null : () => _updatePattern(pattern),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeConfig.accentColor(context).withOpacity(0.15)
              : ThemeConfig.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ThemeConfig.accentColor(context)
                : ThemeConfig.borderColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeConfig.accentColor(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: ThemeConfig.accentColor(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: ThemeConfig.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: ThemeConfig.accentColor(context),
                size: 28,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: ThemeConfig.borderColor(context),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
