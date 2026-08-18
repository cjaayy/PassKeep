import 'package:flutter/material.dart';

/// Supported Payment Card Brands
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
}

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

    // JCB: 3528-3589
    if (RegExp(r'^(352[89]|35[3-8][0-9])').hasMatch(clean)) {
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
}
