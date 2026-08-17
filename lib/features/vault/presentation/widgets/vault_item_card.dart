import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/clipboard_service.dart';
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return const Color(0xFF3B82F6); // Blue
      case 'social':
        return const Color(0xFF8B5CF6); // Purple
      case 'finance':
        return const Color(0xFF10B981); // Emerald
      case 'personal':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'social':
        return Icons.people_outline_rounded;
      case 'finance':
        return Icons.account_balance_outlined;
      case 'personal':
        return Icons.person_outline_rounded;
      default:
        return Icons.lock_outline_rounded;
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
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
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
    final catColor = _getCategoryColor(item.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF1E293B),
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
              // Category Icon Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getCategoryIcon(item.category), color: catColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Title and Masked Details
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: catColor.withValues(alpha: 0.3), width: 0.8),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '••••••••••••',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Copy Button
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white60, size: 20),
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
