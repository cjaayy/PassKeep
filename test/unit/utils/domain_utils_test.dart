import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/utils/domain_utils.dart';

void main() {
  group('DomainUtils Favicon & Domain Resolution Tests', () {
    test('resolves known local and Philippine brands correctly', () {
      expect(DomainUtils.extractDomain('GCash'), 'gcash.com');
      expect(DomainUtils.extractDomain('gcash account'), 'gcash.com');
      expect(DomainUtils.extractDomain('Maya'), 'maya.ph');
      expect(DomainUtils.extractDomain('PayMaya'), 'maya.ph');
      expect(DomainUtils.extractDomain('BDO Online'), 'bdo.com.ph');
      expect(DomainUtils.extractDomain('BPI'), 'bpiexpressonline.com');
      expect(DomainUtils.extractDomain('Metrobank'), 'metrobank.com.ph');
      expect(DomainUtils.extractDomain('UnionBank Online'), 'unionbankph.com');
      expect(DomainUtils.extractDomain('Shopee'), 'shopee.ph');
      expect(DomainUtils.extractDomain('Lazada PH'), 'lazada.com.ph');
    });

    test('resolves global tech brands correctly', () {
      expect(DomainUtils.extractDomain('Google'), 'google.com');
      expect(DomainUtils.extractDomain('Gmail'), 'google.com');
      expect(DomainUtils.extractDomain('Facebook Personal'), 'facebook.com');
      expect(DomainUtils.extractDomain('Github'), 'github.com');
      expect(DomainUtils.extractDomain('Netflix Family'), 'netflix.com');
      expect(DomainUtils.extractDomain('Spotify Premium'), 'spotify.com');
      expect(DomainUtils.extractDomain('Steam'), 'steampowered.com');
      expect(DomainUtils.extractDomain('Discord'), 'discord.com');
      expect(DomainUtils.extractDomain('Twitter / X'), 'x.com');
    });

    test('preserves direct domains and URLs', () {
      expect(DomainUtils.extractDomain('github.com'), 'github.com');
      expect(DomainUtils.extractDomain('mycustomsite.org'), 'mycustomsite.org');
      expect(DomainUtils.extractDomain('https://dashboard.stripe.com/login'), 'dashboard.stripe.com');
      expect(DomainUtils.extractDomain('https://www.reddit.com/r/flutter'), 'reddit.com');
    });

    test('generates fallback .com domain for unrecognized clean titles', () {
      expect(DomainUtils.extractDomain('MyCompanyApp'), 'mycompanyapp.com');
      expect(DomainUtils.extractDomain('Awesome Service 123'), 'awesomeservice123.com');
    });

    test('resolveFaviconUrl constructs high-res Google Favicon API endpoint', () {
      final url = DomainUtils.resolveFaviconUrl('GCash');
      expect(url, 'https://www.google.com/s2/favicons?domain=gcash.com&sz=128');

      final directUrl = DomainUtils.resolveFaviconUrl('cloudflare.com');
      expect(directUrl, 'https://www.google.com/s2/favicons?domain=cloudflare.com&sz=128');
    });
  });
}
