import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../feedback_banner.dart';

/// The learner taps shuffled Russian words in order to reconstruct the
/// sentence shown in French.
class WordBankWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const WordBankWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<WordBankWidget> createState() => _WordBankWidgetState();
}

class _WordBankWidgetState extends State<WordBankWidget> {
  late List<String> _available;
  final List<String> _chosen = [];
  bool? _correct;

  @override
  void initState() {
    super.initState();
    _available = List.from(widget.exercise.wordBankTokens ?? []);
  }

  void _choose(int index) {
    if (_correct != null) return;
    setState(() {
      _chosen.add(_available.removeAt(index));
    });
  }

  void _unchoose(int index) {
    if (_correct != null) return;
    setState(() {
      _available.add(_chosen.removeAt(index));
    });
  }

  void _submit() {
    if (_correct != null || _chosen.isEmpty) return;
    final target = widget.exercise.wordBankCorrectOrder ?? [];
    final ok = _chosen.length == target.length &&
        List.generate(target.length, (i) => _chosen[i] == target[i]).every((x) => x);
    setState(() => _correct = ok);
  }

  Widget _chip(String text, VoidCallback? onTap) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 16)),
      onPressed: onTap,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
      ),
    );
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
          child: Text(e.french, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 60),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _chosen.length; i++) _chip(_chosen[i], () => _unchoose(i)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _available.length; i++) _chip(_available[i], () => _choose(i)),
            ],
          ),
        ),
        const Spacer(),
        if (_correct == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _chosen.isEmpty ? null : _submit,
              child: const Text('VÉRIFIER'),
            ),
          ),
        if (_correct != null)
          FeedbackBanner(
            correct: _correct!,
            correctAnswerText: (widget.exercise.wordBankCorrectOrder ?? []).join(' '),
            onContinue: () => widget.onComplete(_correct!),
          ),
      ],
    );
  }
}
