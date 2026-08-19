import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/card_brand_helper.dart';
import '../../../../core/utils/clipboard_service.dart';
import '../../../../core/utils/domain_utils.dart';
import '../../../../core/utils/service_brand_helper.dart';
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
  bool _isPinVisible = false;
  String _plainUsername = '';
  String _plainEmail = '';
  String _plainAccountNumber = '';
  String _plainPhoneNumber = '';
  String _plainPin = '';
  String _plainPassword = '';

  // Payment Card fields
  bool _isCardNumberVisible = false;
  bool _isCvvVisible = false;
  bool _isCardPinVisible = false;
  CardDetails _cardDetails = const CardDetails();

  String? _decryptionError;
  Timer? _passwordHideTimer;
  Timer? _pinHideTimer;
  Timer? _cvvHideTimer;

  @override
  void initState() {
    super.initState();
    _decryptAllFields();
  }

  @override
  void dispose() {
    _passwordHideTimer?.cancel();
    _pinHideTimer?.cancel();
    _cvvHideTimer?.cancel();
    super.dispose();
  }

  void _decryptAllFields() {
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
          final number = encryptionService.decrypt(
            cipherTextBase64: widget.item.passwordEncrypted,
            ivBase64: widget.item.iv,
          );
          final holder = encryptionService.decrypt(
            cipherTextBase64: widget.item.usernameEncrypted,
            ivBase64: widget.item.iv,
          );
          _cardDetails = CardDetails(
            cardholderName: holder,
            cardNumber: number,
          );
        }
      } else {
        final plainEncryptedUser = widget.item.usernameEncrypted.isNotEmpty
            ? encryptionService.decrypt(
                cipherTextBase64: widget.item.usernameEncrypted,
                ivBase64: widget.item.iv,
              ).trim()
            : '';

        _plainEmail = widget.item.email?.trim() ?? '';
        _plainAccountNumber = widget.item.accountNumber?.trim() ?? '';
        _plainPhoneNumber = widget.item.phoneNumber?.trim() ?? '';

        if (widget.item.username != null && widget.item.username!.isNotEmpty) {
          _plainUsername = widget.item.username!.trim();
        } else {
          // If no separate username field was populated, evaluate plainEncryptedUser:
          if (plainEncryptedUser.isNotEmpty &&
              plainEncryptedUser != _plainAccountNumber &&
              plainEncryptedUser != _plainPhoneNumber &&
              plainEncryptedUser != _plainEmail) {
            _plainUsername = plainEncryptedUser;
          } else {
            _plainUsername = '';
          }
        }

        if (widget.item.pinEncrypted != null && widget.item.pinEncrypted!.isNotEmpty) {
          _plainPin = encryptionService.decrypt(
            cipherTextBase64: widget.item.pinEncrypted!,
            ivBase64: widget.item.iv,
          );
        } else {
          _plainPin = '';
        }

        if (widget.item.passwordEncrypted.isNotEmpty) {
          _plainPassword = encryptionService.decrypt(
            cipherTextBase64: widget.item.passwordEncrypted,
            ivBase64: widget.item.iv,
          );
        } else {
          _plainPassword = '';
        }
      }
      _decryptionError = null;
    } catch (e) {
      _decryptionError = 'Decryption failed: Master PIN mismatch or corrupted data.';
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
      if (_isPasswordVisible) {
        _passwordHideTimer?.cancel();
        _passwordHideTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _isPasswordVisible = false);
        });
      }
    });
  }

  void _togglePinVisibility() {
    setState(() {
      _isPinVisible = !_isPinVisible;
      if (_isPinVisible) {
        _pinHideTimer?.cancel();
        _pinHideTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _isPinVisible = false);
        });
      }
    });
  }

  void _toggleCvvVisibility() {
    setState(() {
      _isCvvVisible = !_isCvvVisible;
      if (_isCvvVisible) {
        _cvvHideTimer?.cancel();
        _cvvHideTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _isCvvVisible = false);
        });
      }
    });
  }

  Future<void> _copyField(String label, String value) async {
    if (value.isEmpty) return;

    await ClipboardService.copyWithAutoClear(value);
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('$label copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyCardNumber() async {
    final clean = _cardDetails.cardNumber.replaceAll(RegExp(r'\s+'), '');
    await ClipboardService.copyWithAutoClear(clean);
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Card number copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyCvv() async {
    await ClipboardService.copyWithAutoClear(_cardDetails.cvv);
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('CVV copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openFullScreenQrDialog(String qrCodeBase64) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(qrCodeBase64),
                    fit: BoxFit.contain,
                    width: 240,
                    height: 240,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Invalid QR Code image', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan with GCash, Maya, or any banking app',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodePreview(String qrCodeBase64) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return InkWell(
      onTap: () => _openFullScreenQrDialog(qrCodeBase64),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  base64Decode(qrCodeBase64),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-Wallet / Bank QR Code',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to enlarge & scan',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.fullscreen_rounded,
              color: textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: Text(
          'Delete Vault Item',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.item.title}"? This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await ref.read(vaultNotifierProvider.notifier).deleteItem(widget.item.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item deleted.'),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF27272A), Color(0xFF18181B)]
              : const [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFF334155),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Bank Favicon + Bank Name + Contactless Indicator
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  DomainUtils.resolveFaviconUrl(widget.item.title),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: child,
                      );
                    }
                    return const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 18,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFAFAFA),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.contactless_rounded, color: Color(0xFFA1A1AA), size: 22),
            ],
          ),
          const SizedBox(height: 18),

          // EMV Chip
          Container(
            width: 36,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D4D8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Card Number + Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayCardNumber,
                style: const TextStyle(
                  color: Color(0xFFFAFAFA),
                  fontSize: 17,
                  letterSpacing: 2.2,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCardNumberVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFFA1A1AA),
                  size: 18,
                ),
                onPressed: () => setState(() => _isCardNumberVisible = !_isCardNumberVisible),
                tooltip: 'Toggle Number',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom Row: Cardholder Name + Expiry + Brand Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cardholder
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARDHOLDER',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _cardDetails.cardholderName.isNotEmpty
                          ? _cardDetails.cardholderName.toUpperCase()
                          : 'VALUED CARDHOLDER',
                      style: const TextStyle(
                        color: Color(0xFFFAFAFA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Expiry
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardDetails.expiryDate.isNotEmpty ? _cardDetails.expiryDate : 'MM/YY',
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Network Logo Badge
              brand.buildBadge(height: 22, showBorder: false),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCard = widget.item.isCard;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header: Avatar + Title + Category + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isCard
                        ? Icon(
                            CardBrandHelper.detectBrand(widget.item.accountNumber ?? widget.item.title).icon,
                            color: textPrimary,
                            size: 22,
                          )
                        : Image.network(
                            DomainUtils.resolveFaviconUrl(widget.item.title),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              ServiceBrandHelper.getIconForService(
                                widget.item.title,
                                category: widget.item.category,
                              ),
                              color: textMuted,
                              size: 22,
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return Padding(
                                  padding: const EdgeInsets.all(7.0),
                                  child: child,
                                );
                              }
                              return Icon(
                                ServiceBrandHelper.getIconForService(
                                  widget.item.title,
                                  category: widget.item.category,
                                ),
                                color: textMuted,
                                size: 22,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCard ? 'PAYMENT CARD' : widget.item.category.toUpperCase(),
                            style: TextStyle(
                              color: textMuted,
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
                    icon: Icon(Icons.edit_outlined, color: textMuted),
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
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.darkDestructive),
                    tooltip: 'Delete Item',
                    onPressed: _confirmDelete,
                  ),
                ],
              ),
              Divider(color: dividerColor, height: 32),

              if (_decryptionError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkDestructive.withValues(alpha: 0.15)
                        : AppTheme.lightDestructive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.darkDestructive, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Decryption Failed',
                            style: TextStyle(
                              color: AppTheme.darkDestructive,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _decryptionError!,
                        style: const TextStyle(color: AppTheme.darkDestructive, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This entry may have been encrypted with a different Master PIN or is corrupted. You can safely delete it below.',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                            foregroundColor: AppTheme.darkDestructive,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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

                // Cardholder Name Row
                if (_cardDetails.cardholderName.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Cardholder Name',
                    content: _cardDetails.cardholderName,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () {
                        ClipboardService.copyWithAutoClear(_cardDetails.cardholderName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Cardholder name copied.'),
                            backgroundColor: surfaceColor,
                          ),
                        );
                      },
                      tooltip: 'Copy Name',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Card Number Row
                _buildFieldCard(
                  title: 'Card Number',
                  content: _isCardNumberVisible
                      ? _cardDetails.cardNumber
                      : _cardDetails.maskedCardNumber,
                  isMonospace: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isCardNumberVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _isCardNumberVisible = !_isCardNumberVisible),
                        tooltip: 'Toggle Number',
                      ),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                        onPressed: _copyCardNumber,
                        tooltip: 'Copy Number',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Expiry & CVV Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldCard(
                        title: 'Expires',
                        content: _cardDetails.expiryDate.isNotEmpty
                            ? _cardDetails.expiryDate
                            : 'MM/YY',
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
                                _isCvvVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: textMuted,
                                size: 18,
                              ),
                              onPressed: _toggleCvvVisibility,
                              tooltip: 'Toggle CVV',
                            ),
                            IconButton(
                              icon: Icon(Icons.copy_rounded, color: textMuted, size: 18),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                    child: Text(
                      'CVV auto-hiding in 10 seconds for security.',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // Card PIN Field (Optional)
                if (_cardDetails.cardPin.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Card PIN',
                    content: _isCardPinVisible ? _cardDetails.cardPin : '••••',
                    isMonospace: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isCardPinVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _isCardPinVisible = !_isCardPinVisible),
                          tooltip: 'Toggle Card PIN',
                        ),
                        IconButton(
                          icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                          onPressed: () {
                            ClipboardService.copyWithAutoClear(_cardDetails.cardPin);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Card PIN copied (clears in 30s).'),
                                backgroundColor: surfaceColor,
                              ),
                            );
                          },
                          tooltip: 'Copy Card PIN',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // QR Code Field (Payment Card)
                if (widget.item.qrCodeBase64 != null && widget.item.qrCodeBase64!.isNotEmpty) ...[
                  _buildQrCodePreview(widget.item.qrCodeBase64!),
                  const SizedBox(height: 14),
                ],

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
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
              ] else ...[
                // LOGIN / PASSWORD VIEW
                // Username Field
                if (_plainUsername.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Username',
                    content: _plainUsername,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () => _copyField('Username', _plainUsername),
                      tooltip: 'Copy Username',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Email Field
                if (_plainEmail.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Email',
                    content: _plainEmail,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () => _copyField('Email', _plainEmail),
                      tooltip: 'Copy Email',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Account Number Field
                if (_plainAccountNumber.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Account Number',
                    content: _plainAccountNumber,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () => _copyField('Account Number', _plainAccountNumber),
                      tooltip: 'Copy Account Number',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Phone Number Field
                if (_plainPhoneNumber.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Phone Number',
                    content: _plainPhoneNumber,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () => _copyField('Phone Number', _plainPhoneNumber),
                      tooltip: 'Copy Phone Number',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // PIN Field
                if (_plainPin.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'PIN',
                    content: _isPinVisible ? _plainPin : '••••••',
                    isMonospace: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPinVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: textMuted,
                            size: 20,
                          ),
                          onPressed: _togglePinVisibility,
                          tooltip: 'Toggle PIN',
                        ),
                        IconButton(
                          icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                          onPressed: () => _copyField('PIN', _plainPin),
                          tooltip: 'Copy PIN',
                        ),
                      ],
                    ),
                  ),
                  if (_isPinVisible)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                      child: Text(
                        'PIN auto-hiding in 15 seconds for security.',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // Password Field
                if (_plainPassword.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Password',
                    content: _isPasswordVisible ? _plainPassword : '••••••••••••',
                    isMonospace: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: textMuted,
                            size: 20,
                          ),
                          onPressed: _togglePasswordVisibility,
                          tooltip: 'Toggle Password',
                        ),
                        IconButton(
                          icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                          onPressed: () => _copyField('Password', _plainPassword),
                          tooltip: 'Copy Password',
                        ),
                      ],
                    ),
                  ),
                  if (_isPasswordVisible)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                      child: Text(
                        'Password auto-hiding in 15 seconds for security.',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 14),

                // QR Code Field (Login / E-Wallet)
                if (widget.item.qrCodeBase64 != null && widget.item.qrCodeBase64!.isNotEmpty) ...[
                  _buildQrCodePreview(widget.item.qrCodeBase64!),
                  const SizedBox(height: 14),
                ],

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
                    style: TextStyle(color: textMuted, fontSize: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    color: textPrimary,
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
