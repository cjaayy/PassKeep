/// Utility for extracting domains and resolving dynamic brand favicons via Google Favicon API
class DomainUtils {
  /// Known brand dictionary mapping service keywords/titles to official domains
  static const Map<String, String> _knownBrandDomains = {
    // E-Wallets & Philippine Banking
    'gcash': 'gcash.com',
    'maya': 'maya.ph',
    'paymaya': 'maya.ph',
    'bpi': 'bpiexpressonline.com',
    'bdo': 'bdo.com.ph',
    'metrobank': 'metrobank.com.ph',
    'unionbank': 'unionbankph.com',
    'securitybank': 'securitybank.com',
    'landbank': 'landbank.com',
    'rcbc': 'rcbc.com',
    'chinabank': 'chinabank.ph',
    'pnb': 'pnb.com.ph',
    'eastwest': 'eastwestbanker.com',
    'seabank': 'seabank.com.ph',
    'gotyme': 'gotyme.com.ph',
    'tonik': 'tonikbank.com',
    'komo': 'komo.ph',

    // Global Tech & Social
    'google': 'google.com',
    'gmail': 'google.com',
    'facebook': 'facebook.com',
    'fb': 'facebook.com',
    'meta': 'meta.com',
    'microsoft': 'microsoft.com',
    'outlook': 'microsoft.com',
    'hotmail': 'microsoft.com',
    'github': 'github.com',
    'gitlab': 'gitlab.com',
    'bitbucket': 'bitbucket.org',
    'twitter': 'x.com',
    'x': 'x.com',
    'instagram': 'instagram.com',
    'linkedin': 'linkedin.com',
    'reddit': 'reddit.com',
    'discord': 'discord.com',
    'slack': 'slack.com',
    'telegram': 'telegram.org',
    'whatsapp': 'whatsapp.com',
    'signal': 'signal.org',
    'apple': 'apple.com',
    'icloud': 'icloud.com',
    'amazon': 'amazon.com',
    'aws': 'aws.amazon.com',
    'netflix': 'netflix.com',
    'spotify': 'spotify.com',
    'youtube': 'youtube.com',
    'twitch': 'twitch.tv',
    'steam': 'steampowered.com',
    'paypal': 'paypal.com',
    'stripe': 'stripe.com',
    'wise': 'wise.com',
    'revolut': 'revolut.com',
    'binance': 'binance.com',
    'coinbase': 'coinbase.com',
    'shopee': 'shopee.ph',
    'lazada': 'lazada.com.ph',
    'tiktok': 'tiktok.com',
    'notion': 'notion.so',
    'figma': 'figma.com',
    'chatgpt': 'openai.com',
    'openai': 'openai.com',
    'adobe': 'adobe.com',
    'dropbox': 'dropbox.com',
  };

  /// Resolves the domain for a given service title or url
  static String extractDomain(String input) {
    var clean = input.trim().toLowerCase();

    // 1. If it starts with http:// or https://, parse Uri
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        if (uri.host.isNotEmpty) {
          return uri.host.replaceFirst(RegExp(r'^www\.'), '');
        }
      } catch (_) {}
    }

    // 2. Remove common url prefixes
    clean = clean.replaceFirst(RegExp(r'^https?:\/\/'), '');
    clean = clean.replaceFirst(RegExp(r'^www\.'), '');

    // Split on slash or colon to drop path/port
    clean = clean.split('/').first.split(':').first.trim();

    // 3. Direct domain check: If title contains a dot (e.g. github.com, myapp.io)
    if (clean.contains('.') && !clean.endsWith('.')) {
      return clean;
    }

    // 4. Check known brand dictionary
    final normalized = clean.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (_knownBrandDomains.containsKey(normalized)) {
      return _knownBrandDomains[normalized]!;
    }

    // Check individual words in clean input (e.g. "Facebook Personal", "Twitter / X", "Netflix Family")
    final words = clean.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    for (final word in words) {
      if (_knownBrandDomains.containsKey(word)) {
        return _knownBrandDomains[word]!;
      }
    }

    // Check compound brand keywords (length >= 3 to avoid single-letter collisions)
    for (final key in _knownBrandDomains.keys) {
      if (key.length >= 3 && normalized.contains(key)) {
        return _knownBrandDomains[key]!;
      }
    }

    // 5. Fallback clean domain: append .com
    if (normalized.isNotEmpty) {
      return '$normalized.com';
    }

    return 'google.com';
  }

  /// Resolves a 128px high-res favicon URL from Google Favicon API
  static String resolveFaviconUrl(String title) {
    final domain = extractDomain(title);
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }
}
