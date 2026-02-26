import 'package:flutter/material.dart';
import '../../core/theme/theme_config.dart';

class AboutHelpScreen extends StatefulWidget {
  const AboutHelpScreen({super.key});

  @override
  State<AboutHelpScreen> createState() => _AboutHelpScreenState();
}

class _AboutHelpScreenState extends State<AboutHelpScreen> {
  @override
  void initState() {
    super.initState();
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.appBarBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeConfig.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About & Help',
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // ─── App Logo and Title Section ───
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.accentColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Shield Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ThemeConfig.accentColor(context).withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.shield,
                        size: 50,
                        color: ThemeConfig.accentColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'StealthSeal',
                      style: TextStyle(
                        color: ThemeConfig.textPrimary(context),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Privacy Guardian',
                      style: TextStyle(
                        color: ThemeConfig.accentColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: ThemeConfig.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ─── About This App ───
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.borderColor(context),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This App',
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'StealthSeal is an advanced mobile security application designed to protect your privacy through app locking, dual-PIN authentication, and intruder detection.',
                    style: TextStyle(
                      color: ThemeConfig.textSecondary(context),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'With features like stealth mode, location-based locking, and panic lock, StealthSeal ensures your personal data stays secure at all times.',
                    style: TextStyle(
                      color: ThemeConfig.textSecondary(context),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Development Team ───
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.borderColor(context),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Development Team',
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTeamRow('Developers:', 'Ravi Wavi', context),
                  const SizedBox(height: 12),
                  _buildTeamRow('Institution:', 'Tech Mumbai University', context),
                  const SizedBox(height: 12),
                  _buildTeamRow('Project Guide:', 'Dipti', context),
                  const SizedBox(height: 12),
                  _buildTeamRow('Year:', '2026', context),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Key Features ───
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.borderColor(context),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Features',
                    style: TextStyle(
                      color: ThemeConfig.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem('Dual-PIN authentication for privacy protection', context),
                  const SizedBox(height: 10),
                  _buildFeatureItem('Biometric fingerprint unlock', context),
                  const SizedBox(height: 10),
                  _buildFeatureItem('Intruder detection with photo capture', context),
                  const SizedBox(height: 10),
                  _buildFeatureItem('Time and location-based locking', context),
                  const SizedBox(height: 10),
                  _buildFeatureItem('Stealth mode for app disguise', context),
                  const SizedBox(height: 10),
                  _buildFeatureItem('Emergency panic lock', context),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Support Info ───
            Container(
              decoration: BoxDecoration(
                color: ThemeConfig.infoBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeConfig.infoColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ThemeConfig.infoColor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For support or feedback, contact us through the app settings',
                      style: TextStyle(
                        color: ThemeConfig.infoColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Helper Widgets ───

  /// Builds a labeled team information row with [label] and [value].
  Widget _buildTeamRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ThemeConfig.textSecondary(context),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: ThemeConfig.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Builds a feature list item with a check icon and description.
  Widget _buildFeatureItem(String feature, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle,
            size: 5,
            color: ThemeConfig.accentColor(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            feature,
            style: TextStyle(
              color: ThemeConfig.textSecondary(context),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
