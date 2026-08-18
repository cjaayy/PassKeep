import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/clipboard_service.dart';
import '../../../../core/utils/service_brand_helper.dart';
import '../../data/models/vault_item.dart';

/// Card widget representing a single encrypted VaultItem in the list
class VaultItemCard extends ConsumerWidget {
  final VaultItem item;
  final VoidCallback onTap;

  const VaultItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _getDecryptedUsername(WidgetRef ref) {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final plainUsername = encryptionService.decrypt(
        cipherTextBase64: item.usernameEncrypted,
        ivBase64: item.iv,
      );
      return plainUsername.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _quickCopyPassword(BuildContext context, WidgetRef ref) async {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final plainPassword = encryptionService.decrypt(
        cipherTextBase64: item.passwordEncrypted,
        ivBase64: item.iv,
      );

      await ClipboardService.copyWithAutoClear(plainPassword);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                Text('Copied password for "${item.title}". Auto-clears in 30s.'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decrypt password: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = _getDecryptedUsername(ref);
    final displaySubtitle = username.isNotEmpty
        ? username
        : (item.accountNumber != null && item.accountNumber!.isNotEmpty
            ? item.accountNumber!
            : (item.usernameEncrypted.isNotEmpty ? '••••••••' : 'No identifier'));

    final brandIcon = ServiceBrandHelper.getIconForService(
      item.title,
      category: item.category,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Dynamic Service Brand Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Icon(
                  brandIcon,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Account Username/Email Subtext
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Monochromatic Neutral Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF475569), width: 0.8),
                          ),
                          child: Text(
                            item.category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displaySubtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Quick Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                tooltip: 'Copy Password',
                onPressed: () => _quickCopyPassword(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
