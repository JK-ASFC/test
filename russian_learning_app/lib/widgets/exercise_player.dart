import 'package:flutter/material.dart';
import '../models/exercise.dart';
import 'exercises/multiple_choice_widget.dart';
import 'exercises/translate_widget.dart';
import 'exercises/word_bank_widget.dart';
import 'exercises/match_pairs_widget.dart';
import 'exercises/speaking_widget.dart';
import 'exercises/flashcard_widget.dart';

/// Dispatches to the right exercise widget for [exercise.type].
class ExercisePlayer extends StatelessWidget {
  final Exercise exercise;
  final void Function(bool correct) onComplete;

  const ExercisePlayer({super.key, required this.exercise, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    switch (exercise.type) {
      case ExerciseType.multipleChoice:
      case ExerciseType.listening:
        return MultipleChoiceWidget(exercise: exercise, onComplete: onComplete);
      case ExerciseType.translate:
        return TranslateWidget(exercise: exercise, onComplete: onComplete);
      case ExerciseType.wordBank:
        return WordBankWidget(exercise: exercise, onComplete: onComplete);
      case ExerciseType.matchPairs:
        return MatchPairsWidget(exercise: exercise, onComplete: onComplete);
      case ExerciseType.speaking:
        return SpeakingWidget(exercise: exercise, onComplete: onComplete);
      case ExerciseType.flashcard:
        return FlashcardWidget(exercise: exercise, onComplete: onComplete);
    }
  }
}
