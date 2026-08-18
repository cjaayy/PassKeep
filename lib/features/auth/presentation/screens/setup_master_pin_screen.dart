import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

/// Screen for creating and confirming a Master PIN on first launch
class SetupMasterPinScreen extends ConsumerStatefulWidget {
  const SetupMasterPinScreen({super.key});

  @override
  ConsumerState<SetupMasterPinScreen> createState() => _SetupMasterPinScreenState();
}

class _SetupMasterPinScreenState extends ConsumerState<SetupMasterPinScreen> {
  String _enteredPin = '';
  String _confirmedPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _validationError;

  void _onDigitPressed(String digit) {
    if (_isLoading) return;

    bool shouldSubmit = false;

    setState(() {
      _validationError = null;
      if (!_isConfirming) {
        if (_enteredPin.length < 6) {
          _enteredPin += digit;
          if (_enteredPin.length == 6) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmedPin.length < 6) {
          _confirmedPin += digit;
          if (_confirmedPin.length == 6) {
            shouldSubmit = true;
          }
        }
      }
    });

    if (shouldSubmit) {
      _handleNextOrSubmit();
    }
  }

  void _onDeletePressed() {
    if (_isLoading) return;

    setState(() {
      _validationError = null;
      if (!_isConfirming) {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else {
        if (_confirmedPin.isNotEmpty) {
          _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1);
        }
      }
    });
  }

  Future<void> _handleNextOrSubmit() async {
    if (_isLoading) return;

    if (!_isConfirming) {
      if (_enteredPin.length < 6) {
        setState(() => _validationError = 'PIN must be exactly 6 digits');
        return;
      }
      setState(() {
        _isConfirming = true;
        _validationError = null;
      });
    } else {
      if (_confirmedPin != _enteredPin) {
        setState(() {
          _validationError = 'PINs do not match. Please try again.';
          _confirmedPin = '';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _validationError = null;
      });

      try {
        final success = await ref
            .read(authNotifierProvider.notifier)
            .setupMasterPin(_enteredPin);

        if (!mounted) return;

        if (success) {
          setState(() {
            _enteredPin = '';
            _confirmedPin = '';
            _isConfirming = false;
            _isLoading = false;
            _validationError = null;
          });

          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else {
          final error = ref.read(authNotifierProvider).errorMessage ?? 'Failed to configure Master PIN';
          setState(() {
            _isLoading = false;
            _validationError = error;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppTheme.darkDestructive,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        final error = 'Failed to configure Master PIN: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _validationError = error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.darkDestructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmedPin : _enteredPin;
    const maxDigits = 6;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Brand Icon (Borderless)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 42,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isConfirming ? 'Confirm Master PIN' : 'Create Master PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isConfirming
                    ? 'Re-enter your PIN to confirm'
                    : 'This PIN will derive your Zero-Knowledge encryption key.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // PIN Indicator Dots (Borderless)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxDigits, (index) {
                  final isFilled = index < currentPin.length;
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

              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationError!,
                  style: const TextStyle(
                    color: AppTheme.darkDestructive,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Numeric Keypad
              _buildKeypad(),

              const SizedBox(height: 16),

              // Next / Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('submit_pin_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAction,
                    foregroundColor: onPrimaryAction,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (currentPin.length >= 6 && !_isLoading) ? _handleNextOrSubmit : null,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onPrimaryAction,
                          ),
                        )
                      : Text(
                          _isConfirming ? 'Complete Setup' : 'Continue',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              if (_isConfirming) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConfirming = false;
                      _enteredPin = '';
                      _confirmedPin = '';
                      _validationError = null;
                    });
                  },
                  child: Text('Start Over', style: TextStyle(color: textMuted)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
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
            const SizedBox(width: 72, height: 72),
            _buildKeypadButton('0'),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: _onDeletePressed,
                icon: Icon(
                  Icons.backspace_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextMuted
                      : AppTheme.lightTextMuted,
                  size: 26,
                ),
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
