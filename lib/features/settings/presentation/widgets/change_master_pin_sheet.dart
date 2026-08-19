import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// Steps in the Change Master PIN multi-step verification process
enum ChangePinStep {
  verifyCurrent,
  enterNew,
  confirmNew,
}

/// Modal bottom sheet guiding the user through changing their 6-digit Master PIN.
///
/// Flow:
/// 1. Verify Current PIN (checks with AuthNotifier.verifyMasterPin)
/// 2. Enter New PIN (stores new 6-digit candidate)
/// 3. Confirm New PIN (checks match & calls AuthNotifier.updateMasterPin)
class ChangeMasterPinSheet extends ConsumerStatefulWidget {
  const ChangeMasterPinSheet({super.key});

  @override
  ConsumerState<ChangeMasterPinSheet> createState() => _ChangeMasterPinSheetState();
}

class _ChangeMasterPinSheetState extends ConsumerState<ChangeMasterPinSheet> {
  ChangePinStep _step = ChangePinStep.verifyCurrent;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';

  String? _errorMessage;
  bool _isProcessing = false;

  String get _activePin {
    switch (_step) {
      case ChangePinStep.verifyCurrent:
        return _currentPin;
      case ChangePinStep.enterNew:
        return _newPin;
      case ChangePinStep.confirmNew:
        return _confirmPin;
    }
  }

  void _onDigitPressed(String digit) {
    if (_isProcessing) return;

    if (_activePin.length >= 6) return;

    setState(() {
      _errorMessage = null;
      switch (_step) {
        case ChangePinStep.verifyCurrent:
          _currentPin += digit;
          if (_currentPin.length == 6) {
            _handleVerifyCurrent();
          }
          break;
        case ChangePinStep.enterNew:
          _newPin += digit;
          if (_newPin.length == 6) {
            _handleEnterNew();
          }
          break;
        case ChangePinStep.confirmNew:
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            _handleConfirmNew();
          }
          break;
      }
    });
  }

  void _onDeletePressed() {
    if (_isProcessing || _activePin.isEmpty) return;

    setState(() {
      _errorMessage = null;
      switch (_step) {
        case ChangePinStep.verifyCurrent:
          _currentPin = _currentPin.substring(0, _currentPin.length - 1);
          break;
        case ChangePinStep.enterNew:
          _newPin = _newPin.substring(0, _newPin.length - 1);
          break;
        case ChangePinStep.confirmNew:
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          break;
      }
    });
  }

  Future<void> _handleVerifyCurrent() async {
    setState(() => _isProcessing = true);

    try {
      final isValid = await ref
          .read(authNotifierProvider.notifier)
          .verifyMasterPin(_currentPin);

      if (!mounted) return;

      if (isValid) {
        setState(() {
          _isProcessing = false;
          _step = ChangePinStep.enterNew;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _currentPin = '';
          _isProcessing = false;
          _errorMessage = 'Incorrect current Master PIN. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentPin = '';
          _isProcessing = false;
          _errorMessage = 'Verification error. Please try again.';
        });
      }
    }
  }

  void _handleEnterNew() {
    setState(() {
      _errorMessage = null;
      _step = ChangePinStep.confirmNew;
    });
  }

  Future<void> _handleConfirmNew() async {
    if (_confirmPin != _newPin) {
      setState(() {
        _confirmPin = '';
        _errorMessage = 'PINs do not match. Please try again.';
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .updateMasterPin(_currentPin, _newPin);

      if (!mounted) return;

      if (success) {
        ref.read(isVaultSessionUnlockedProvider.notifier).state = true;
        // Refresh vault items in memory
        await ref.read(vaultNotifierProvider.notifier).loadVaultItems();
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final error = ref.read(authNotifierProvider).errorMessage ??
            'Failed to update Master PIN';
        setState(() {
          _confirmPin = '';
          _isProcessing = false;
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _confirmPin = '';
          _isProcessing = false;
          _errorMessage = 'Failed to update PIN: ${e.toString()}';
        });
      }
    }
  }

  void _stepBack() {
    if (_isProcessing) return;

    setState(() {
      _errorMessage = null;
      if (_step == ChangePinStep.confirmNew) {
        _confirmPin = '';
        _newPin = '';
        _step = ChangePinStep.enterNew;
      } else if (_step == ChangePinStep.enterNew) {
        _newPin = '';
        _currentPin = '';
        _step = ChangePinStep.verifyCurrent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const maxDots = 6;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    String stepTitle;
    String stepSubtitle;
    IconData stepIcon;
    int currentStepIndex;

    switch (_step) {
      case ChangePinStep.verifyCurrent:
        stepTitle = 'Verify Current PIN';
        stepSubtitle = 'Enter your current 6-digit Master PIN to continue';
        stepIcon = Icons.lock_outline_rounded;
        currentStepIndex = 0;
        break;
      case ChangePinStep.enterNew:
        stepTitle = 'Create New PIN';
        stepSubtitle = 'Enter your new 6-digit Master PIN';
        stepIcon = Icons.pin_outlined;
        currentStepIndex = 1;
        break;
      case ChangePinStep.confirmNew:
        stepTitle = 'Confirm New PIN';
        stepSubtitle = 'Re-enter your new 6-digit Master PIN to verify';
        stepIcon = Icons.check_circle_outline_rounded;
        currentStepIndex = 2;
        break;
    }

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

              // Header navigation row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step != ChangePinStep.verifyCurrent)
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                      tooltip: 'Back',
                      onPressed: _stepBack,
                    )
                  else
                    const SizedBox(width: 48),

                  // Center icon badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: inputFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      stepIcon,
                      size: 24,
                      color: textPrimary,
                    ),
                  ),

                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Step Progress Pills
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index <= currentStepIndex;
                  final isCurrent = index == currentStepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 28 : 12,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isActive
                          ? (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
                          : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              Text(
                stepTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // 6 PIN Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxDots, (index) {
                  final isFilled = index < _activePin.length;
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
              const SizedBox(height: 10),

              // Error or loading message
              if (_isProcessing)
                SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing...',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.darkDestructive,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SizedBox(height: 20),

              const SizedBox(height: 6),

              // Keypad
              _buildKeypad(),

              const SizedBox(height: 8),
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
            const SizedBox(width: 64, height: 64),
            _buildKeypadButton('0'),
            SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
                onPressed: _isProcessing ? null : _onDeletePressed,
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

    return InkWell(
      onTap: _isProcessing ? null : () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: inputFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
    );
  }
}
