import 'dart:async';
import 'package:flutter/services.dart';

/// Service managing secure clipboard interactions with automated timeout clearing.
abstract final class ClipboardService {
  static Timer? _clearTimer;

  /// Copies [text] to clipboard and schedules an automatic wipe after [duration] (default 30s).
  static Future<void> copyWithAutoClear(
    String text, {
    Duration duration = const Duration(seconds: 30),
  }) async {
    _clearTimer?.cancel();

    await Clipboard.setData(ClipboardData(text: text));

    _clearTimer = Timer(duration, () async {
      final currentData = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentData?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  /// Immediately clears the clipboard.
  static Future<void> clear() async {
    _clearTimer?.cancel();
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
