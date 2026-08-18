import 'dart:convert';
import '../../../../core/utils/card_brand_helper.dart';

/// Model representing decrypted credit / debit card details.
class CardDetails {
  final String cardholderName;
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final String cardPin;

  const CardDetails({
    this.cardholderName = '',
    this.cardNumber = '',
    this.expiryDate = '',
    this.cvv = '',
    this.cardPin = '',
  });

  Map<String, dynamic> toMap() => {
        'cardholderName': cardholderName,
        'cardNumber': cardNumber,
        'expiryDate': expiryDate,
        'cvv': cvv,
        'cardPin': cardPin,
      };

  factory CardDetails.fromMap(Map<String, dynamic> map) => CardDetails(
        cardholderName: (map['cardholderName'] as String?) ?? '',
        cardNumber: (map['cardNumber'] as String?) ?? '',
        expiryDate: (map['expiryDate'] as String?) ?? '',
        cvv: (map['cvv'] as String?) ?? '',
        cardPin: (map['cardPin'] as String?) ?? '',
      );

  String toJson() => jsonEncode(toMap());

  factory CardDetails.fromJson(String source) {
    if (source.trim().isEmpty) return const CardDetails();
    try {
      return CardDetails.fromMap(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return const CardDetails();
    }
  }

  /// Returns the last 4 digits of the card number
  String get last4 {
    final clean = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.length < 4) return clean;
    return clean.substring(clean.length - 4);
  }

  /// Returns formatted masked card number (e.g. `•••• •••• •••• 1234`)
  String get maskedCardNumber {
    final clean = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.isEmpty) return '•••• •••• •••• ••••';
    if (clean.length <= 4) return '•••• •••• •••• $clean';
    final l4 = clean.substring(clean.length - 4);
    return '•••• •••• •••• $l4';
  }

  /// Returns the detected card brand (Visa, Mastercard, Amex, etc.)
  CardBrand get brand => CardBrandHelper.detectBrand(cardNumber);
}
