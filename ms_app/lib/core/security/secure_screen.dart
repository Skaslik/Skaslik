import 'package:flutter/services.dart';

/// Hides something private from prying: on Android it blocks screenshots,
/// screen recording and the recent-apps thumbnail (FLAG_SECURE, set in
/// MainActivity.kt); on iPhone it blurs the app-switcher snapshot
/// (AppDelegate.swift; iOS can't block screenshots). Elsewhere it does
/// nothing.
abstract final class SecureScreen {
  static const _channel = MethodChannel('ms/secure_screen');

  static Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod<void>('set', on);
    } on MissingPluginException {
      // Not Android (or a test without a handler): nothing to hide.
    } on PlatformException {
      // The window refused; the safe still works.
    }
  }
}
