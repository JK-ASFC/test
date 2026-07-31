import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import '../../services/progress_service.dart';
import '../feedback_banner.dart';

/// Speaking exercise: the learner reads a Russian sentence aloud. Uses the
/// free on-device speech recognizer to give encouraging feedback. If the
/// microphone/recognizer is unavailable the learner can still mark it done.
class SpeakingWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const SpeakingWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<SpeakingWidget> createState() => _SpeakingWidgetState();
}

class _SpeakingWidgetState extends State<SpeakingWidget> {
  bool _listening = false;
  String _heard = '';
  double? _score;

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _heard = '';
      _score = null;
    });
    await SttService.instance.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() => _heard = words);
        if (isFinal) {
          final score = SttService.similarity(words, widget.exercise.russian);
          setState(() {
            _score = score;
            _listening = false;
          });
        }
      },
    );
    // Safety timeout in case the platform never reports isFinal.
    Future.delayed(const Duration(seconds: 13), () {
      if (mounted && _listening) {
        setState(() => _listening = false);
      }
    });
  }

  void _skip() {
    setState(() => _score = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final passed = (_score ?? 0) >= 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(e.prompt, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(e.russian, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(e.french, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        const SizedBox(height: 20),
        Center(
          child: IconButton(
            iconSize: 32,
            onPressed: () => TtsService.instance.speak(e.russian, rate: ProgressService.instance.ttsRate),
            icon: const Icon(Icons.volume_up),
          ),
        ),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: _listening ? null : _listen,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: _listening ? Colors.red : Theme.of(context).colorScheme.primary,
              child: Icon(_listening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_heard.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Toi : "$_heard"', textAlign: TextAlign.center),
          ),
        const SizedBox(height: 12),
        if (_score == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton(onPressed: _skip, child: const Text("Je n'ai pas de micro / passer")),
          ),
        const SizedBox(height: 12),
        if (_score != null)
          FeedbackBanner(
            correct: passed,
            correctAnswerText: passed ? null : e.russian,
            onContinue: () => widget.onComplete(true),
          ),
      ],
    );
  }
}
