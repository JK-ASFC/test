import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../feedback_banner.dart';

/// Handles both [ExerciseType.multipleChoice] and [ExerciseType.listening].
/// For listening exercises the Russian text is hidden until after answering
/// - the learner must rely on the spoken audio.
class MultipleChoiceWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const MultipleChoiceWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<MultipleChoiceWidget> createState() => _MultipleChoiceWidgetState();
}

class _MultipleChoiceWidgetState extends State<MultipleChoiceWidget> {
  String? _selected;
  bool? _correct;

  bool get _isListening => widget.exercise.type == ExerciseType.listening;

  @override
  void initState() {
    super.initState();
    if (_isListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
    }
  }

  void _speak() {
    if (ProgressService.instance.soundEnabled) {
      TtsService.instance.speak(widget.exercise.russian, rate: ProgressService.instance.ttsRate);
    }
  }

  void _submit(String option) {
    if (_selected != null) return;
    setState(() {
      _selected = option;
      _correct = option == widget.exercise.correctOption;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(e.prompt, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _isListening
              ? Center(
                  child: IconButton.filled(
                    iconSize: 40,
                    padding: const EdgeInsets.all(20),
                    onPressed: _speak,
                    icon: const Icon(Icons.volume_up),
                  ),
                )
              : Text(e.russian, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: (e.options ?? []).map((opt) {
              final isSelected = _selected == opt;
              final isCorrectOpt = opt == e.correctOption;
              Color? color;
              if (_selected != null) {
                if (isCorrectOpt) {
                  color = Colors.green;
                } else if (isSelected) {
                  color = Colors.red;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _selected == null ? () => _submit(opt) : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color ?? Theme.of(context).colorScheme.outlineVariant, width: 2),
                    backgroundColor: color?.withValues(alpha: 0.1),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(opt, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        ),
        if (_correct != null)
          FeedbackBanner(
            correct: _correct!,
            correctAnswerText: e.correctOption,
            onContinue: () => widget.onComplete(_correct!),
          ),
      ],
    );
  }
}
