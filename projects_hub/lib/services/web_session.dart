import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/project.dart';
import 'exports.dart';
import 'local_server.dart';
import 'native_bridge.dart';

/// What a built-in music app reports it is playing.
class NowPlaying {
  const NowPlaying({required this.title, required this.artist, required this.playing});
  final String title;
  final String artist;
  final bool playing;
}

/// A loaded web project, independent of the screen showing it: the
/// WebView, its local server and its bridge to Android live here, so a
/// music app can keep playing after its screen is closed.
class WebSession {
  WebSession({required this.project, required this.url, this.server}) {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => progress.value = p,
        onPageStarted: (_) => error.value = null,
        onPageFinished: (_) async => title.value = await controller.getTitle(),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) error.value = e.description;
        },
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          if (u != null && !const {'http', 'https', 'about', 'data', 'blob', 'file'}.contains(u.scheme)) {
            // mailto:, tel:, intent:... -> let Android handle it.
            NativeBridge.openUrl(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..setOnJavaScriptAlertDialog((r) => _alert(r.message))
      ..setOnJavaScriptConfirmDialog((r) => _confirm(r.message))
      ..setOnJavaScriptTextInputDialog((r) => _prompt(r.message, r.defaultText));

    if (project.type == SourceType.builtin) {
      // Lets built-in apps ask for things a web page can't do by itself.
      controller.addJavaScriptChannel('HubBridge', onMessageReceived: (m) => _onBridge(m.message));
    }

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setOnShowFileSelector(_pickFiles);
    }
    controller.loadRequest(Uri.parse(url));
  }

  final Project project;
  final String url;
  final LocalServer? server;
  late final WebViewController controller;

  final progress = ValueNotifier<int>(0);
  final title = ValueNotifier<String?>(null);
  final error = ValueNotifier<String?>(null);

  /// Set by built-in music apps; null until something has been played.
  final nowPlaying = ValueNotifier<NowPlaying?>(null);

  /// The screen currently showing this session, for JS dialogs. Null while
  /// the session runs in the background (dialogs are then answered "no").
  BuildContext? Function()? screenContext;

  bool _closed = false;

  void runJs(String js) {
    if (!_closed) controller.runJavaScript(js);
  }

  /// Button of the media notification / mini player -> page.
  void mediaAction(String action, [int positionMs = -1]) =>
      runJs('window.__hubMedia && window.__hubMedia(${jsonEncode(action)}, $positionMs)');

  /// Stops everything: page, sound, server, notification.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    nowPlaying.value = null;
    await controller.loadRequest(Uri.parse('about:blank'));
    if (project.type == SourceType.builtin && Platform.isAndroid) await NativeBridge.mediaStop();
    await server?.stop();
  }

  // ---------------------------------------------------------------- bridge

  /// Requests from built-in apps: {"type": "requestMusicPermission" | "openUrl" | "saveFile" | "media", ...}.
  Future<void> _onBridge(String raw) async {
    Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      msg = {'type': raw};
    }
    switch (msg['type']) {
      case 'requestMusicPermission':
        await NativeBridge.requestAllFilesAccess();
      case 'openUrl':
        final url = msg['url'];
        if (url is String && (url.startsWith('https://') || url.startsWith('http://'))) {
          await NativeBridge.openUrl(url);
        }
      case 'media':
        final title = '${msg['title'] ?? ''}';
        nowPlaying.value = title.isEmpty
            ? null
            : NowPlaying(title: title, artist: '${msg['artist'] ?? ''}', playing: msg['playing'] == true);
        if (!Platform.isAndroid) return;
        if (title.isEmpty) {
          await NativeBridge.mediaStop();
          return;
        }
        await NativeBridge.mediaUpdate(
          title: title,
          artist: '${msg['artist'] ?? ''}',
          playing: msg['playing'] == true,
          positionMs: (msg['position'] as num?)?.toInt() ?? 0,
          durationMs: (msg['duration'] as num?)?.toInt() ?? 0,
          hue: (msg['hue'] as num?)?.toInt() ?? 280,
        );
      case 'saveFile':
        try {
          final path = await saveExport('${msg['name'] ?? 'export.json'}', '${msg['content'] ?? ''}');
          _reply('Enregistré dans ${path.replaceFirst('/storage/emulated/0/', '')}');
        } catch (e) {
          _reply('Enregistrement impossible : autorise l\'accès aux fichiers ($e)');
        }
    }
  }

  void _reply(String text) => runJs('window.__hubReply && window.__hubReply(${jsonEncode({'text': text})})');

  // ---------------------------------------------------------------- dialogs

  BuildContext? get _ctx {
    final c = screenContext?.call();
    return c != null && c.mounted ? c : null;
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final types = params.acceptTypes.where((t) => t.isNotEmpty).join(',');
    final single = !types.contains(',');
    final type = types.startsWith('image/') && single
        ? FileType.image
        : types.startsWith('video/') && single
            ? FileType.video
            : types.startsWith('audio/') && single
                ? FileType.audio
                : FileType.any;
    final res = await FilePicker.pickFiles(type: type);
    final picked = params.mode == FileSelectorMode.openMultiple ? res : res.take(1);
    return picked.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList();
  }

  Future<void> _alert(String msg) async {
    final ctx = _ctx;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
      ),
    );
  }

  Future<bool> _confirm(String msg) async {
    final ctx = _ctx;
    if (ctx == null) return false;
    return await showDialog<bool>(
          context: ctx,
          builder: (d) => AlertDialog(
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
            ],
          ),
        ) ??
        false;
  }

  Future<String> _prompt(String msg, String? def) async {
    final ctx = _ctx;
    if (ctx == null) return def ?? '';
    final ctl = TextEditingController(text: def);
    final r = await showDialog<String>(
      context: ctx,
      builder: (d) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(msg),
          TextField(controller: ctl, autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, ctl.text), child: const Text('OK')),
        ],
      ),
    );
    return r ?? '';
  }
}
