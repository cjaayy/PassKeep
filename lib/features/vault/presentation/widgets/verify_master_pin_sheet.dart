import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/vault_providers.dart';

/// Modal bottom sheet prompting the user to enter their 6-digit Master PIN
/// to unlock their session before viewing decrypted vault entries.
class VerifyMasterPinSheet extends ConsumerStatefulWidget {
  const VerifyMasterPinSheet({super.key});

  @override
  ConsumerState<VerifyMasterPinSheet> createState() => _VerifyMasterPinSheetState();
}

class _VerifyMasterPinSheetState extends ConsumerState<VerifyMasterPinSheet> {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _onDigitPressed(String digit) {
    if (_isVerifying || _pin.length >= 6) return;

    setState(() {
      _errorMessage = null;
      _pin += digit;
    });

    if (_pin.length == 6) {
      _submitPin();
    }
  }

  void _onDeletePressed() {
    if (_isVerifying || _pin.isEmpty) return;

    setState(() {
      _errorMessage = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submitPin() async {
    setState(() => _isVerifying = true);

    try {
      final isCorrect = await ref.read(authNotifierProvider.notifier).verifyMasterPin(_pin);

      if (isCorrect && mounted) {
        ref.read(isVaultSessionUnlockedProvider.notifier).state = true;
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() {
          _pin = '';
          _isVerifying = false;
          _errorMessage = 'Incorrect Master PIN. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pin = '';
          _isVerifying = false;
          _errorMessage = 'Verification error. Please try again.';
        });
      }
    }
  }

  Future<void> _onBiometricPressed() async {
    setState(() => _isVerifying = true);
    final isSuccess = await ref.read(authNotifierProvider.notifier).unlockWithBiometrics();

    if (isSuccess && mounted) {
      ref.read(isVaultSessionUnlockedProvider.notifier).state = true;
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const maxDots = 6;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final authState = ref.watch(authNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
              const SizedBox(height: 10),

              // Header Row: Close button on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  // Shield Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: inputFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 24,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Enter Master PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Authenticate to view encrypted vault entries',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // 6 PIN Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxDots, (index) {
                  final isFilled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? textPrimary
                          : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Error message or placeholder
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.darkDestructive,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SizedBox(height: 14),

              const SizedBox(height: 4),

              // Keypad
              _buildKeypad(authState.isBiometricsAvailable),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool showBiometrics) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showBiometrics)
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: _isVerifying ? null : _onBiometricPressed,
                  icon: Icon(Icons.fingerprint_rounded, color: textPrimary, size: 30),
                ),
              )
            else
              const SizedBox(width: 64, height: 64),
            _buildKeypadButton('0'),
            SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
                onPressed: _isVerifying ? null : _onDeletePressed,
                icon: Icon(Icons.backspace_outlined, color: textMuted, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return Container(
      key: Key('verify_keypad_$digit'),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: inputFill,
        shape: BoxShape.circle,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: _isVerifying ? null : () => _onDigitPressed(digit),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
