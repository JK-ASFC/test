import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the audio files stored on the phone, for the built-in Fondu
/// musique app. Exposed by [LocalServer] under /__hub/music only for
/// built-in apps, never to downloaded projects.
class MusicLibrary {
  MusicLibrary({required this.roots, this.hasPermission, this.maxTracks = 10000});

  /// Folders searched recursively (internal storage, SD cards).
  final List<String> roots;

  /// Returns false when the app can't read shared storage yet.
  final Future<bool> Function()? hasPermission;

  final int maxTracks;

  List<Map<String, Object?>>? _cache;

  static const audioExtensions = {
    'mp3', 'm4a', 'aac', 'ogg', 'oga', 'opus', 'wav', 'flac', 'webm', '3gp', 'amr', 'mka',
  };

  /// Folders that only contain system sounds or app data.
  static const _skipped = {'android', 'notifications', 'ringtones', 'alarms', 'ui', 'lost.dir'};

  /// Internal storage plus any SD card / USB drive mounted under /storage.
  static List<String> androidRoots() {
    final out = <String>['/storage/emulated/0'];
    try {
      for (final e in Directory('/storage').listSync(followLinks: false)) {
        final name = p.basename(e.path);
        if (e is Directory && name != 'emulated' && name != 'self') out.add(e.path);
      }
    } on FileSystemException {
      // /storage not listable: internal storage only.
    }
    return out;
  }

  static bool isAudio(String path) =>
      audioExtensions.contains(p.extension(path).toLowerCase().replaceFirst('.', ''));

  /// True if [path] is an audio file inside one of the [roots].
  bool allows(String path) {
    final n = p.normalize(path);
    return isAudio(n) && roots.any((r) => p.isWithin(p.normalize(r), n));
  }

  /// JSON payload for GET /__hub/music.
  Future<Map<String, Object?>> list({bool refresh = false}) async {
    if (hasPermission != null && !await hasPermission!()) {
      return {'ok': false, 'needPermission': true, 'tracks': const []};
    }
    if (refresh || _cache == null) _cache = await _scan();
    return {'ok': true, 'needPermission': false, 'roots': roots, 'tracks': _cache};
  }

  Future<List<Map<String, Object?>>> _scan() async {
    final tracks = <Map<String, Object?>>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      await _walk(dir, root, 0, tracks);
      if (tracks.length >= maxTracks) break;
    }
    tracks.sort((a, b) {
      final f = (a['folder'] as String).toLowerCase().compareTo((b['folder'] as String).toLowerCase());
      return f != 0 ? f : (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });
    return tracks;
  }

  Future<void> _walk(Directory dir, String root, int depth, List<Map<String, Object?>> out) async {
    if (depth > 10 || out.length >= maxTracks) return;
    final subdirs = <Directory>[];
    try {
      await for (final e in dir.list(followLinks: false)) {
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          if (!_skipped.contains(name.toLowerCase())) subdirs.add(e);
        } else if (e is File && isAudio(e.path)) {
          final stat = await e.stat();
          if (stat.size < 20 * 1024) continue; // UI blips, not music
          final rel = p.relative(p.dirname(e.path), from: root);
          out.add({
            'path': e.path,
            'name': p.basenameWithoutExtension(e.path),
            'file': p.basename(e.path),
            'folder': rel == '.' ? p.basename(root) : rel,
            'size': stat.size,
            'modified': stat.modified.millisecondsSinceEpoch,
          });
          if (out.length >= maxTracks) return;
        }
      }
    } on FileSystemException {
      return; // unreadable folder
    }
    for (final d in subdirs) {
      await _walk(d, root, depth + 1, out);
    }
  }
}
