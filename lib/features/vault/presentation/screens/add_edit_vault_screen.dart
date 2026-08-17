import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/security_providers.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_providers.dart';
import '../widgets/password_generator_sheet.dart';

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
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;
  String _selectedCategory = 'General';
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  final List<String> _categories = ['General', 'Work', 'Social', 'Finance', 'Personal'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingItem?.title ?? '');
    _notesController = TextEditingController(text: widget.existingItem?.notes ?? '');
    _selectedCategory = widget.existingItem?.category ?? 'General';

    // Decrypt fields if editing
    if (widget.existingItem != null) {
      final encryptionService = ref.read(encryptionServiceProvider);
      try {
        final plainUser = encryptionService.decrypt(
          cipherTextBase64: widget.existingItem!.usernameEncrypted,
          ivBase64: widget.existingItem!.iv,
        );
        final plainPass = encryptionService.decrypt(
          cipherTextBase64: widget.existingItem!.passwordEncrypted,
          ivBase64: widget.existingItem!.iv,
        );
        _usernameController = TextEditingController(text: plainUser);
        _passwordController = TextEditingController(text: plainPass);
      } catch (_) {
        _usernameController = TextEditingController(text: '');
        _passwordController = TextEditingController(text: '');
      }
    } else {
      _usernameController = TextEditingController();
      _passwordController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final encryptionService = ref.read(encryptionServiceProvider);

      final encUser = encryptionService.encrypt(_usernameController.text.trim());
      final encPass = encryptionService.encrypt(
        _passwordController.text,
      );

      final itemToSave = VaultItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        usernameEncrypted: encUser.cipherTextBase64,
        passwordEncrypted: encPass.cipherTextBase64,
        iv: encPass.ivBase64,
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isSynced: false, // Mark unsynced so bidirectional sync engine pushes it
        updatedAt: DateTime.now(),
      );

      await ref.read(vaultNotifierProvider.notifier).saveItem(itemToSave);

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Item' : 'New Vault Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              // Title Field
              _buildSectionLabel('Title / Service'),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. GitHub, Google, Work VPN',
                  prefixIcon: Icon(Icons.label_outline_rounded, color: Color(0xFF10B981)),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 18),

              // Category Selector
              _buildSectionLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_outlined, color: Color(0xFF10B981)),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 18),

              // Username / Email Field
              _buildSectionLabel('Username / Email'),
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF10B981)),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Username is required' : null,
              ),
              const SizedBox(height: 18),

              // Password Field with Generator button
              _buildSectionLabel('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter or generate password',
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
                ),
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: 18),

              // Notes Field
              _buildSectionLabel('Secure Notes (Optional)'),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '2FA Backup codes, PINs, or security answers...',
                  alignLabelWithHint: true,
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
                    isEditing ? 'Update Entry' : 'Save Encrypted Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
