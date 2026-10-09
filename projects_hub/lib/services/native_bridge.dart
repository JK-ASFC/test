import 'package:flutter/services.dart';

/// Small Android-only helpers implemented in MainActivity.kt.
class NativeBridge {
  static const _ch = MethodChannel('projects_hub/native');

  static Future<bool> isAppInstalled(String packageName) async =>
      await _ch.invokeMethod<bool>('isAppInstalled', {'package': packageName}) ?? false;

  /// Opens another installed app. Returns false if it isn't installed.
  static Future<bool> launchApp(String packageName) async =>
      await _ch.invokeMethod<bool>('launchApp', {'package': packageName}) ?? false;

  /// Opens a link in the default browser (e.g. to download an APK).
  static Future<bool> openUrl(String url) async =>
      await _ch.invokeMethod<bool>('openUrl', {'url': url}) ?? false;

  /// "All files access", needed to serve a folder picked anywhere on the phone.
  static Future<bool> hasAllFilesAccess() async =>
      await _ch.invokeMethod<bool>('hasAllFilesAccess') ?? false;

  static Future<void> requestAllFilesAccess() =>
      _ch.invokeMethod<void>('requestAllFilesAccess');
}
