import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/security_providers.dart';
import '../../../../core/utils/clipboard_service.dart';
import '../../../../core/utils/service_brand_helper.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_state.dart';

/// Expandable grouped card representing multiple accounts under the same service/app
class VaultGroupCard extends ConsumerStatefulWidget {
  final VaultItemGroup group;
  final void Function(VaultItem item) onItemTap;

  const VaultGroupCard({
    super.key,
    required this.group,
    required this.onItemTap,
  });

  @override
  ConsumerState<VaultGroupCard> createState() => _VaultGroupCardState();
}

class _VaultGroupCardState extends ConsumerState<VaultGroupCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _chevronAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _getDecryptedUsername(VaultItem item) {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final plain = encryptionService.decrypt(
        cipherTextBase64: item.usernameEncrypted,
        ivBase64: item.iv,
      );
      return plain.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _quickCopyPassword(VaultItem item) async {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final plainPassword = encryptionService.decrypt(
        cipherTextBase64: item.passwordEncrypted,
        ivBase64: item.iv,
      );

      await ClipboardService.copyWithAutoClear(plainPassword);

      if (mounted) {
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
      if (mounted) {
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
  Widget build(BuildContext context) {
    final brandIcon = ServiceBrandHelper.getIconForService(
      widget.group.title,
      category: widget.group.primaryCategory,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isExpanded ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleExpand,
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

                  // Title and Multi-Account Counter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.group.title,
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
                            // Category Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF475569), width: 0.8),
                              ),
                              child: Text(
                                widget.group.primaryCategory.toUpperCase(),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.group.count} ACCOUNTS',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '• Tap to expand',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand / Collapse Animated Chevron
                  RotationTransition(
                    turns: _chevronAnimation,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Sub-Account Items List
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(color: Color(0xFF334155), height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.group.items.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFF334155),
                    height: 1,
                    indent: 56,
                  ),
                  itemBuilder: (context, index) {
                    final subItem = widget.group.items[index];
                    final username = _getDecryptedUsername(subItem);
                    final displaySubtitle = username.isNotEmpty
                        ? username
                        : (subItem.usernameEncrypted.isNotEmpty ? '••••••••' : 'No username');

                    return InkWell(
                      onTap: () => widget.onItemTap(subItem),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        child: Row(
                          children: [
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.account_circle_outlined,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                displaySubtitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                              tooltip: 'Copy Password',
                              onPressed: () => _quickCopyPassword(subItem),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
