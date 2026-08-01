import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper around the device's built-in, free speech recognizer, used for
/// speaking/pronunciation exercises. The app never sends audio to a paid
/// third-party API - it relies entirely on the OS-level recognizer that
/// speech_to_text talks to (Android's on-device or Google app recognizer).
class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _available;
  }

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<void> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'ru-RU',
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 12),
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();

  /// A lightweight similarity score (0..1) between what was said and the
  /// expected Russian phrase, used to give encouraging feedback rather than
  /// a strict pass/fail (speech recognition of a foreign accent is noisy).
  static double similarity(String said, String expected) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^а-яa-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final a = norm(said).split(' ').where((w) => w.isNotEmpty).toSet();
    final b = norm(expected).split(' ').where((w) => w.isNotEmpty).toSet();
    if (b.isEmpty) return 0;
    final overlap = a.intersection(b).length;
    return (overlap / b.length).clamp(0.0, 1.0);
  }
}
