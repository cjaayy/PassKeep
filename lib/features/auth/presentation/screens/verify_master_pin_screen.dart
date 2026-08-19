import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/supabase_auth_providers.dart';

/// Screen displayed when signing into an existing cloud account on a fresh install.
/// Prompts the user for their existing 6-digit Master PIN to derive the encryption key
/// and restore vault access.
class VerifyMasterPinScreen extends ConsumerStatefulWidget {
  const VerifyMasterPinScreen({super.key});

  @override
  ConsumerState<VerifyMasterPinScreen> createState() =>
      _VerifyMasterPinScreenState();
}

class _VerifyMasterPinScreenState extends ConsumerState<VerifyMasterPinScreen> {
  String _pin = '';
  bool _isVerifying = false;
  String? _errorMessage;

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
      final success = await ref
          .read(authNotifierProvider.notifier)
          .unlockWithExistingPin(_pin);

      if (!mounted) return;

      if (success) {
        ref.read(isVaultSessionUnlockedProvider.notifier).state = true;
        // Trigger initial cloud sync and load items
        ref.read(syncNotifierProvider.notifier).sync();
        ref.read(vaultNotifierProvider.notifier).loadVaultItems();

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        final error = ref.read(authNotifierProvider).errorMessage ??
            'Incorrect Master PIN. Please try again.';
        setState(() {
          _pin = '';
          _isVerifying = false;
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pin = '';
          _isVerifying = false;
          _errorMessage = 'Verification error: ${e.toString()}';
        });
      }
    }
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
    const maxDots = 6;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final userState = ref.watch(supabaseUserProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Shield Icon (Borderless)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Enter Master PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter your existing Master PIN to unlock and decrypt your vault',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),

              if (userState.email != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 14, color: textMuted),
                      const SizedBox(width: 6),
                      Text(
                        userState.email!,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // PIN Dots (Borderless)
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

              if (_errorMessage != null) ...[
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
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.darkDestructive,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 12),

              const SizedBox(height: 16),

              // Keypad
              _buildKeypad(),

              const SizedBox(height: 16),

              // Emergency Reset / Sign Out button
              TextButton(
                onPressed: _isVerifying ? null : () => _handleResetSession(context),
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

  Widget _buildKeypad() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 72),
            _buildKeypadButton('0'),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: _isVerifying ? null : _onDeletePressed,
                icon: Icon(Icons.backspace_outlined, color: textMuted, size: 24),
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

    return InkWell(
      onTap: _isVerifying ? null : () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: inputFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
    );
  }
}
