import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme/theme_config.dart';

class StealthModeSettingsScreen extends StatefulWidget {
  const StealthModeSettingsScreen({super.key});

  @override
  State<StealthModeSettingsScreen> createState() =>
      _StealthModeSettingsScreenState();
}

class _StealthModeSettingsScreenState extends State<StealthModeSettingsScreen> {
  late Box _securityBox;
  late String _selectedMode; // 'normal', 'hidden', 'calculator'

  @override
  void initState() {
    super.initState();
    _securityBox = Hive.box('securityBox');
    _loadSettings();
  }

  void _loadSettings() {
    _selectedMode = _securityBox.get('stealthMode', defaultValue: 'normal');
  }

  void _setStealthMode(String mode) {
    setState(() => _selectedMode = mode);
    _securityBox.put('stealthMode', mode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stealth mode changed to: ${mode.toUpperCase()}'),
        backgroundColor: const Color(0xFF00BCD4),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeConfig.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Stealth Mode',
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: ThemeConfig.backgroundColor(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning Box
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB74D),
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stealth mode can make it harder to find this app, but may affect accessibility',
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Normal Mode
              GestureDetector(
                onTap: () => _setStealthMode('normal'),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConfig.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'normal'
                          ? ThemeConfig.accentColor(context)
                          : ThemeConfig.borderColor(context),
                      width: _selectedMode == 'normal' ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: ThemeConfig.accentColor(context),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Normal Mode',
                            style: TextStyle(
                              color: ThemeConfig.textPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'App visible in launcher',
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Radio<String>(
                        value: 'normal',
                        groupValue: _selectedMode,
                        onChanged: (value) {
                          if (value != null) {
                            _setStealthMode(value);
                          }
                        },
                        activeColor: ThemeConfig.accentColor(context),
                        fillColor: WidgetStateProperty.all(
                          ThemeConfig.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hidden Icon
              GestureDetector(
                onTap: () => _setStealthMode('hidden'),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConfig.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'hidden'
                          ? ThemeConfig.accentColor(context)
                          : ThemeConfig.borderColor(context),
                      width: _selectedMode == 'hidden' ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_off,
                        color: Color(0xFFB366CC),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hidden Icon',
                            style: TextStyle(
                              color: ThemeConfig.textPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Remove from app drawer',
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Radio<String>(
                        value: 'hidden',
                        groupValue: _selectedMode,
                        onChanged: (value) {
                          if (value != null) {
                            _setStealthMode(value);
                          }
                        },
                        activeColor: ThemeConfig.accentColor(context),
                        fillColor: WidgetStateProperty.all(
                          ThemeConfig.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Calculator Disguise
              GestureDetector(
                onTap: () => _setStealthMode('calculator'),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConfig.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'calculator'
                          ? ThemeConfig.accentColor(context)
                          : ThemeConfig.borderColor(context),
                      width: _selectedMode == 'calculator' ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        color: ThemeConfig.accentColor(context),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calculator Disguise',
                            style: TextStyle(
                              color: ThemeConfig.textPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Appears as calculator app',
                            style: TextStyle(
                              color: ThemeConfig.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Radio<String>(
                            value: 'calculator',
                            groupValue: _selectedMode,
                            onChanged: (value) {
                              if (value != null) {
                                _setStealthMode(value);
                              }
                            },
                            activeColor: ThemeConfig.accentColor(context),
                            fillColor: WidgetStateProperty.all(
                              ThemeConfig.accentColor(context),
                            ),
                          ),
                          if (_selectedMode == 'calculator')
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ThemeConfig.accentColor(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                decoration: BoxDecoration(
                  color: ThemeConfig.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeConfig.accentColor(context).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: ThemeConfig.accentColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your PIN will always be required to access the app',
                        style: TextStyle(
                          color: ThemeConfig.accentColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
