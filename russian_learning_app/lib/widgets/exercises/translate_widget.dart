import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../feedback_banner.dart';

/// Typed translation exercise. Answer checking is lenient: case-insensitive,
/// punctuation-insensitive, and accepts ё/е interchangeably plus any
/// [Exercise.acceptableAnswers].
class TranslateWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const TranslateWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<TranslateWidget> createState() => _TranslateWidgetState();
}

class _TranslateWidgetState extends State<TranslateWidget> {
  final _controller = TextEditingController();
  bool? _correct;

  String _normalize(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[.!?,;:]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  String get _expected => widget.exercise.answerInRussian ? widget.exercise.russian : widget.exercise.french;

  void _submit() {
    if (_correct != null) return;
    final userAnswer = _normalize(_controller.text);
    final accepted = {_expected, ...widget.exercise.acceptableAnswers}.map(_normalize);
    setState(() => _correct = accepted.contains(userAnswer));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final source = e.answerInRussian ? e.french : e.russian;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(e.prompt, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(source, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: _controller,
            enabled: _correct == null,
            autofocus: true,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              hintText: 'Écris ta réponse...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_correct == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(onPressed: _submit, child: const Text('VÉRIFIER')),
          ),
        const Spacer(),
        if (_correct != null)
          FeedbackBanner(
            correct: _correct!,
            correctAnswerText: _expected,
            onContinue: () => widget.onComplete(_correct!),
          ),
      ],
    );
  }
}
