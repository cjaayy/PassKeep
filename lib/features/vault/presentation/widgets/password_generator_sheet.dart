import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/password_generator.dart';

/// Modal bottom sheet for generating strong customizable passwords
class PasswordGeneratorSheet extends StatefulWidget {
  const PasswordGeneratorSheet({super.key});

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  late String _currentPassword;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _currentPassword = PasswordGenerator.generate(
        length: _length,
        includeUppercase: _includeUppercase,
        includeLowercase: _includeLowercase,
        includeNumbers: _includeNumbers,
        includeSymbols: _includeSymbols,
      );
    });
  }

  String _getStrengthLabel(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordGenerator.estimateStrength(_currentPassword);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Password Generator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: _regenerate,
                  icon: Icon(Icons.refresh_rounded, color: textPrimary),
                  tooltip: 'Regenerate',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Password Display Box (Borderless)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentPassword,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Strength bar & label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Strength:', style: TextStyle(color: textMuted, fontSize: 13)),
                Text(
                  _getStrengthLabel(strength),
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (strength.index + 1) / 5.0,
                backgroundColor: inputFill,
                valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 20),

            // Length Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Length', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                Text(
                  '$_length',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _length.toDouble(),
              min: 8,
              max: 32,
              divisions: 24,
              activeColor: textPrimary,
              inactiveColor: inputFill,
              onChanged: (val) {
                _length = val.round();
                _regenerate();
              },
            ),

            // Toggle Switches
            _buildOptionSwitch('Uppercase (A-Z)', _includeUppercase, (val) {
              _includeUppercase = val;
              _regenerate();
            }),
            _buildOptionSwitch('Lowercase (a-z)', _includeLowercase, (val) {
              _includeLowercase = val;
              _regenerate();
            }),
            _buildOptionSwitch('Numbers (0-9)', _includeNumbers, (val) {
              _includeNumbers = val;
              _regenerate();
            }),
            _buildOptionSwitch('Symbols (!@#\$%...)', _includeSymbols, (val) {
              _includeSymbols = val;
              _regenerate();
            }),

            const SizedBox(height: 18),

            // Use Password Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAction,
                  foregroundColor: onPrimaryAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, _currentPassword),
                child: const Text(
                  'USE GENERATED PASSWORD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
          Switch(
            value: value,
            activeThumbColor: textPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
