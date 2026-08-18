import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/clipboard_service.dart';
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
  bool _isPasswordVisible = false;
  String _plainUsername = '';
  String _plainPassword = '';
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
      final user = encryptionService.decrypt(
        cipherTextBase64: widget.item.usernameEncrypted,
        ivBase64: widget.item.iv,
      );
      final pass = encryptionService.decrypt(
        cipherTextBase64: widget.item.passwordEncrypted,
        ivBase64: widget.item.iv,
      );

      setState(() {
        _plainUsername = user;
        _plainPassword = pass;
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
      // Auto-hide password back to masked after 10 seconds
      _autoHideTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isPasswordVisible = false);
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

  @override
  Widget build(BuildContext context) {
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
                            widget.item.category,
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
              ] else ...[
                // Username field
                _buildFieldCard(
                  title: 'Username / Email',
                  content: _plainUsername,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                    onPressed: _copyUsername,
                    tooltip: 'Copy Username',
                  ),
                ),
                const SizedBox(height: 14),

                // Account / Phone Number field (if present)
                if (widget.item.accountNumber != null && widget.item.accountNumber!.isNotEmpty) ...[
                  _buildFieldCard(
                    title: 'Account / Phone Number',
                    content: widget.item.accountNumber!,
                    isMonospace: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                      onPressed: () => _copyAccountNumber(widget.item.accountNumber!),
                      tooltip: 'Copy Account Number',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
