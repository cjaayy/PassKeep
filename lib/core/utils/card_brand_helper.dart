import 'package:flutter/material.dart';

/// Supported Payment Card Networks / Brands
enum CardBrand {
  visa('Visa', Icons.credit_card_rounded, Color(0xFF1A1F71)),
  mastercard('Mastercard', Icons.credit_card_rounded, Color(0xFFEB001B)),
  amex('American Express', Icons.credit_card_rounded, Color(0xFF006FCF)),
  discover('Discover', Icons.credit_card_rounded, Color(0xFFFF6000)),
  jcb('JCB', Icons.credit_card_rounded, Color(0xFF00377B)),
  dinersClub('Diners Club', Icons.credit_card_rounded, Color(0xFF0079BE)),
  unionPay('UnionPay', Icons.credit_card_rounded, Color(0xFFE21B23)),
  generic('Card', Icons.credit_card_rounded, Color(0xFF334155));

  final String displayName;
  final IconData icon;
  final Color brandColor;

  const CardBrand(this.displayName, this.icon, this.brandColor);

  /// Builds a modern styled badge widget representing the card network logo
  Widget buildBadge({double height = 24, bool showBorder = true}) {
    switch (this) {
      case CardBrand.visa:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F71),
            borderRadius: BorderRadius.circular(6),
            border: showBorder ? Border.all(color: const Color(0xFF2E389C), width: 1) : null,
          ),
          child: const Center(
            child: Text(
              'VISA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
        );

      case CardBrand.mastercard:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: showBorder ? Border.all(color: const Color(0xFF334155), width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overlapping Circles
              SizedBox(
                width: 24,
                height: 16,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEB001B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 9,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'mastercard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        );

      case CardBrand.amex:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF006FCF),
            borderRadius: BorderRadius.circular(6),
            border: showBorder ? Border.all(color: const Color(0xFF389BFF), width: 1) : null,
          ),
          child: const Center(
            child: Text(
              'AMEX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case CardBrand.jcb:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00377B), Color(0xFF006FCF)],
            ),
            borderRadius: BorderRadius.circular(6),
            border: showBorder ? Border.all(color: const Color(0xFF389BFF), width: 1) : null,
          ),
          child: const Center(
            child: Text(
              'JCB',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );

      case CardBrand.discover:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              'DISCOVER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );

      default:
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: showBorder ? Border.all(color: const Color(0xFF334155), width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.credit_card_rounded, color: Color(0xFF10B981), size: 14),
              const SizedBox(width: 4),
              Text(
                displayName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// Alias for [CardBrand] to align with network terminology
typedef CardNetwork = CardBrand;

/// Utility for detecting credit/debit card brands and formatting card numbers
class CardBrandHelper {
  /// Detects the card brand based on leading IIN/BIN digits
  static CardBrand detectBrand(String cardNumber) {
    final clean = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.isEmpty) return CardBrand.generic;

    // Visa: starts with 4
    if (clean.startsWith('4')) {
      return CardBrand.visa;
    }

    // Mastercard: 51-55 or 2221-2720
    if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)').hasMatch(clean)) {
      return CardBrand.mastercard;
    }

    // American Express: 34 or 37
    if (RegExp(r'^(34|37)').hasMatch(clean)) {
      return CardBrand.amex;
    }

    // Discover: 6011, 65, 644-649, 622
    if (RegExp(r'^(6011|65|64[4-9]|622)').hasMatch(clean)) {
      return CardBrand.discover;
    }

    // JCB: 3528-3589 or 35
    if (RegExp(r'^(352[89]|35[3-8][0-9]|35)').hasMatch(clean)) {
      return CardBrand.jcb;
    }

    // Diners Club: 300-305, 36, 38
    if (RegExp(r'^(30[0-5]|36|38)').hasMatch(clean)) {
      return CardBrand.dinersClub;
    }

    // UnionPay: 62
    if (clean.startsWith('62')) {
      return CardBrand.unionPay;
    }

    return CardBrand.generic;
  }

  /// Helper matching `detectCardNetwork` requirement
  static CardNetwork detectCardNetwork(String cardNumber) => detectBrand(cardNumber);
}
