import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String? _validationError;

  void _onDigitPressed(String digit) {
    setState(() {
      _validationError = null;
      if (!_isConfirming) {
        if (_enteredPin.length < 6) _enteredPin += digit;
      } else {
        if (_confirmedPin.length < 6) _confirmedPin += digit;
      }
    });
  }

  void _onDeletePressed() {
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
    if (!_isConfirming) {
      if (_enteredPin.length < 4) {
        setState(() => _validationError = 'PIN must be at least 4 digits');
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

      final success = await ref
          .read(authNotifierProvider.notifier)
          .setupMasterPin(_enteredPin);

      if (!success && mounted) {
        final error = ref.read(authNotifierProvider).errorMessage;
        setState(() => _validationError = error ?? 'Failed to setup PIN');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmedPin : _enteredPin;
    const maxDigits = 6;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Brand Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 42,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isConfirming ? 'Confirm Master PIN' : 'Create Master PIN',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isConfirming
                    ? 'Re-enter your PIN to confirm'
                    : 'This PIN will derive your Zero-Knowledge encryption key.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxDigits, (index) {
                  final isFilled = index < currentPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? const Color(0xFF10B981)
                          : const Color(0xFF334155),
                      border: Border.all(
                        color: isFilled
                            ? const Color(0xFF10B981)
                            : const Color(0xFF475569),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),

              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationError!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Numeric Keypad
              _buildKeypad(),

              const SizedBox(height: 16),

              // Next / Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: currentPin.length >= 4 ? _handleNextOrSubmit : null,
                  child: Text(
                    _isConfirming ? 'Complete Setup' : 'Continue',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_isConfirming)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConfirming = false;
                      _enteredPin = '';
                      _confirmedPin = '';
                      _validationError = null;
                    });
                  },
                  child: const Text('Back to PIN Creation', style: TextStyle(color: Colors.white60)),
                ),
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
                onPressed: _onDeletePressed,
                icon: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 26),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: () => _onDigitPressed(digit),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
