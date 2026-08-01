import 'exercise.dart';

class Lesson {
  final String id;
  final String title;
  final List<Exercise> exercises;

  const Lesson({
    required this.id,
    required this.title,
    required this.exercises,
  });

  /// Every vocabulary/grammar item this lesson teaches, used to feed the
  /// spaced-repetition review bank.
  List<Exercise> get vocabItems => exercises
      .where((e) => e.russian.isNotEmpty && e.french.isNotEmpty)
      .toList();
}
