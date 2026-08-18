import 'package:flutter/material.dart';

/// Helper utility for detecting brand icons and initials based on service titles
class ServiceBrandHelper {
  /// Returns a relevant IconData for recognized platforms and apps
  static IconData getIconForService(String serviceName, {String category = ''}) {
    final name = serviceName.trim().toLowerCase();

    // Google / Gmail / Productivity
    if (name.contains('gmail') || name.contains('google mail')) {
      return Icons.mail_outline_rounded;
    }
    if (name.contains('google') || name.contains('drive') || name.contains('workspace')) {
      return Icons.cloud_queue_rounded;
    }
    if (name.contains('outlook') ||
        name.contains('microsoft') ||
        name.contains('office') ||
        name.contains('hotmail') ||
        name.contains('live.com') ||
        name.contains('exchange')) {
      return Icons.mark_email_read_outlined;
    }
    if (name.contains('yahoo') ||
        name.contains('proton') ||
        name.contains('mail') ||
        name.contains('zoho')) {
      return Icons.email_outlined;
    }

    // Developer / Code
    if (name.contains('github') || name.contains('gitlab') || name.contains('bitbucket')) {
      return Icons.code_rounded;
    }
    if (name.contains('aws') ||
        name.contains('azure') ||
        name.contains('gcp') ||
        name.contains('cloud') ||
        name.contains('supabase') ||
        name.contains('firebase') ||
        name.contains('digitalocean')) {
      return Icons.cloud_done_outlined;
    }
    if (name.contains('terminal') ||
        name.contains('ssh') ||
        name.contains('server') ||
        name.contains('linux')) {
      return Icons.terminal_rounded;
    }

    // Social Media & Messaging
    if (name.contains('facebook') || name.contains('meta')) {
      return Icons.facebook_rounded;
    }
    if (name.contains('twitter') || name.contains('x.com') || name.contains('threads')) {
      return Icons.alternate_email_rounded;
    }
    if (name.contains('instagram')) {
      return Icons.camera_alt_outlined;
    }
    if (name.contains('linkedin')) {
      return Icons.business_center_outlined;
    }
    if (name.contains('reddit')) {
      return Icons.forum_outlined;
    }
    if (name.contains('discord') ||
        name.contains('slack') ||
        name.contains('telegram') ||
        name.contains('whatsapp') ||
        name.contains('signal')) {
      return Icons.chat_bubble_outline_rounded;
    }

    // Entertainment / Media
    if (name.contains('netflix') ||
        name.contains('youtube') ||
        name.contains('spotify') ||
        name.contains('hulu') ||
        name.contains('disney') ||
        name.contains('twitch')) {
      return Icons.play_circle_outline_rounded;
    }

    // Shopping / E-commerce
    if (name.contains('amazon') ||
        name.contains('ebay') ||
        name.contains('shopify') ||
        name.contains('aliexpress') ||
        name.contains('walmart')) {
      return Icons.shopping_bag_outlined;
    }

    // Finance / Banking / E-Wallets / Crypto
    if (name.contains('paypal') ||
        name.contains('stripe') ||
        name.contains('wise') ||
        name.contains('revolut') ||
        name.contains('gcash') ||
        name.contains('maya') ||
        name.contains('paymaya') ||
        name.contains('bank') ||
        name.contains('chase') ||
        name.contains('bdo') ||
        name.contains('bpi') ||
        name.contains('crypto') ||
        name.contains('binance') ||
        name.contains('coinbase')) {
      return Icons.account_balance_wallet_outlined;
    }

    // Education / School
    if (name.contains('school') ||
        name.contains('university') ||
        name.contains('college') ||
        name.contains('canvas') ||
        name.contains('blackboard') ||
        name.contains('moodle') ||
        name.contains('student') ||
        name.contains('portal')) {
      return Icons.school_outlined;
    }

    // Apple
    if (name.contains('apple') || name.contains('icloud')) {
      return Icons.apple_rounded;
    }

    // Password manager / Vault
    if (name.contains('bitwarden') ||
        name.contains('1password') ||
        name.contains('lastpass') ||
        name.contains('passkeep') ||
        name.contains('keepass')) {
      return Icons.shield_outlined;
    }

    // Categories fallback
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'school':
      case 'education':
        return Icons.school_outlined;
      case 'social':
        return Icons.people_outline_rounded;
      case 'finance':
        return Icons.account_balance_outlined;
      case 'personal':
        return Icons.person_outline_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }
}
