import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/project.dart';
import '../services/native_bridge.dart';

/// Shows a web project in a full-featured WebView.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.project, required this.url});

  final Project project;
  final String url;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _web;
  int _progress = 0;
  String? _title;
  String? _error;
  late bool _immersive = widget.project.fullscreen;

  @override
  void initState() {
    super.initState();
    _applySystemUi();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _error = null),
        onPageFinished: (_) async {
          final t = await _web.getTitle();
          if (mounted) setState(() => _title = t);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            setState(() => _error = e.description);
          }
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

    if (widget.project.type == SourceType.builtin) {
      // Lets built-in apps ask for things a web page can't do by itself.
      _web.addJavaScriptChannel('HubBridge', onMessageReceived: (m) {
        if (m.message == 'requestMusicPermission') NativeBridge.requestAllFilesAccess();
      });
    }

    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      platform
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setOnShowFileSelector(_pickFiles);
    }
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _applySystemUi() {
    SystemChrome.setPreferredOrientations(switch (widget.project.orientation) {
      PlayerOrientation.portrait => [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      PlayerOrientation.landscape => [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ],
      PlayerOrientation.auto => [],
    });
    SystemChrome.setEnabledSystemUIMode(
        _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final types = params.acceptTypes.where((t) => t.isNotEmpty).join(',');
    final type = types.startsWith('image/') && !types.contains(',')
        ? FileType.image
        : types.startsWith('video/') && !types.contains(',')
            ? FileType.video
            : types.startsWith('audio/') && !types.contains(',')
                ? FileType.audio
                : FileType.any;
    final res = await FilePicker.pickFiles(type: type);
    final picked = params.mode == FileSelectorMode.openMultiple ? res : res.take(1);
    return picked.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList();
  }

  Future<void> _alert(String msg) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<bool> _confirm(String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
          ],
        ),
      ) ??
      false;

  Future<String> _prompt(String msg, String? def) async {
    final ctl = TextEditingController(text: def);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(msg),
          TextField(controller: ctl, autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('OK')),
        ],
      ),
    );
    return r ?? '';
  }

  Future<void> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    _applySystemUi();
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Recharger'),
            onTap: () {
              Navigator.pop(ctx);
              _web.reload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Page d\'accueil du projet'),
            onTap: () {
              Navigator.pop(ctx);
              _web.loadRequest(Uri.parse(widget.url));
            },
          ),
          ListTile(
            leading: Icon(_immersive ? Icons.fullscreen_exit : Icons.fullscreen),
            title: Text(_immersive ? 'Quitter le plein écran' : 'Plein écran'),
            onTap: () {
              Navigator.pop(ctx);
              _toggleImmersive();
            },
          ),
          if (widget.project.type == SourceType.url)
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Ouvrir dans le navigateur'),
              onTap: () async {
                Navigator.pop(ctx);
                final u = await _web.currentUrl();
                NativeBridge.openUrl(u ?? widget.url);
              },
            ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Fermer le projet'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.project.color);
    final body = Stack(children: [
      WebViewWidget(controller: _web),
      if (_progress < 100)
        Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(value: _progress / 100, color: color, minHeight: 3),
        ),
      if (_error != null)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const SizedBox(height: 12),
                  Text('Impossible de charger la page', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _web.reload(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      if (_immersive)
        Positioned(
          right: 8,
          top: MediaQuery.paddingOf(context).top + 8,
          child: Opacity(
            opacity: 0.55,
            child: FloatingActionButton.small(
              heroTag: null,
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              onPressed: _showMenu,
              child: const Icon(Icons.more_vert),
            ),
          ),
        ),
    ]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _immersive
            ? null
            : AppBar(
                backgroundColor: color,
                foregroundColor:
                    ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black,
                title: Text(_title?.isNotEmpty == true ? _title! : widget.project.name,
                    overflow: TextOverflow.ellipsis),
                leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                actions: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack, tooltip: 'Page précédente'),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _web.reload(), tooltip: 'Recharger'),
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: _showMenu),
                ],
              ),
        body: _immersive ? body : SafeArea(top: false, child: body),
      ),
    );
  }
}
