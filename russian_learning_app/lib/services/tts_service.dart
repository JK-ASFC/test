import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the device's built-in text-to-speech engine, used to
/// read Russian words and sentences aloud for listening/pronunciation
/// exercises. Free and works fully offline once the device's Russian voice
/// is installed (Android downloads it automatically the first time it is
/// requested, via the system Text-to-speech settings).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured(double rate) async {
    if (_configured) return;
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(rate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  Future<void> speak(String text, {double rate = 0.42}) async {
    if (text.trim().isEmpty) return;
    await _ensureConfigured(rate);
    await _tts.setSpeechRate(rate);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
