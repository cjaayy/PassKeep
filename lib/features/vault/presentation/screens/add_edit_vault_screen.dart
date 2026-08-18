import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/service_brand_helper.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/supabase_auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
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

  const AddEditVaultScreen({super.key, this.existingItem});

  @override
  ConsumerState<AddEditVaultScreen> createState() => _AddEditVaultScreenState();
}

class _AddEditVaultScreenState extends ConsumerState<AddEditVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _customCategoryController;
  late TextEditingController _usernameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;

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

    // Decrypt fields if editing
    if (widget.existingItem != null) {
      final encryptionService = ref.read(encryptionServiceProvider);
      try {
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
    final userTrimmed = _usernameController.text.trim();
    final accountTrimmed = _accountNumberController.text.trim();

    if (!_formKey.currentState!.validate()) {
      if (userTrimmed.isEmpty && accountTrimmed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter either a Username/Email or an Account/Phone Number.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    if (userTrimmed.isEmpty && accountTrimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter either a Username/Email or an Account/Phone Number.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final itemIv = encryptionService.generateRandomIv();

      // Ensure whichever identifier is present gets encrypted into usernameEncrypted
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

      final finalCategory = _isCustomCategory
          ? toTitleCase(_customCategoryController.text.trim())
          : _selectedCategoryOption;

      final itemToSave = VaultItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        title: finalTitle,
        usernameEncrypted: encUser.cipherTextBase64,
        passwordEncrypted: encPass.cipherTextBase64,
        iv: itemIv,
        category: finalCategory,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isSynced: false, // Mark unsynced so bidirectional sync engine pushes it
        updatedAt: DateTime.now(),
        accountNumber: accountTrimmed.isNotEmpty ? accountTrimmed : null,
      );

      await ref.read(vaultNotifierProvider.notifier).saveItem(itemToSave);

      // Auto-sync item to cloud if enabled and online
      final authState = ref.read(authNotifierProvider);
      final userState = ref.read(supabaseUserProvider);
      final autoSyncEnabled = ref.read(settingsNotifierProvider).autoSyncEnabled;

      if (autoSyncEnabled && !authState.isOfflineOnlyMode && userState.isAuthenticated) {
        // Fire non-blocking asynchronous cloud sync
        ref.read(syncNotifierProvider.notifier).sync();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingItem != null ? 'Item updated securely.' : 'Item added to vault.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to encrypt item: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF94A3B8),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Vault Item' : 'New Vault Item',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 28),
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
              // Title / Service Selector
              _buildSectionLabel('Title / Platform Service'),
              DropdownButtonFormField<String>(
                initialValue: _selectedService,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  prefixIcon: Icon(
                    ServiceBrandHelper.getIconForService(_selectedService),
                    color: const Color(0xFF10B981),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
                items: _presetServices.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Row(
                      children: [
                        Icon(
                          ServiceBrandHelper.getIconForService(service),
                          color: const Color(0xFF94A3B8),
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

              // Custom Title / Service Input Field
              if (_isCustomService) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [TitleCaseTextInputFormatter()],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: 'Enter custom service name (e.g. Work Vpn)',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                  validator: (val) =>
                      (_isCustomService && (val == null || val.trim().isEmpty))
                          ? 'Custom service name is required'
                          : null,
                ),
              ],
              const SizedBox(height: 18),

              // Category Selector
              _buildSectionLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryOption,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  prefixIcon: const Icon(Icons.folder_outlined, color: Color(0xFF10B981)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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

              // Custom Category Input Field
              if (_isCustomCategory) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customCategoryController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [TitleCaseTextInputFormatter()],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: 'Enter custom category (e.g. Gaming, Cloud)',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF10B981)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                  validator: (val) =>
                      (_isCustomCategory && (val == null || val.trim().isEmpty))
                          ? 'Custom category is required'
                          : null,
                ),
              ],
              const SizedBox(height: 18),

              // Username / Email Field
              _buildSectionLabel('Username / Email (Optional if Phone/Account No. is provided)'),
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hintText: 'name@example.com',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF10B981)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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

              // Account / Phone Number (Optional) Field
              _buildSectionLabel('Account / Phone Number (Optional if Username/Email is provided)'),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hintText: 'e.g. 09171234567, 1234-5678-90',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF10B981)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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

              // Password / PIN Field with Generator button
              _buildSectionLabel('Password / PIN'),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hintText: 'Enter or generate password / PIN',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white60,
                        ),
                        onPressed: () =>
                            setState(() => _isPasswordVisible = !_isPasswordVisible),
                        tooltip: 'Toggle Visibility',
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981)),
                        onPressed: _openPasswordGenerator,
                        tooltip: 'Generate Strong Password',
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Password or PIN is required' : null,
              ),
              const SizedBox(height: 18),

              // Notes Field
              _buildSectionLabel('Secure Notes (Optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hintText: '2FA Backup codes, PINs, or security answers...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: Text(
                    isEditing ? 'UPDATE ENTRY' : 'SAVE ENCRYPTED ITEM',
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
