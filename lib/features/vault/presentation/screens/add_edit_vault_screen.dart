import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/card_brand_helper.dart';
import '../../../../core/utils/country_code_helper.dart';
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
  final String vaultType;

  const AddEditVaultScreen({
    super.key,
    this.existingItem,
    this.vaultType = VaultType.password,
  });

  @override
  ConsumerState<AddEditVaultScreen> createState() => _AddEditVaultScreenState();
}

class _AddEditVaultScreenState extends ConsumerState<AddEditVaultScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isCard =>
      (widget.existingItem?.isCard ?? false) || widget.vaultType == VaultType.card;

  // Login Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _customCategoryController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _accountNumberController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _pinController;
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

  CountryCode _selectedCountryCode = CountryCodeHelper.defaultCountryCode;
  String? _qrCodeBase64;
  bool _isPickingQr = false;
  bool _isPinVisible = false;
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final isExistingCard = _isCard;

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

    _emailController = TextEditingController(text: widget.existingItem?.email ?? '');
    _accountNumberController =
        TextEditingController(text: widget.existingItem?.accountNumber ?? '');

    final parsedPhone = CountryCodeHelper.parsePhoneNumber(widget.existingItem?.phoneNumber);
    _selectedCountryCode = parsedPhone.country;
    _phoneNumberController = TextEditingController(text: parsedPhone.localNumber);
    _qrCodeBase64 = widget.existingItem?.qrCodeBase64;

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
          _pinController = TextEditingController();
          _passwordController = TextEditingController();
        } else {
          final plainUser = widget.existingItem!.usernameEncrypted.isNotEmpty
              ? encryptionService.decrypt(
                  cipherTextBase64: widget.existingItem!.usernameEncrypted,
                  ivBase64: widget.existingItem!.iv,
                ).trim()
              : '';
          final plainPass = widget.existingItem!.passwordEncrypted.isNotEmpty
              ? encryptionService.decrypt(
                  cipherTextBase64: widget.existingItem!.passwordEncrypted,
                  ivBase64: widget.existingItem!.iv,
                )
              : '';
          final plainPin = (widget.existingItem!.pinEncrypted != null &&
                  widget.existingItem!.pinEncrypted!.isNotEmpty)
              ? encryptionService.decrypt(
                  cipherTextBase64: widget.existingItem!.pinEncrypted!,
                  ivBase64: widget.existingItem!.iv,
                )
              : '';

          final existingEmail = widget.existingItem?.email?.trim() ?? '';
          final existingAccount = widget.existingItem?.accountNumber?.trim() ?? '';
          final existingPhone = widget.existingItem?.phoneNumber?.trim() ?? '';

          if (widget.existingItem!.username != null) {
            _usernameController = TextEditingController(text: widget.existingItem!.username);
          } else {
            // For legacy items without separate fields:
            if (plainUser.isNotEmpty &&
                plainUser != existingEmail &&
                plainUser != existingAccount &&
                plainUser != existingPhone &&
                !plainUser.contains('@') &&
                !RegExp(r'^[0-9+\s\-()]+$').hasMatch(plainUser)) {
              _usernameController = TextEditingController(text: plainUser);
            } else {
              _usernameController = TextEditingController(text: '');
            }
          }

          _passwordController = TextEditingController(text: plainPass);
          _pinController = TextEditingController(text: plainPin);
        }
      } catch (_) {
        _usernameController = TextEditingController();
        _pinController = TextEditingController();
        _passwordController = TextEditingController();
      }
    } else {
      _usernameController = TextEditingController();
      _pinController = TextEditingController();
      _passwordController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customCategoryController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _accountNumberController.dispose();
    _phoneNumberController.dispose();
    _pinController.dispose();
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

  Future<void> _openCountryCodePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final selected = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Select Country Code',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: CountryCodeHelper.commonCountryCodes.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                    ),
                    itemBuilder: (context, index) {
                      final item = CountryCodeHelper.commonCountryCodes[index];
                      final isSelected = item.code == _selectedCountryCode.code;

                      return ListTile(
                        leading: Text(
                          item.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: Text(
                          item.code,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
                                : textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCountryCode = selected;
      });
    }
  }

  Future<void> _pickQrCodeImage() async {
    try {
      setState(() => _isPickingQr = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          _qrCodeBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick QR Code image: $e'),
            backgroundColor: AppTheme.darkDestructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingQr = false);
    }
  }

  void _removeQrCodeImage() {
    setState(() {
      _qrCodeBase64 = null;
    });
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

      if (_isCard) {
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
          qrCodeBase64: _qrCodeBase64,
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
        final emailTrimmed = _emailController.text.trim();
        final accountTrimmed = _accountNumberController.text.trim();
        final phoneDigits = _phoneNumberController.text.replaceAll(RegExp(r'\D'), '');
        final phoneFormatted = phoneDigits.isNotEmpty
            ? CountryCodeHelper.formatFullPhoneNumber(_selectedCountryCode, phoneDigits)
            : '';
        final pinTrimmed = _pinController.text.trim();
        final passTrimmed = _passwordController.text;

        final hasCredential = userTrimmed.isNotEmpty ||
            emailTrimmed.isNotEmpty ||
            accountTrimmed.isNotEmpty ||
            phoneFormatted.isNotEmpty ||
            pinTrimmed.isNotEmpty ||
            passTrimmed.isNotEmpty ||
            (_qrCodeBase64 != null && _qrCodeBase64!.isNotEmpty);

        if (!hasCredential) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Enter at least one credential field (Username, Email, Account Number, Phone Number, PIN, Password, or QR Code)',
              ),
              backgroundColor: AppTheme.darkDestructive,
            ),
          );
          return;
        }

        final primaryIdentifier = userTrimmed.isNotEmpty
            ? userTrimmed
            : (emailTrimmed.isNotEmpty
                ? emailTrimmed
                : (accountTrimmed.isNotEmpty
                    ? accountTrimmed
                    : (phoneFormatted.isNotEmpty
                        ? phoneFormatted
                        : (_qrCodeBase64 != null ? 'QR Code Entry' : 'Credential'))));

        final encUser = encryptionService.encrypt(
          primaryIdentifier,
          customIvBase64: itemIv,
        );
        final encPass = passTrimmed.isNotEmpty
            ? encryptionService.encrypt(
                passTrimmed,
                customIvBase64: itemIv,
              ).cipherTextBase64
            : '';
        final encPin = pinTrimmed.isNotEmpty
            ? encryptionService.encrypt(
                pinTrimmed,
                customIvBase64: itemIv,
              ).cipherTextBase64
            : null;

        final finalTitle = _isCustomService
            ? toTitleCase(_titleController.text.trim())
            : _selectedService;

        itemToSave = VaultItem(
          id: widget.existingItem?.id ?? const Uuid().v4(),
          title: finalTitle,
          type: 'login',
          username: userTrimmed.isNotEmpty ? userTrimmed : null,
          email: emailTrimmed.isNotEmpty ? emailTrimmed : null,
          accountNumber: accountTrimmed.isNotEmpty ? accountTrimmed : null,
          phoneNumber: phoneFormatted.isNotEmpty ? phoneFormatted : null,
          usernameEncrypted: encUser.cipherTextBase64,
          passwordEncrypted: encPass,
          pinEncrypted: encPin,
          qrCodeBase64: _qrCodeBase64,
          iv: itemIv,
          category: finalCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isSynced: false,
          updatedAt: DateTime.now(),
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

  Widget _buildFieldSubLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 2.0, left: 2.0),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    final isCard = _isCard;
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
              ? (isCard ? 'Edit Payment Card' : 'Edit Password')
              : (isCard ? 'New Payment Card' : 'New Password'),
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

                // 1. TITLE / PLATFORM SERVICE (Dropdown OR Swappable Custom Text Field)
                _buildSectionLabel('Title / Platform Service'),
                if (_isCustomService) ...[
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [TitleCaseTextInputFormatter()],
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      hintText: 'Enter custom service name (e.g. Work VPN)',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                        tooltip: 'Choose from preset platforms',
                        onPressed: () {
                          setState(() {
                            _isCustomService = false;
                            _selectedService = _presetServices.first;
                            _titleController.text = _selectedService;
                          });
                        },
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
                        (_isCustomService && (val == null || val.trim().isEmpty))
                            ? 'Custom service name is required'
                            : null,
                  ),
                ] else ...[
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
                ],
                const SizedBox(height: 18),

                // 2. CATEGORY (Placed immediately below Title)
                _buildSectionLabel('Category'),
                if (_isCustomCategory) ...[
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
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                        tooltip: 'Choose from preset categories',
                        onPressed: () {
                          setState(() {
                            _isCustomCategory = false;
                            _selectedCategoryOption = _presetCategories.first;
                            _customCategoryController.clear();
                          });
                        },
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
                        (_isCustomCategory && (val == null || val.trim().isEmpty))
                            ? 'Custom category is required'
                            : null,
                  ),
                ] else ...[
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
                ],
                const SizedBox(height: 18),

                // 3. CREDENTIAL DETAILS (Individual Optional Fields)
                _buildSectionLabel('CREDENTIAL DETAILS'),

                // Username Field
                _buildFieldSubLabel('Username (Optional)'),
                TextFormField(
                  controller: _usernameController,
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
                ),
                const SizedBox(height: 14),

                // Email Field
                _buildFieldSubLabel('Email (Optional)'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'user@company.com',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: textMuted),
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
                const SizedBox(height: 14),

                // Account Number Field
                _buildFieldSubLabel('Account Number (Optional)'),
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'e.g. 09171234567, 1234-5678-90',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.badge_outlined, color: textMuted),
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
                const SizedBox(height: 14),

                // Phone Number Field
                _buildFieldSubLabel('Phone Number (Optional)'),
                TextFormField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: '917 123 4567',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: InkWell(
                      onTap: _openCountryCodePicker,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountryCode.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountryCode.code,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down_rounded, color: textMuted, size: 20),
                            const SizedBox(width: 6),
                            Container(
                              width: 1,
                              height: 20,
                              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),
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
                const SizedBox(height: 14),

                // PIN Field
                _buildFieldSubLabel('PIN (Optional)'),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: !_isPinVisible,
                  maxLength: 6,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  style: TextStyle(color: textPrimary, letterSpacing: 2.0, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: '4-6 digit PIN',
                    hintStyle: TextStyle(color: textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.pin_rounded, color: textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPinVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
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
                const SizedBox(height: 14),

                // Password Field with Generator Button
                _buildFieldSubLabel('Password (Optional)'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: '••••••••••••',
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
                ),
                const SizedBox(height: 18),

                // 4. E-WALLET / BANK QR CODE SECTION
                _buildSectionLabel('E-WALLET / BANK QR CODE (OPTIONAL)'),
                if (_qrCodeBase64 != null && _qrCodeBase64!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            child: Image.memory(
                              base64Decode(_qrCodeBase64!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image_rounded,
                                color: textMuted,
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
                                'QR Code Attached',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ready for secure display & scan',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.darkDestructive),
                          onPressed: _removeQrCodeImage,
                          tooltip: 'Remove QR Code',
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: _isPickingQr ? null : _pickQrCodeImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color: textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isPickingQr ? 'Selecting Image...' : 'Upload QR Code Image',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // 5. SECURE NOTES (Moved to very bottom)
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

