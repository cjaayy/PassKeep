import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/supabase_auth_providers.dart';

/// Lock screen shown when the vault is locked.
/// Prompts for Master PIN or Biometrics to decrypt.
class AuthLockScreen extends ConsumerStatefulWidget {
  const AuthLockScreen({super.key});

  @override
  ConsumerState<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends ConsumerState<AuthLockScreen> {
  String _pin = '';

  void _onDigitPressed(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
      });

      if (_pin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _submitPin() async {
    final success = await ref.read(authNotifierProvider.notifier).unlockWithPin(_pin);
    if (!success && mounted) {
      setState(() {
        _pin = '';
      });
    }
  }

  Future<void> _onBiometricPressed() async {
    await ref.read(authNotifierProvider.notifier).unlockWithBiometrics();
  }

  Future<void> _handleResetSession(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: Text(
          'Reset Session / Sign Out',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will sign you out and clear local cached session keys. Your cloud data remains safe in Supabase.',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
              foregroundColor: AppTheme.darkDestructive,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset & Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(supabaseUserProvider.notifier).signOut();
      ref.read(isVaultSessionUnlockedProvider.notifier).state = false;
      await ref.read(authNotifierProvider.notifier).resetSession();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    const maxDots = 6;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Shield Icon (Borderless)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 48,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'PassKeep Vault',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter Master PIN to Unlock',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // PIN Indicators (Borderless)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxDots, (index) {
                  final isFilled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? primaryAction : inputFill,
                    ),
                  );
                }),
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkDestructive.withValues(alpha: 0.15)
                        : AppTheme.lightDestructive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.darkDestructive,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Keypad
              _buildKeypad(authState.isBiometricsAvailable),

              const SizedBox(height: 16),

              // Emergency Reset / Sign Out button
              TextButton(
                onPressed: () => _handleResetSession(context),
                style: TextButton.styleFrom(
                  foregroundColor: textMuted,
                ),
                child: const Text(
                  'Having trouble? Reset Session / Sign Out',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showBiometrics)
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  onPressed: _onBiometricPressed,
                  icon: Icon(Icons.fingerprint_rounded, color: textPrimary, size: 36),
                ),
              )
            else
              const SizedBox(width: 72, height: 72),
            _buildKeypadButton('0'),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: _onDeletePressed,
                icon: Icon(Icons.backspace_outlined, color: textMuted, size: 26),
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
      key: Key('keypad_$digit'),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: inputFill,
        shape: BoxShape.circle,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: () => _onDigitPressed(digit),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
