import 'package:flutter/foundation.dart';

import 'native_bridge.dart';
import 'web_session.dart';

/// Keeps the built-in music player alive when its screen is closed, so the
/// music goes on while browsing the hub, another project or another app
/// (like YouTube's background play). Only one at a time.
class BackgroundPlayer extends ChangeNotifier {
  BackgroundPlayer._() {
    // Media notification buttons -> page, whether or not its screen is open.
    NativeBridge.onMediaAction = (action, pos) {
      final s = session;
      if (s == null) return;
      if (action == 'stop') NativeBridge.mediaStop();
      s.mediaAction(action, pos);
    };
  }

  static final instance = BackgroundPlayer._();

  WebSession? _session;
  WebSession? get session => _session;

  /// True while the player's own screen is shown (the hub hides its mini bar).
  bool _screenOpen = false;
  bool get screenOpen => _screenOpen;
  set screenOpen(bool v) {
    if (v == _screenOpen) return;
    _screenOpen = v;
    notifyListeners();
  }

  /// Something to show in the hub's mini player.
  bool get showMiniPlayer => _session != null && !_screenOpen && _session!.nowPlaying.value != null;

  /// Makes [s] the background player (closing a previous one).
  Future<void> adopt(WebSession s) async {
    if (identical(s, _session)) return;
    await stop();
    _session = s;
    s.nowPlaying.addListener(notifyListeners);
    notifyListeners();
  }

  /// Called when the player's screen closes: keep it if music was started,
  /// otherwise free it.
  Future<void> screenClosed() async {
    _screenOpen = false;
    if (_session?.nowPlaying.value == null) {
      await stop();
    } else {
      notifyListeners();
    }
  }

  void action(String a) => _session?.mediaAction(a);

  Future<void> stop() async {
    final s = _session;
    if (s == null) return;
    _session = null;
    s.nowPlaying.removeListener(notifyListeners);
    notifyListeners();
    await s.close();
  }
}
