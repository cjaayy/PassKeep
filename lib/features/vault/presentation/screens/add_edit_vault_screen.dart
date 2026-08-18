import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/card_brand_helper.dart';
import '../../../../core/utils/service_brand_helper.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../data/models/card_details.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_providers.dart';
import '../widgets/password_generator_sheet.dart';

/// Formatter that automatically capitalizes the first letter of each word
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      if (char == ' ' || char == '/' || char == '-' || char == '_') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    final newString = buffer.toString();
    return TextEditingValue(
      text: newString,
      selection: newValue.selection,
    );
  }
}

/// Formatter for credit/debit card numbers: groups digits in 4s (XXXX XXXX XXXX XXXX)
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digitsOnly.length > 19 ? digitsOnly.substring(0, 19) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(truncated[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter for card expiry date: MM/YY
class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(truncated[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Helper function to ensure string is sanitized to Title Case
String toTitleCase(String input) {
  if (input.trim().isEmpty) return input.trim();
  final words = input.trim().split(RegExp(r'\s+'));
  return words.map((word) {
    if (word.isEmpty) return word;
    if (word.length == 1) return word.toUpperCase();
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Screen for creating a new vault entry or editing an existing one
class AddEditVaultScreen extends ConsumerStatefulWidget {
  final VaultItem? existingItem;
  final String? initialItemType;

  const AddEditVaultScreen({
    super.key,
    this.existingItem,
    this.initialItemType,
  });

  @override
  ConsumerState<AddEditVaultScreen> createState() => _AddEditVaultScreenState();
}

class _AddEditVaultScreenState extends ConsumerState<AddEditVaultScreen> {
  final _formKey = GlobalKey<FormState>();

  // Item Type: 'login' | 'card'
  late String _selectedItemType;

  // Login Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _customCategoryController;
  late TextEditingController _usernameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;

  // Payment Card Form Controllers
  late TextEditingController _cardTitleController;
  late TextEditingController _cardholderController;
  late TextEditingController _cardNumberController;
  late TextEditingController _cardExpiryController;
  late TextEditingController _cardCvvController;
  late TextEditingController _cardPinController;
  bool _isCvvVisible = false;
  bool _isCardPinVisible = false;

  static const List<String> _presetServices = [
    'Google / Gmail',
    'Facebook',
    'Microsoft / Outlook',
    'GitHub',
    'Netflix',
    'Spotify',
    'Steam',
    'Twitter / X',
    'Discord',
    'Custom...',
  ];

  static const List<String> _presetCategories = [
    'General',
    'Personal',
    'Work',
    'School',
    'Social',
    'Finance',
    'Entertainment',
    'Shopping',
    'Developer / Tech',
    'Utilities',
    'Custom...',
  ];

  late String _selectedService;
  bool _isCustomService = false;

  late String _selectedCategoryOption;
  bool _isCustomCategory = false;

  bool _isPasswordVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final isExistingCard =
        (widget.existingItem?.isCard ?? false) || widget.initialItemType == 'card';
    _selectedItemType = isExistingCard ? 'card' : 'login';

    // Initialize Service selection
    final existingTitle = widget.existingItem?.title.trim() ?? '';
    if (existingTitle.isNotEmpty && _presetServices.contains(existingTitle)) {
      _selectedService = existingTitle;
      _isCustomService = false;
      _titleController = TextEditingController(text: existingTitle);
    } else if (existingTitle.isNotEmpty) {
      _selectedService = 'Custom...';
      _isCustomService = true;
      _titleController = TextEditingController(text: existingTitle);
    } else {
      _selectedService = 'Google / Gmail';
      _isCustomService = false;
      _titleController = TextEditingController(text: 'Google / Gmail');
    }

    // Initialize Category selection
    final existingCategory = widget.existingItem?.category.trim() ?? '';
    if (existingCategory.isNotEmpty && _presetCategories.contains(existingCategory)) {
      _selectedCategoryOption = existingCategory;
      _isCustomCategory = false;
      _customCategoryController = TextEditingController();
    } else if (existingCategory.isNotEmpty) {
      _selectedCategoryOption = 'Custom...';
      _isCustomCategory = true;
      _customCategoryController = TextEditingController(text: existingCategory);
    } else {
      _selectedCategoryOption = 'General';
      _isCustomCategory = false;
      _customCategoryController = TextEditingController();
    }

    _notesController =
        TextEditingController(text: widget.existingItem?.notes ?? '');

    _cardTitleController = TextEditingController(
      text: isExistingCard ? widget.existingItem?.title ?? '' : '',
    );
    _cardholderController = TextEditingController();
    _cardNumberController = TextEditingController();
    _cardExpiryController = TextEditingController();
    _cardCvvController = TextEditingController();
    _cardPinController = TextEditingController();

    // Decrypt fields if editing
    if (widget.existingItem != null) {
      final encryptionService = ref.read(encryptionServiceProvider);
      try {
        if (widget.existingItem!.isCard &&
            widget.existingItem!.cardDetailsEnc != null &&
            widget.existingItem!.cardDetailsEnc!.isNotEmpty) {
          final decryptedCardJson = encryptionService.decrypt(
            cipherTextBase64: widget.existingItem!.cardDetailsEnc!,
            ivBase64: widget.existingItem!.iv,
          );
          final card = CardDetails.fromJson(decryptedCardJson);
          _cardholderController = TextEditingController(text: card.cardholderName);
          _cardNumberController = TextEditingController(text: card.cardNumber);
          _cardExpiryController = TextEditingController(text: card.expiryDate);
          _cardCvvController = TextEditingController(text: card.cvv);
          _cardPinController = TextEditingController(text: card.cardPin);
          _usernameController = TextEditingController();
          _accountNumberController = TextEditingController();
          _passwordController = TextEditingController();
        } else {
          final plainUser = encryptionService.decrypt(
            cipherTextBase64: widget.existingItem!.usernameEncrypted,
            ivBase64: widget.existingItem!.iv,
          ).trim();
          final plainPass = encryptionService.decrypt(
            cipherTextBase64: widget.existingItem!.passwordEncrypted,
            ivBase64: widget.existingItem!.iv,
          );

          final existingAccount = widget.existingItem?.accountNumber?.trim() ?? '';

          if (existingAccount.isNotEmpty) {
            if (plainUser == existingAccount) {
              // Saved with phone/account number only
              _usernameController = TextEditingController(text: '');
              _accountNumberController = TextEditingController(text: existingAccount);
            } else {
              // Saved with both username and account number
              _usernameController = TextEditingController(text: plainUser);
              _accountNumberController = TextEditingController(text: existingAccount);
            }
          } else {
            // If no separate accountNumber was recorded, check if plainUser is a phone/numeric account
            final isPhoneOrAccountNumber =
                RegExp(r'^[0-9+\s\-()]+$').hasMatch(plainUser) && !plainUser.contains('@');
            if (isPhoneOrAccountNumber) {
              _usernameController = TextEditingController(text: '');
              _accountNumberController = TextEditingController(text: plainUser);
            } else {
              _usernameController = TextEditingController(text: plainUser);
              _accountNumberController = TextEditingController(text: '');
            }
          }

          _passwordController = TextEditingController(text: plainPass);
        }
      } catch (_) {
        _usernameController = TextEditingController();
        _accountNumberController =
            TextEditingController(text: widget.existingItem?.accountNumber ?? '');
        _passwordController = TextEditingController();
      }
    } else {
      _usernameController = TextEditingController();
      _accountNumberController = TextEditingController();
      _passwordController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customCategoryController.dispose();
    _usernameController.dispose();
    _accountNumberController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    _cardTitleController.dispose();
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardPinController.dispose();
    super.dispose();
  }

  Future<void> _openPasswordGenerator() async {
    final generated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PasswordGeneratorSheet(),
    );

    if (generated != null && generated.isNotEmpty) {
      setState(() {
        _passwordController.text = generated;
        _isPasswordVisible = true;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final itemIv = encryptionService.generateRandomIv();

      VaultItem itemToSave;

      if (_selectedItemType == 'card') {
        // Build and encrypt Payment Card details
        final card = CardDetails(
          cardholderName: _cardholderController.text.trim(),
          cardNumber: _cardNumberController.text.trim(),
          expiryDate: _cardExpiryController.text.trim(),
          cvv: _cardCvvController.text.trim(),
          cardPin: _cardPinController.text.trim(),
        );

        final encCardDetails = encryptionService.encrypt(
          card.toJson(),
          customIvBase64: itemIv,
        );

        final encCardholder = encryptionService.encrypt(
          card.cardholderName,
          customIvBase64: itemIv,
        );

        final encCardNumber = encryptionService.encrypt(
          card.cardNumber,
          customIvBase64: itemIv,
        );

        itemToSave = VaultItem(
          id: widget.existingItem?.id ?? const Uuid().v4(),
          title: toTitleCase(_cardTitleController.text.trim()),
          type: 'card',
          usernameEncrypted: encCardholder.cipherTextBase64,
          passwordEncrypted: encCardNumber.cipherTextBase64,
          cardDetailsEnc: encCardDetails.cipherTextBase64,
          iv: itemIv,
          category: 'Cards', // Cards do not use categories
          notes: null,
          isSynced: false,
          updatedAt: DateTime.now(),
          accountNumber: card.maskedCardNumber,
        );
      } else {
        // Build and encrypt standard Login details
        final finalCategory = _isCustomCategory
            ? toTitleCase(_customCategoryController.text.trim())
            : _selectedCategoryOption;

        final userTrimmed = _usernameController.text.trim();
        final accountTrimmed = _accountNumberController.text.trim();
        final primaryIdentifier = userTrimmed.isNotEmpty ? userTrimmed : accountTrimmed;

        final encUser = encryptionService.encrypt(
          primaryIdentifier,
          customIvBase64: itemIv,
        );
        final encPass = encryptionService.encrypt(
          _passwordController.text,
          customIvBase64: itemIv,
        );

        final finalTitle = _isCustomService
            ? toTitleCase(_titleController.text.trim())
            : _selectedService;

        itemToSave = VaultItem(
          id: widget.existingItem?.id ?? const Uuid().v4(),
          title: finalTitle,
          type: 'login',
          usernameEncrypted: encUser.cipherTextBase64,
          passwordEncrypted: encPass.cipherTextBase64,
          iv: itemIv,
          category: finalCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isSynced: false,
          updatedAt: DateTime.now(),
          accountNumber: accountTrimmed.isNotEmpty ? accountTrimmed : null,
        );
      }

      await ref.read(vaultNotifierProvider.notifier).saveItem(itemToSave);

      // Auto-sync item to cloud if enabled and online
      final authState = ref.read(authNotifierProvider);
      final userState = ref.read(supabaseUserProvider);
      final autoSyncEnabled = ref.read(settingsNotifierProvider).autoSyncEnabled;

      if (autoSyncEnabled && !authState.isOfflineOnlyMode && userState.isAuthenticated) {
        ref.read(syncNotifierProvider.notifier).sync();
      }

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingItem != null ? 'Item updated securely.' : 'Item added to vault.',
            ),
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save item: $e'),
            backgroundColor: AppTheme.darkDestructive,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    final isCard = _selectedItemType == 'card';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final primaryAction = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimaryAction = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isEditing
              ? (isCard ? 'Edit Payment Card' : 'Edit Vault Item')
              : (isCard ? 'New Payment Card' : 'New Vault Item'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textPrimary,
                    ),
                  )
                : Icon(Icons.check_rounded, color: textPrimary, size: 28),
            tooltip: 'Save Item',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Type Segmented Toggle (Borderless, Monochromatic)
              _buildSectionLabel('Item Type'),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedItemType != 'login') {
                            setState(() {
                              _selectedItemType = 'login';
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isCard ? primaryAction : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.vpn_key_rounded,
                                size: 16,
                                color: !isCard ? onPrimaryAction : textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PASSWORD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: !isCard ? onPrimaryAction : textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedItemType != 'card') {
                            setState(() {
                              _selectedItemType = 'card';
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCard ? primaryAction : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.credit_card_rounded,
                                size: 16,
                                color: isCard ? onPrimaryAction : textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PAYMENT CARD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: isCard ? onPrimaryAction : textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ====================================================
              // PAYMENT CARD FORM (Zero-Knowledge, No Category/Notes)
              // ====================================================
              if (isCard) ...[
                // Card Title / Bank Name
                _buildSectionLabel('Card Title / Bank Name'),
                TextFormField(
                  controller: _cardTitleController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [TitleCaseTextInputFormatter()],
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'e.g. BPI Gold Visa, GCash Card, Maya Card',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.account_balance_rounded, color: textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Card Title / Bank name is required' : null,
                ),
                const SizedBox(height: 18),

                // Cardholder Name
                _buildSectionLabel('Cardholder Name'),
                TextFormField(
                  controller: _cardholderController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: textPrimary, letterSpacing: 1.0),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'e.g. JUAN DELA CRUZ',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Cardholder name is required' : null,
                ),
                const SizedBox(height: 18),

                // Card Number with Brand Detection
                _buildSectionLabel('Card Number'),
                TextFormField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CardNumberInputFormatter()],
                  style: TextStyle(color: textPrimary, letterSpacing: 1.5, fontFamily: 'monospace'),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'XXXX XXXX XXXX XXXX',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.credit_card_rounded, color: textMuted),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                      child: CardBrandHelper.detectBrand(_cardNumberController.text).buildBadge(height: 22, showBorder: false),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                    if (clean.length < 13 || clean.length > 19) {
                      return 'Enter a valid card number (13-19 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Expiry Date & CVV Row
                Row(
                  children: [
                    // Expiry Date (MM/YY)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Expiry Date (MM/YY)'),
                          TextFormField(
                            controller: _cardExpiryController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CardExpiryInputFormatter()],
                            style: TextStyle(color: textPrimary, letterSpacing: 1.0, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              hintText: 'MM/YY',
                              hintStyle: TextStyle(color: textMuted, fontSize: 14),
                              prefixIcon: Icon(Icons.calendar_today_rounded, color: textMuted, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.length != 5 || !val.contains('/')) {
                                return 'Enter MM/YY';
                              }
                              final parts = val.split('/');
                              final month = int.tryParse(parts[0]) ?? 0;
                              if (month < 1 || month > 12) {
                                return 'Month 01-12';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // CVV / CVC
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('CVV / CVC'),
                          TextFormField(
                            controller: _cardCvvController,
                            keyboardType: TextInputType.number,
                            obscureText: !_isCvvVisible,
                            maxLength: 4,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            style: TextStyle(color: textPrimary, letterSpacing: 2.0, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              hintText: '123',
                              hintStyle: TextStyle(color: textMuted, fontSize: 14),
                              prefixIcon: Icon(Icons.security_rounded, color: textMuted, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isCvvVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: textMuted,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _isCvvVisible = !_isCvvVisible),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (val) {
                              final clean = (val ?? '').trim();
                              if (clean.length < 3 || clean.length > 4) {
                                return '3-4 digits';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Optional Card / ATM PIN
                _buildSectionLabel('Card PIN (Optional)'),
                TextFormField(
                  controller: _cardPinController,
                  keyboardType: TextInputType.number,
                  obscureText: !_isCardPinVisible,
                  maxLength: 6,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  style: TextStyle(color: textPrimary, letterSpacing: 2.0, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'ATM / Online PIN',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.pin_rounded, color: textMuted, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isCardPinVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _isCardPinVisible = !_isCardPinVisible),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ] else ...[
                // ====================================================
                // LOGIN / PASSWORD FORM
                // ====================================================
                _buildSectionLabel('Title / Platform Service'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedService,
                  dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: Icon(
                      ServiceBrandHelper.getIconForService(_selectedService),
                      color: textMuted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _presetServices.map((service) {
                    return DropdownMenuItem(
                      value: service,
                      child: Row(
                        children: [
                          Icon(
                            ServiceBrandHelper.getIconForService(service),
                            color: textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(service),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedService = val;
                        _isCustomService = (val == 'Custom...');
                        if (!_isCustomService) {
                          _titleController.text = val;
                        } else {
                          _titleController.clear();
                        }
                      });
                    }
                  },
                ),

                if (_isCustomService) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [TitleCaseTextInputFormatter()],
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      hintText: 'Enter custom service name (e.g. Work Vpn)',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) =>
                        (_isCustomService && (val == null || val.trim().isEmpty))
                            ? 'Custom service name is required'
                            : null,
                  ),
                ],
                const SizedBox(height: 18),

                // Username / Email Field
                _buildSectionLabel('Username / Email (Optional if Phone/Account No. is provided)'),
                TextFormField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'name@example.com',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    final userVal = val?.trim() ?? '';
                    final accountVal = _accountNumberController.text.trim();
                    if (userVal.isEmpty && accountVal.isEmpty) {
                      return 'Enter either Username/Email or Account/Phone Number';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_accountNumberController.text.trim().isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Account / Phone Number Field
                _buildSectionLabel('Account / Phone Number (Optional if Username/Email is provided)'),
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'e.g. 09171234567, 1234-5678-90',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.pin_outlined, color: textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    final accountVal = val?.trim() ?? '';
                    final userVal = _usernameController.text.trim();
                    if (accountVal.isEmpty && userVal.isEmpty) {
                      return 'Enter either Username/Email or Account/Phone Number';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_usernameController.text.trim().isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Password / PIN Field
                _buildSectionLabel('Password / PIN'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'Enter or generate password / PIN',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: textMuted),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            color: textMuted,
                          ),
                          onPressed: () =>
                              setState(() => _isPasswordVisible = !_isPasswordVisible),
                          tooltip: 'Toggle Visibility',
                        ),
                        IconButton(
                          icon: Icon(Icons.auto_awesome_rounded, color: primaryAction),
                          onPressed: _openPasswordGenerator,
                          tooltip: 'Generate Strong Password',
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.isEmpty) ? 'Password or PIN is required' : null,
                ),
                const SizedBox(height: 18),

                // Category Selector (Only for Passwords)
                _buildSectionLabel('Category'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryOption,
                  dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: Icon(Icons.folder_outlined, color: textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _presetCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryOption = val;
                        _isCustomCategory = (val == 'Custom...');
                        if (!_isCustomCategory) {
                          _customCategoryController.clear();
                        }
                      });
                    }
                  },
                ),

                if (_isCustomCategory) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customCategoryController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [TitleCaseTextInputFormatter()],
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      hintText: 'Enter custom category (e.g. Banking, Crypto)',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.create_new_folder_outlined, color: textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) =>
                        (_isCustomCategory && (val == null || val.trim().isEmpty))
                            ? 'Custom category is required'
                            : null,
                  ),
                ],
                const SizedBox(height: 18),

                // Notes Field (Only for Passwords)
                _buildSectionLabel('Secure Notes (Optional)'),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: '2FA Backup codes, PINs, or security answers...',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Save Button (High contrast solid minimalist style)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAction,
                    foregroundColor: onPrimaryAction,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: Text(
                    isEditing
                        ? (isCard ? 'UPDATE PAYMENT CARD' : 'UPDATE PASSWORD')
                        : (isCard ? 'SAVE PAYMENT CARD' : 'SAVE PASSWORD'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

