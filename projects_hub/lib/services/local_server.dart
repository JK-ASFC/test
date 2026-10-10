import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'music_library.dart';

/// Minimal static HTTP server bound to 127.0.0.1.
///
/// Serving projects over http:// (instead of file://) makes them behave like
/// they do with `python -m http.server`: fetch(), ES modules, IndexedDB,
/// localStorage and video seeking (Range requests) all work.
///
/// Each project gets its own stable port so that it has its own web origin:
/// its localStorage/IndexedDB data is kept between launches and never mixed
/// with another project's.
class LocalServer {
  LocalServer._(this._server, this.root, this.music);

  final HttpServer _server;
  final String root;

  /// Phone music, exposed under /__hub/music for built-in apps only.
  final MusicLibrary? music;

  int get port => _server.port;
  String get origin => 'http://127.0.0.1:$port';

  static LocalServer? _current;

  /// Starts (or reuses) the server for [root] on [preferredPort].
  static Future<LocalServer> start(String root, int preferredPort, {MusicLibrary? music}) async {
    final cur = _current;
    if (cur != null && cur.root == root && cur.port == preferredPort && cur.music == music) return cur;
    await stopCurrent();
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, preferredPort);
    } on SocketException {
      // Port taken by something else: fall back to a random one (the project
      // still works, it just won't see data saved under its usual port).
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    final s = LocalServer._(server, root, music);
    server.listen(s._handle, onError: (_) {});
    _current = s;
    return s;
  }

  static Future<void> stopCurrent() async {
    final cur = _current;
    _current = null;
    await cur?._server.close(force: true);
  }

  /// Stable port in 20000..39999 derived from the project id (FNV-1a).
  static int portFor(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return 20000 + h % 20000;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      if (req.method != 'GET' && req.method != 'HEAD') {
        res.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (req.uri.path.startsWith('/__hub/')) {
        await _handleHub(req);
        return;
      }
      final file = resolve(root, req.uri.path);
      if (file == null) {
        _notFound(res, req.uri.path);
        return;
      }
      res.headers.set('Access-Control-Allow-Origin', '*');
      await _sendFile(req, file);
    } catch (_) {
      try {
        res.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  /// GET /__hub/music[?refresh=1] -> JSON list of the phone's audio files.
  /// GET /__hub/music/file?p=/absolute/path.mp3 -> the file (Range supported).
  Future<void> _handleHub(HttpRequest req) async {
    final res = req.response;
    final lib = music;
    if (lib == null) {
      _notFound(res, req.uri.path);
      return;
    }
    if (req.uri.path == '/__hub/music') {
      final data = await lib.list(refresh: req.uri.queryParameters['refresh'] == '1');
      res.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      res.write(jsonEncode(data));
      return;
    }
    if (req.uri.path == '/__hub/music/file') {
      final path = req.uri.queryParameters['p'] ?? '';
      if (!lib.allows(path) || !File(path).existsSync()) {
        _notFound(res, path);
        return;
      }
      await _sendFile(req, File(path));
      return;
    }
    _notFound(res, req.uri.path);
  }

  void _notFound(HttpResponse res, String what) {
    res.statusCode = HttpStatus.notFound;
    res.headers.contentType = ContentType.html;
    res.write('<h1>404</h1><p>${_escape(what)} introuvable</p>');
  }

  Future<void> _sendFile(HttpRequest req, File file) async {
    final res = req.response;
    final length = await file.length();
    res.headers
      ..set(HttpHeaders.contentTypeHeader, contentTypeFor(file.path))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');

    final range = parseRange(req.headers.value(HttpHeaders.rangeHeader), length);
    if (range != null) {
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes ${range.$1}-${range.$2}/$length');
      res.contentLength = range.$2 - range.$1 + 1;
      if (req.method == 'GET') await res.addStream(file.openRead(range.$1, range.$2 + 1));
    } else {
      res.contentLength = length;
      if (req.method == 'GET') await res.addStream(file.openRead());
    }
  }

  /// Maps a URL path to a file under [root], or null. Directories resolve to
  /// their index.html; paths escaping [root] are rejected.
  static File? resolve(String root, String urlPath) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(urlPath);
    } catch (_) {
      return null;
    }
    final rel = decoded.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final full = p.normalize(p.join(root, rel));
    final normRoot = p.normalize(root);
    if (full != normRoot && !p.isWithin(normRoot, full)) return null;
    if (FileSystemEntity.isDirectorySync(full)) {
      for (final idx in const ['index.html', 'index.htm']) {
        final f = File(p.join(full, idx));
        if (f.existsSync()) return f;
      }
      return null;
    }
    final f = File(full);
    return f.existsSync() ? f : null;
  }

  /// Parses a single "bytes=a-b" range. Returns inclusive (start, end).
  static (int, int)? parseRange(String? header, int length) {
    if (header == null || length == 0) return null;
    final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (m == null) return null;
    final a = m.group(1)!, b = m.group(2)!;
    int start, end;
    if (a.isEmpty) {
      if (b.isEmpty) return null;
      final suffix = int.parse(b);
      start = (length - suffix).clamp(0, length - 1);
      end = length - 1;
    } else {
      start = int.parse(a);
      end = b.isEmpty ? length - 1 : int.parse(b).clamp(0, length - 1);
    }
    if (start > end || start >= length) return null;
    return (start, end);
  }

  static String contentTypeFor(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    return _mime[ext] ?? 'application/octet-stream';
  }

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static const _mime = {
    'html': 'text/html; charset=utf-8',
    'htm': 'text/html; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'map': 'application/json; charset=utf-8',
    'txt': 'text/plain; charset=utf-8',
    'md': 'text/plain; charset=utf-8',
    'csv': 'text/csv; charset=utf-8',
    'xml': 'application/xml',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'avif': 'image/avif',
    'ico': 'image/x-icon',
    'bmp': 'image/bmp',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'opus': 'audio/ogg',
    '3gp': 'audio/3gpp',
    'amr': 'audio/amr',
    'mka': 'audio/x-matroska',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'webm': 'video/webm',
    'ogv': 'video/ogg',
    'mov': 'video/quicktime',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'eot': 'application/vnd.ms-fontobject',
    'pdf': 'application/pdf',
    'wasm': 'application/wasm',
    'zip': 'application/zip',
    'webmanifest': 'application/manifest+json',
  };
}
