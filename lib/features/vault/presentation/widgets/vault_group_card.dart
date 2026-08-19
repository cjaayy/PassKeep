import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/card_brand_helper.dart';
import '../../../../core/utils/domain_utils.dart';
import '../../../../core/utils/service_brand_helper.dart';
import '../../data/models/vault_item.dart';
import '../providers/vault_state.dart';

/// Expandable grouped card representing multiple accounts under the same service/app.
/// Sub-accounts are generically labeled ("Account 1", "Account 2", etc.) with brand icons
/// and an explicit "View" action button for privacy and security.
class VaultGroupCard extends StatefulWidget {
  final VaultItemGroup group;
  final void Function(VaultItem item) onItemTap;

  const VaultGroupCard({
    super.key,
    required this.group,
    required this.onItemTap,
  });

  @override
  State<VaultGroupCard> createState() => _VaultGroupCardState();
}

class _VaultGroupCardState extends State<VaultGroupCard>
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    final isCardGroup = widget.group.items.any((i) => i.isCard);

    final IconData brandIcon;
    if (isCardGroup) {
      final brand = CardBrandHelper.detectBrand(widget.group.title);
      brandIcon = brand.icon;
    } else {
      brandIcon = ServiceBrandHelper.getIconForService(
        widget.group.title,
        category: widget.group.primaryCategory,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(16),
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
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isCardGroup
                        ? Icon(
                            brandIcon,
                            color: textPrimary,
                            size: 20,
                          )
                        : Image.network(
                            DomainUtils.resolveFaviconUrl(widget.group.title),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              brandIcon,
                              color: textPrimary,
                              size: 20,
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: child,
                                );
                              }
                              return Icon(
                                brandIcon,
                                color: textPrimary,
                                size: 20,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Service Title + Account Count Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.group.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
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
                                color: inputFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCardGroup ? 'CARDS' : widget.group.primaryCategory.toUpperCase(),
                                style: TextStyle(
                                  color: textMuted,
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
                                color: inputFill,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.group.count} ${isCardGroup ? 'CARDS' : 'ACCOUNTS'}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• Tap to expand',
                              style: TextStyle(
                                color: textMuted,
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
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textMuted,
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
                Divider(color: dividerColor, height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.group.items.length,
                  separatorBuilder: (context, index) => Divider(
                    color: dividerColor,
                    height: 1,
                    indent: 56,
                  ),
                  itemBuilder: (context, index) {
                    final subItem = widget.group.items[index];
                    final accountLabel = isCardGroup ? 'Card ${index + 1}' : 'Account ${index + 1}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 9.0),
                      child: Row(
                        children: [
                          // Small Platform Brand Icon Badge
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isCardGroup
                                ? Icon(
                                    brandIcon,
                                    color: textPrimary,
                                    size: 16,
                                  )
                                : Image.network(
                                    DomainUtils.resolveFaviconUrl(widget.group.title),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      brandIcon,
                                      color: textPrimary,
                                      size: 16,
                                    ),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: child,
                                        );
                                      }
                                      return Icon(
                                        brandIcon,
                                        color: textPrimary,
                                        size: 16,
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // Generic Account Label ("Account 1", "Account 2", etc.)
                          Expanded(
                            child: Text(
                              accountLabel,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Explicit "View" Action Button
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onItemTap(subItem),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 13,
                                    color: textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
