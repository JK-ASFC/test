import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';

/// Introduces a new word/phrase before it is tested. Always "succeeds" -
/// it exists purely to teach, not to quiz.
class FlashcardWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const FlashcardWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ProgressService.instance.soundEnabled) {
        TtsService.instance.speak(widget.exercise.russian, rate: ProgressService.instance.ttsRate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(e.prompt, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        Expanded(
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.russian,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    if (e.transliteration != null) ...[
                      const SizedBox(height: 6),
                      Text('[${e.transliteration}]',
                          style: const TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 10),
                    Text(e.french, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
                    if (e.example != null) ...[
                      const Divider(height: 32),
                      Text(e.example!, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                      if (e.exampleTranslation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(e.exampleTranslation!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                    ],
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () => TtsService.instance
                          .speak(e.russian, rate: ProgressService.instance.ttsRate),
                      icon: const Icon(Icons.volume_up),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => widget.onComplete(true),
            child: const Text('CONTINUER'),
          ),
        ),
      ],
    );
  }
}
