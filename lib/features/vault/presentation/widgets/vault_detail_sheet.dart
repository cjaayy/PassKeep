import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/clipboard_service.dart';
import '../../data/models/card_details.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_providers.dart';
import '../screens/add_edit_vault_screen.dart';

/// Bottom sheet displaying decrypted details for a selected VaultItem
class VaultDetailSheet extends ConsumerStatefulWidget {
  final VaultItem item;

  const VaultDetailSheet({super.key, required this.item});

  @override
  ConsumerState<VaultDetailSheet> createState() => _VaultDetailSheetState();
}

class _VaultDetailSheetState extends ConsumerState<VaultDetailSheet> {
  // Login fields
  bool _isPasswordVisible = false;
  String _plainUsername = '';
  String _plainPassword = '';

  // Payment Card fields
  bool _isCardNumberVisible = false;
  bool _isCvvVisible = false;
  CardDetails _cardDetails = const CardDetails();

  String? _decryptionError;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _decryptCredentials();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _decryptCredentials() {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);

      if (widget.item.isCard) {
        if (widget.item.cardDetailsEnc != null && widget.item.cardDetailsEnc!.isNotEmpty) {
          final decryptedJson = encryptionService.decrypt(
            cipherTextBase64: widget.item.cardDetailsEnc!,
            ivBase64: widget.item.iv,
          );
          _cardDetails = CardDetails.fromJson(decryptedJson);
        } else {
          final cardholder = encryptionService.decrypt(
            cipherTextBase64: widget.item.usernameEncrypted,
            ivBase64: widget.item.iv,
          );
          final cardNumber = encryptionService.decrypt(
            cipherTextBase64: widget.item.passwordEncrypted,
            ivBase64: widget.item.iv,
          );
          _cardDetails = CardDetails(
            cardholderName: cardholder,
            cardNumber: cardNumber,
          );
        }
      } else {
        final user = encryptionService.decrypt(
          cipherTextBase64: widget.item.usernameEncrypted,
          ivBase64: widget.item.iv,
        );
        final pass = encryptionService.decrypt(
          cipherTextBase64: widget.item.passwordEncrypted,
          ivBase64: widget.item.iv,
        );
        _plainUsername = user;
        _plainPassword = pass;
      }

