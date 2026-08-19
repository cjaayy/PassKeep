import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/utils/country_code_helper.dart';

void main() {
  group('CountryCodeHelper Tests', () {
    test('defaultCountryCode is Philippines (+63)', () {
      expect(CountryCodeHelper.defaultCountryCode.code, '+63');
      expect(CountryCodeHelper.defaultCountryCode.flag, '🇵🇭');
      expect(CountryCodeHelper.defaultCountryCode.name, 'Philippines');
    });

    test('findByCode finds known country codes or defaults to +63', () {
      expect(CountryCodeHelper.findByCode('+1').name, 'United States / Canada');
      expect(CountryCodeHelper.findByCode('+44').flag, '🇬🇧');
      expect(CountryCodeHelper.findByCode('+65').name, 'Singapore');
      expect(CountryCodeHelper.findByCode('+999').code, '+63'); // fallback
    });

    test('parsePhoneNumber handles empty or null', () {
      final res1 = CountryCodeHelper.parsePhoneNumber(null);
      expect(res1.country.code, '+63');
      expect(res1.localNumber, '');

      final res2 = CountryCodeHelper.parsePhoneNumber('');
      expect(res2.country.code, '+63');
      expect(res2.localNumber, '');
    });

    test('parsePhoneNumber parses formatted international numbers', () {
      final res1 = CountryCodeHelper.parsePhoneNumber('+63 9171234567');
      expect(res1.country.code, '+63');
      expect(res1.localNumber, '9171234567');

      final res2 = CountryCodeHelper.parsePhoneNumber('+1 (555) 123-4567');
      expect(res2.country.code, '+1');
      expect(res2.localNumber, '5551234567');

      final res3 = CountryCodeHelper.parsePhoneNumber('+852 98765432');
      expect(res3.country.code, '+852');
      expect(res3.localNumber, '98765432');
    });

    test('parsePhoneNumber handles PH local numbers starting with 0', () {
      final res = CountryCodeHelper.parsePhoneNumber('09171234567');
      expect(res.country.code, '+63');
      expect(res.localNumber, '9171234567');
    });

    test('formatFullPhoneNumber formats code and local digits', () {
      const ph = CountryCode(code: '+63', flag: '🇵🇭', name: 'Philippines');
      expect(CountryCodeHelper.formatFullPhoneNumber(ph, '9171234567'), '+63 9171234567');
      expect(CountryCodeHelper.formatFullPhoneNumber(ph, '0917-123-4567'), '+63 09171234567');
      expect(CountryCodeHelper.formatFullPhoneNumber(ph, ''), '');
    });
  });
}
