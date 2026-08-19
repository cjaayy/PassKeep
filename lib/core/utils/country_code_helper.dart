/// Country code model representing an international dialing prefix
class CountryCode {
  final String code; // e.g. '+63'
  final String flag; // e.g. '🇵🇭'
  final String name; // e.g. 'Philippines'

  const CountryCode({
    required this.code,
    required this.flag,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$flag $code';
}

/// Helper utility for international country calling codes
class CountryCodeHelper {
  static const CountryCode defaultCountryCode = CountryCode(
    code: '+63',
    flag: '🇵🇭',
    name: 'Philippines',
  );

  static const List<CountryCode> commonCountryCodes = [
    CountryCode(code: '+63', flag: '🇵🇭', name: 'Philippines'),
    CountryCode(code: '+1', flag: '🇺🇸', name: 'United States / Canada'),
    CountryCode(code: '+44', flag: '🇬🇧', name: 'United Kingdom'),
    CountryCode(code: '+65', flag: '🇸🇬', name: 'Singapore'),
    CountryCode(code: '+81', flag: '🇯🇵', name: 'Japan'),
    CountryCode(code: '+61', flag: '🇦🇺', name: 'Australia'),
    CountryCode(code: '+852', flag: '🇭🇰', name: 'Hong Kong'),
    CountryCode(code: '+971', flag: '🇦🇪', name: 'United Arab Emirates'),
    CountryCode(code: '+49', flag: '🇩🇪', name: 'Germany'),
    CountryCode(code: '+91', flag: '🇮🇳', name: 'India'),
    CountryCode(code: '+82', flag: '🇰🇷', name: 'South Korea'),
    CountryCode(code: '+886', flag: '🇹🇼', name: 'Taiwan'),
    CountryCode(code: '+60', flag: '🇲🇾', name: 'Malaysia'),
    CountryCode(code: '+62', flag: '🇮🇩', name: 'Indonesia'),
    CountryCode(code: '+66', flag: '🇹🇭', name: 'Thailand'),
    CountryCode(code: '+84', flag: '🇻🇳', name: 'Vietnam'),
    CountryCode(code: '+33', flag: '🇫🇷', name: 'France'),
    CountryCode(code: '+39', flag: '🇮🇹', name: 'Italy'),
    CountryCode(code: '+34', flag: '🇪🇸', name: 'Spain'),
    CountryCode(code: '+55', flag: '🇧🇷', name: 'Brazil'),
    CountryCode(code: '+52', flag: '🇲🇽', name: 'Mexico'),
    CountryCode(code: '+966', flag: '🇸🇦', name: 'Saudi Arabia'),
    CountryCode(code: '+974', flag: '🇶🇦', name: 'Qatar'),
    CountryCode(code: '+64', flag: '🇳🇿', name: 'New Zealand'),
  ];

  static CountryCode findByCode(String code) {
    final clean = code.trim();
    return commonCountryCodes.firstWhere(
      (c) => c.code == clean,
      orElse: () => defaultCountryCode,
    );
  }

  /// Parses a raw phone string into (CountryCode, localNumber).
  /// E.g. "+63 9171234567" -> (CountryCode(+63), "9171234567")
  /// E.g. "+1 (555) 123-4567" -> (CountryCode(+1), "5551234567")
  /// E.g. "09171234567" -> (CountryCode(+63), "9171234567")
  static ({CountryCode country, String localNumber}) parsePhoneNumber(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      return (country: defaultCountryCode, localNumber: '');
    }

    final trimmed = rawPhone.trim();

    if (trimmed.startsWith('+')) {
      final sortedCodes = List<CountryCode>.from(commonCountryCodes)
        ..sort((a, b) => b.code.length.compareTo(a.code.length));

      for (final item in sortedCodes) {
        if (trimmed.startsWith(item.code)) {
          final remainder = trimmed.substring(item.code.length).replaceAll(RegExp(r'\D'), '');
          return (country: item, localNumber: remainder);
        }
      }

      final parts = trimmed.split(' ');
      if (parts.length > 1) {
        final codePart = parts.first;
        final remainder = parts.sublist(1).join('').replaceAll(RegExp(r'\D'), '');
        final matched = findByCode(codePart);
        return (country: matched, localNumber: remainder);
      }
    }

    String cleanDigits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.startsWith('0') && cleanDigits.length == 11) {
      cleanDigits = cleanDigits.substring(1);
    }

    return (country: defaultCountryCode, localNumber: cleanDigits);
  }

  /// Formats country code and local number for storage.
  /// E.g. "+63", "9171234567" -> "+63 9171234567"
  static String formatFullPhoneNumber(CountryCode country, String localNumber) {
    final cleanLocal = localNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanLocal.isEmpty) return '';
    return '${country.code} $cleanLocal';
  }
}