      setState(() {
        _decryptionError = null;
      });
    } catch (e) {
      setState(() {
        _decryptionError = 'Failed to decrypt credentials. Master key invalid or payload corrupted.';
      });
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });

    _autoHideTimer?.cancel();
    if (_isPasswordVisible) {
      _autoHideTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isPasswordVisible = false);
        }
      });
    }
  }

  void _toggleCvvVisibility() {
    setState(() {
      _isCvvVisible = !_isCvvVisible;
    });

    _autoHideTimer?.cancel();
    if (_isCvvVisible) {
      _autoHideTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isCvvVisible = false);
        }
      });
    }
  }

  Future<void> _copyUsername() async {
    await ClipboardService.copyWithAutoClear(_plainUsername);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username copied to clipboard.'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyAccountNumber(String number) async {
    await ClipboardService.copyWithAutoClear(number);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account / Phone number copied to clipboard.'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyPassword() async {
    await ClipboardService.copyWithAutoClear(_plainPassword);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('Password copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyCardNumber() async {
    final clean = _cardDetails.cardNumber.replaceAll(RegExp(r'\s+'), '');
    await ClipboardService.copyWithAutoClear(clean);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.credit_card_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('Card number copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyCvv() async {
    await ClipboardService.copyWithAutoClear(_cardDetails.cvv);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('CVV copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Vault Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${widget.item.title}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await ref.read(vaultNotifierProvider.notifier).deleteItem(widget.item.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted.'),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
    }
  }

  Widget _buildVirtualCard() {
    final brand = _cardDetails.brand;
    final formattedNumber = _cardDetails.cardNumber.isNotEmpty
        ? _cardDetails.cardNumber
        : '•••• •••• •••• ••••';
    final displayCardNumber = _isCardNumberVisible
        ? formattedNumber
        : _cardDetails.maskedCardNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank Name + Brand Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.item.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  brand.displayName.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // EMV Chip + Contactless Wave Icon
          Row(
            children: [
              Container(
                width: 36,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26, width: 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.contactless_rounded, color: Colors.white38, size: 20),
            ],
          ),
          const SizedBox(height: 20),

          // Card Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayCardNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isCardNumberVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _isCardNumberVisible = !_isCardNumberVisible),
                    tooltip: 'Toggle Mask',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 18),
                    onPressed: _copyCardNumber,
                    tooltip: 'Copy Card Number',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cardholder + Expiration Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARDHOLDER',
                    style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardDetails.cardholderName.isNotEmpty
                        ? _cardDetails.cardholderName.toUpperCase()
                        : 'CARD MEMBER',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardDetails.expiryDate.isNotEmpty ? _cardDetails.expiryDate : 'MM/YY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCard = widget.item.isCard;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
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
              const SizedBox(height: 18),

              // Header: Title + Category + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCard ? 'PAYMENT CARD' : widget.item.category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit Button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    tooltip: 'Edit Item',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditVaultScreen(existingItem: widget.item),
                        ),
                      );
                    },
                  ),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    tooltip: 'Delete Item',
                    onPressed: _confirmDelete,
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 32),

              if (_decryptionError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Decryption Failed',
                            style: TextStyle(
                              color: Color(0xFFF87171),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _decryptionError!,
                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This entry may have been encrypted with a different Master PIN or is corrupted. You can safely delete it below.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Delete Corrupted Entry'),
                          onPressed: _confirmDelete,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isCard) ...[
                // PAYMENT CARD VIEW
                _buildVirtualCard(),
                const SizedBox(height: 20),

                // Cardholder Name Card
                if (_cardDetails.cardholderName.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Cardholder Name',
                    content: _cardDetails.cardholderName,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                      onPressed: () {
                        ClipboardService.copyWithAutoClear(_cardDetails.cardholderName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cardholder name copied.'),
                            backgroundColor: Color(0xFF1E293B),
                          ),
                        );
                      },
                      tooltip: 'Copy Cardholder Name',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Card Number Card
                _buildFieldCard(
                  title: 'Card Number',
                  content: _isCardNumberVisible ? _cardDetails.cardNumber : _cardDetails.maskedCardNumber,
                  isMonospace: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isCardNumberVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _isCardNumberVisible = !_isCardNumberVisible),
                        tooltip: 'Toggle Mask',
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                        onPressed: _copyCardNumber,
                        tooltip: 'Copy Card Number',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Expiry Date and CVV Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldCard(
                        title: 'Expires',
                        content: _cardDetails.expiryDate.isNotEmpty ? _cardDetails.expiryDate : 'MM/YY',
                        isMonospace: true,
                        trailing: null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildFieldCard(
                        title: 'CVV / CVC',
                        content: _isCvvVisible ? _cardDetails.cvv : '•••',
                        isMonospace: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isCvvVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: _toggleCvvVisibility,
                              tooltip: 'Toggle CVV',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 18),
                              onPressed: _copyCvv,
                              tooltip: 'Copy CVV',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isCvvVisible)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0, left: 4.0),
                    child: Text(
                      'CVV auto-hiding in 10 seconds for security.',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // Notes Field
                if (widget.item.notes != null && widget.item.notes!.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Notes',
                    content: widget.item.notes!,
                    trailing: null,
                  ),
                  const SizedBox(height: 14),
                ],

                // Metadata
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Text(
                    'Last updated: ${widget.item.updatedAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ] else ...[
                // LOGIN / PASSWORD VIEW
                () {
                  final rawAccount = widget.item.accountNumber?.trim() ?? '';
                  final rawUser = _plainUsername.trim();

                  final hasExplicitAccount = rawAccount.isNotEmpty;
                  final isUserSameAsAccount = hasExplicitAccount && rawUser == rawAccount;
                  final isUserNumericPhone =
                      RegExp(r'^[0-9+\s\-()]+$').hasMatch(rawUser) && !rawUser.contains('@');

                  final shouldShowUsername = rawUser.isNotEmpty &&
                      !isUserSameAsAccount &&
                      (!isUserNumericPhone || hasExplicitAccount);
                  final shouldShowAccount =
                      hasExplicitAccount || (rawUser.isNotEmpty && isUserNumericPhone);
                  final displayAccountNumber = hasExplicitAccount ? rawAccount : rawUser;

                  return Column(
                    children: [
                      if (shouldShowUsername) ...[
                        _buildFieldCard(
                          title: 'Username / Email',
                          content: rawUser,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                            onPressed: _copyUsername,
                            tooltip: 'Copy Username',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (shouldShowAccount) ...[
                        _buildFieldCard(
                          title: 'Account / Phone Number',
                          content: displayAccountNumber,
                          isMonospace: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                            onPressed: () => _copyAccountNumber(displayAccountNumber),
                            tooltip: 'Copy Account Number',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                }(),

                // Password field
                _buildFieldCard(
                  title: 'Password',
                  content: _isPasswordVisible ? _plainPassword : '••••••••••••••••',
                  isMonospace: _isPasswordVisible,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
                        onPressed: _togglePasswordVisibility,
                        tooltip: _isPasswordVisible ? 'Hide (10s auto-hide)' : 'Show Password',
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                        onPressed: _copyPassword,
                        tooltip: 'Copy Password (30s auto-wipe)',
                      ),
                    ],
                  ),
                ),
                if (_isPasswordVisible)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0, left: 4.0),
                    child: Text(
                      'Auto-hiding in 10 seconds for privacy.',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // Notes Field
                if (widget.item.notes != null && widget.item.notes!.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Notes',
                    content: widget.item.notes!,
                    trailing: null,
                  ),
                  const SizedBox(height: 14),
                ],

                // Metadata
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Text(
                    'Last updated: ${widget.item.updatedAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required String title,
    required String content,
    required Widget? trailing,
    bool isMonospace = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: isMonospace ? 'monospace' : null,
                    letterSpacing: isMonospace ? 1.0 : 0.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
