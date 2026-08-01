import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/srs_service.dart';
import '../widgets/exercise_player.dart';

/// A short spaced-repetition review session over vocabulary due for
/// practice today, mixing translation direction so it's not too easy.
class ReviewScreen extends StatefulWidget {
  final List<SrsCard> cards;

  const ReviewScreen({super.key, required this.cards});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<Exercise> _exercises;
  late final List<String> _keys;
  int _index = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _exercises = widget.cards.map((c) {
      final toRussian = rnd.nextBool();
      return Exercise(
        id: c.key,
        type: ExerciseType.translate,
        prompt: toRussian ? 'Traduis en russe' : 'Traduis en français',
        russian: c.russian,
        french: c.french,
        answerInRussian: toRussian,
      );
    }).toList();
    _keys = widget.cards.map((c) => c.key).toList();
  }

  void _handleComplete(bool correct) {
    SrsService.instance.review(_keys[_index], correct);
    if (correct) _correct++;
    final next = _index + 1;
    if (next >= _exercises.length) {
      _finish();
    } else {
      setState(() => _index = next);
    }
  }

  void _finish() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Révision terminée !'),
        content: Text('$_correct / ${_exercises.length} bonnes réponses.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Révision')),
        body: const Center(child: Text('Rien à réviser pour le moment !')),
      );
    }
    final exercise = _exercises[_index];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _index / _exercises.length,
                        minHeight: 10,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ExercisePlayer(
                key: ValueKey('review_${exercise.id}_$_index'),
                exercise: exercise,
                onComplete: _handleComplete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
