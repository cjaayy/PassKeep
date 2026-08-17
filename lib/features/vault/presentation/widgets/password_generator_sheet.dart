import 'package:flutter/material.dart';
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

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFEF4444);
      case PasswordStrength.fair:
        return const Color(0xFFF97316);
      case PasswordStrength.good:
        return const Color(0xFFFBBF24);
      case PasswordStrength.strong:
        return const Color(0xFF10B981);
      case PasswordStrength.veryStrong:
        return const Color(0xFF059669);
    }
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
    final strengthColor = _getStrengthColor(strength);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password Generator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
                  tooltip: 'Regenerate',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Password Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
                const Text('Strength:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  _getStrengthLabel(strength),
                  style: TextStyle(color: strengthColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (strength.index + 1) / 5.0,
                backgroundColor: const Color(0xFF334155),
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),

            // Length Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Length', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text('$_length', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _length.toDouble(),
              min: 8,
              max: 32,
              divisions: 24,
              activeColor: const Color(0xFF10B981),
              inactiveColor: const Color(0xFF334155),
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
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, _currentPassword),
                child: const Text('Use Generated Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
