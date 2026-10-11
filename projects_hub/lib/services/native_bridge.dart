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

  // ---------- Media notification (built-in music player) ----------

  /// Called with (action, positionMs) when a button of the media
  /// notification is pressed: play, pause, next, prev, seek, rewind,
  /// forward, stop.
  static void Function(String action, int positionMs)? onMediaAction;

  /// Listens for calls coming from MainActivity. Call once at startup.
  static void init() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'mediaAction') {
        final args = (call.arguments as Map).cast<String, Object?>();
        onMediaAction?.call(args['action'] as String? ?? '', (args['position'] as num?)?.toInt() ?? -1);
      }
    });
  }

  /// Shows/updates the media notification (title, artist, play state, position).
  static Future<void> mediaUpdate({
    required String title,
    required String artist,
    required bool playing,
    required int positionMs,
    required int durationMs,
    int hue = 280,
  }) =>
      _ch.invokeMethod<void>('mediaUpdate', {
        'title': title,
        'artist': artist,
        'playing': playing,
        'position': positionMs,
        'duration': durationMs,
        'hue': hue,
      });

  static Future<void> mediaStop() => _ch.invokeMethod<void>('mediaStop');
}
