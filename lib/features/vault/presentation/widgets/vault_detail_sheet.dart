import 'dart:async';
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
  String _plainUsername = '';
  String _plainPassword = '';

  // Payment Card fields
  bool _isCardNumberVisible = false;
  bool _isCvvVisible = false;
  bool _isCardPinVisible = false;
  CardDetails _cardDetails = const CardDetails();

  String? _decryptionError;
  Timer? _passwordHideTimer;
  Timer? _cvvHideTimer;

  @override
  void initState() {
    super.initState();
    _decryptAllFields();
  }

  @override
  void dispose() {
    _passwordHideTimer?.cancel();
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
        _plainUsername = encryptionService.decrypt(
          cipherTextBase64: widget.item.usernameEncrypted,
          ivBase64: widget.item.iv,
        );
        _plainPassword = encryptionService.decrypt(
          cipherTextBase64: widget.item.passwordEncrypted,
          ivBase64: widget.item.iv,
        );
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

  Future<void> _copyUsername() async {
    final textToCopy = _plainUsername.isNotEmpty
        ? _plainUsername
        : (widget.item.accountNumber ?? '');
    if (textToCopy.isEmpty) return;

    await ClipboardService.copyWithAutoClear(textToCopy);
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
              const Text('Identifier copied. Clipboard auto-clears in 30s.'),
            ],
          ),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyPassword() async {
    await ClipboardService.copyWithAutoClear(_plainPassword);
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
              const Text('Password copied. Clipboard auto-clears in 30s.'),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Sleek monochromatic dark virtual card
        borderRadius: BorderRadius.circular(18),
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
                  color: const Color(0xFF27272A),
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.contactless_rounded, color: Colors.white38, size: 22),
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
                  color: Colors.white,
                  fontSize: 17,
                  letterSpacing: 2.2,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCardNumberVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white60,
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
                        color: Colors.white38,
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
                        color: Colors.white,
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
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardDetails.expiryDate.isNotEmpty ? _cardDetails.expiryDate : 'MM/YY',
                    style: const TextStyle(
                      color: Colors.white,
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
                if (_plainUsername.isNotEmpty &&
                    _plainUsername != widget.item.accountNumber) ...[
                  _buildFieldCard(
                    title: 'Username / Email',
                    content: _plainUsername,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: _copyUsername,
                      tooltip: 'Copy Username',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Account / Phone Number Field
                if (widget.item.accountNumber != null &&
                    widget.item.accountNumber!.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Account / Phone Number',
                    content: widget.item.accountNumber!,
                    trailing: IconButton(
                      icon: Icon(Icons.copy_rounded, color: textMuted, size: 20),
                      onPressed: () {
                        ClipboardService.copyWithAutoClear(widget.item.accountNumber!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Account number copied (clears in 30s).'),
                            backgroundColor: surfaceColor,
                          ),
                        );
                      },
                      tooltip: 'Copy Account Number',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Password Field
                _buildFieldCard(
                  title: 'Password / PIN',
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
                        onPressed: _copyPassword,
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
