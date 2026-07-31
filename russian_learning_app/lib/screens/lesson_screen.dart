import 'package:flutter/material.dart';
import '../models/course_level.dart';
import '../models/exercise.dart';
import '../models/lesson.dart';
import '../services/progress_service.dart';
import '../services/srs_service.dart';
import '../widgets/exercise_player.dart';
import 'lesson_summary_screen.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final Cefr level;

  const LessonScreen({super.key, required this.lesson, required this.level});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late int _index;
  int _correctCount = 0;
  final List<Exercise> _mistakes = [];
  final _stopwatch = Stopwatch()..start();

  static const _gradedTypes = {ExerciseType.multipleChoice, ExerciseType.listening, ExerciseType.translate};

  @override
  void initState() {
    super.initState();
    final saved = ProgressService.instance.getLessonProgress(widget.lesson.id);
    _index = (saved != null && saved < widget.lesson.exercises.length) ? saved : 0;
    SrsService.instance.registerLessonVocab(widget.lesson);
  }

  @override
  void dispose() {
    _stopwatch.stop();
    ProgressService.instance.recordStudySeconds(_stopwatch.elapsed.inSeconds);
    super.dispose();
  }

  void _handleComplete(bool correct) {
    final exercise = widget.lesson.exercises[_index];
    if (correct) {
      _correctCount++;
    } else {
      _mistakes.add(exercise);
    }
    if (_gradedTypes.contains(exercise.type) && exercise.russian.isNotEmpty) {
      SrsService.instance.review(exercise.russian, correct);
    }

    final next = _index + 1;
    if (next >= widget.lesson.exercises.length) {
      _finish();
    } else {
      setState(() => _index = next);
      ProgressService.instance.saveLessonProgress(widget.lesson.id, _index);
    }
  }

  Future<void> _finish() async {
    ProgressService.instance.recordStudySeconds(_stopwatch.elapsed.inSeconds);
    _stopwatch.reset();
    final xp = 10 + (_mistakes.isEmpty ? 5 : 0);
    await ProgressService.instance.completeLesson(widget.lesson.id, xpEarned: xp);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonSummaryScreen(
        lesson: widget.lesson,
        xpEarned: xp,
        mistakes: _mistakes,
        totalExercises: widget.lesson.exercises.length,
        correctCount: _correctCount,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.lesson.exercises.length;
    final exercise = widget.lesson.exercises[_index];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_index) / total,
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
                key: ValueKey('${exercise.id}_$_index'),
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
