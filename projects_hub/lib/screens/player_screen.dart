import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/project.dart';
import '../services/background_player.dart';
import '../services/native_bridge.dart';
import '../services/web_session.dart';

/// Shows a [WebSession] full screen. For the built-in music player the
/// session outlives this screen: closing it keeps the music playing in the
/// background (see [BackgroundPlayer]).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.session});

  final WebSession session;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  WebSession get _s => widget.session;
  WebViewController get _web => _s.controller;
  Project get _project => _s.project;
  late bool _immersive = _project.fullscreen;
  late final bool _background = _project.type == SourceType.builtin;

  @override
  void initState() {
    super.initState();
    _applySystemUi();
    _s.screenContext = () => mounted ? context : null;
    if (_background) BackgroundPlayer.instance.screenOpen = true;
  }

  void _applySystemUi() {
    SystemChrome.setPreferredOrientations(switch (_project.orientation) {
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
    _s.screenContext = null;
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Closes the screen and also stops the music.
  Future<void> _closeAndStop() async {
    if (_background) await BackgroundPlayer.instance.stop();
    if (mounted) Navigator.pop(context);
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
              _web.loadRequest(Uri.parse(_s.url));
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
          if (_project.type == SourceType.url)
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Ouvrir dans le navigateur'),
              onTap: () async {
                Navigator.pop(ctx);
                final u = await _web.currentUrl();
                NativeBridge.openUrl(u ?? _s.url);
              },
            ),
          if (_background) ...[
            ListTile(
              leading: const Icon(Icons.picture_in_picture_alt_outlined),
              title: const Text('Réduire (la musique continue)'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('Fermer et arrêter la musique'),
              onTap: () {
                Navigator.pop(ctx);
                _closeAndStop();
              },
            ),
          ] else
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
    final color = Color(_project.color);
    final body = Stack(children: [
      WebViewWidget(controller: _web),
      ValueListenableBuilder<int>(
        valueListenable: _s.progress,
        builder: (_, p, _) => p < 100
            ? Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(value: p / 100, color: color, minHeight: 3),
              )
            : const SizedBox.shrink(),
      ),
      ValueListenableBuilder<String?>(
        valueListenable: _s.error,
        builder: (_, err, _) => err == null
            ? const SizedBox.shrink()
            : Positioned.fill(
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
                        Text(err, textAlign: TextAlign.center),
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
                title: ValueListenableBuilder<String?>(
                  valueListenable: _s.title,
                  builder: (_, t, _) =>
                      Text(t?.isNotEmpty == true ? t! : _project.name, overflow: TextOverflow.ellipsis),
                ),
                leading: IconButton(
                  icon: Icon(_background ? Icons.keyboard_arrow_down : Icons.close),
                  tooltip: _background ? 'Réduire (la musique continue)' : 'Fermer',
                  onPressed: () => Navigator.pop(context),
                ),
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
