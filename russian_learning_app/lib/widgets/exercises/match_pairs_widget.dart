import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../feedback_banner.dart';

/// Tap a Russian word then its French translation to connect them all.
class MatchPairsWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const MatchPairsWidget({super.key, required this.exercise, required this.onComplete});

  @override
  State<MatchPairsWidget> createState() => _MatchPairsWidgetState();
}

class _MatchPairsWidgetState extends State<MatchPairsWidget> {
  late List<String> _left;
  late List<String> _right;
  final Set<String> _matchedLeft = {};
  final Set<String> _matchedRight = {};
  String? _selectedLeft;
  String? _selectedRight;
  int _mistakes = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final pairs = widget.exercise.pairs ?? [];
    _left = pairs.map((p) => p.key).toList()..shuffle(Random());
    _right = pairs.map((p) => p.value).toList()..shuffle(Random());
  }

  String? _frenchFor(String russian) =>
      widget.exercise.pairs!.firstWhere((p) => p.key == russian).value;

  void _tapLeft(String word) {
    if (_matchedLeft.contains(word) || _done) return;
    setState(() => _selectedLeft = word);
    _tryMatch();
  }

  void _tapRight(String word) {
    if (_matchedRight.contains(word) || _done) return;
    setState(() => _selectedRight = word);
    _tryMatch();
  }

  void _tryMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;
    final isMatch = _frenchFor(_selectedLeft!) == _selectedRight;
    if (isMatch) {
      _matchedLeft.add(_selectedLeft!);
      _matchedRight.add(_selectedRight!);
    } else {
      _mistakes++;
    }
    final matchedLeft = _selectedLeft;
    final matchedRight = _selectedRight;
    setState(() {
      _selectedLeft = null;
      _selectedRight = null;
    });
    if (!isMatch) {
      // Briefly flash both as wrong via a post-frame re-render.
      setState(() {
        _selectedLeft = matchedLeft;
        _selectedRight = matchedRight;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _selectedLeft = null;
            _selectedRight = null;
          });
        }
      });
    }
    if (_matchedLeft.length == _left.length) {
      setState(() => _done = true);
    }
  }

  Widget _tile(String text, {required bool matched, required bool selected, required VoidCallback onTap}) {
    Color? color;
    if (matched) {
      color = Colors.green;
    } else if (selected) {
      color = Colors.blue;
    }
    return GestureDetector(
      onTap: matched ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? Theme.of(context).colorScheme.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: matched ? Colors.green.withOpacity(0.1) : null,
        ),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(widget.exercise.prompt, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: _left
                      .map((w) => _tile(w,
                          matched: _matchedLeft.contains(w),
                          selected: _selectedLeft == w,
                          onTap: () => _tapLeft(w)))
                      .toList(),
                ),
              ),
              Expanded(
                child: Column(
                  children: _right
                      .map((w) => _tile(w,
                          matched: _matchedRight.contains(w),
                          selected: _selectedRight == w,
                          onTap: () => _tapRight(w)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        if (_done)
          FeedbackBanner(
            correct: _mistakes == 0,
            onContinue: () => widget.onComplete(_mistakes == 0),
          ),
      ],
    );
  }
}
