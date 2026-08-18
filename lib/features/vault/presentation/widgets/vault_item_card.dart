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

  Future<void> _quickCopyCredential(BuildContext context, WidgetRef ref) async {
    try {
      final encryptionService = ref.read(encryptionServiceProvider);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      if (item.isCard) {
        String cardNumber = '';
        if (item.cardDetailsEnc != null && item.cardDetailsEnc!.isNotEmpty) {
          final decryptedCardJson = encryptionService.decrypt(
            cipherTextBase64: item.cardDetailsEnc!,
            ivBase64: item.iv,
          );
          final card = CardDetails.fromJson(decryptedCardJson);
          cardNumber = card.cardNumber;
        } else {
          cardNumber = encryptionService.decrypt(
            cipherTextBase64: item.passwordEncrypted,
            ivBase64: item.iv,
          );
        }

        await ClipboardService.copyWithAutoClear(cardNumber.replaceAll(RegExp(r'\s+'), ''));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Copied card number for "${item.title}". Auto-clears in 30s.'),
                  ),
                ],
              ),
              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
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
                  Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? AppTheme.darkPrimary : AppTheme.lightOnPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Copied password for "${item.title}". Auto-clears in 30s.'),
                  ),
                ],
              ),
              backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightPrimary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: ${e.toString()}'),
            backgroundColor: AppTheme.darkDestructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final username = _getDecryptedUsername(ref);
    final displaySubtitle = item.getPrimaryIdentifier(decryptedUsername: username);

    final CardBrand cardBrand;
    final IconData brandIcon;
    if (item.isCard) {
      cardBrand = CardBrandHelper.detectBrand(item.accountNumber ?? item.title);
      brandIcon = cardBrand.icon;
    } else {
      cardBrand = CardBrand.generic;
      brandIcon = ServiceBrandHelper.getIconForService(
        item.title,
        category: item.category,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Dynamic Bank / Service Brand Favicon Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  DomainUtils.resolveFaviconUrl(item.title),
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

              // Title and Identifier Subtext
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
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
                        // Category / Card Badge (Monochromatic, borderless)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.isCard ? 'CARD' : item.category.toUpperCase(),
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
                    const SizedBox(height: 4),
                    if (item.isCard)
                      Row(
                        children: [
                          cardBrand.buildBadge(height: 18, showBorder: false),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              displaySubtitle,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        displaySubtitle,
                        style: TextStyle(
                          color: textMuted,
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
                icon: Icon(Icons.copy_rounded, color: textMuted, size: 18),
                tooltip: item.isCard ? 'Copy Card Number' : 'Copy Password',
                onPressed: () => _quickCopyCredential(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
