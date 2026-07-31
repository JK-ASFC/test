import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

class LessonSummaryScreen extends StatelessWidget {
  final Lesson lesson;
  final int xpEarned;
  final List<Exercise> mistakes;
  final int totalExercises;
  final int correctCount;

  const LessonSummaryScreen({
    super.key,
    required this.lesson,
    required this.xpEarned,
    required this.mistakes,
    required this.totalExercises,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = totalExercises == 0 ? 1.0 : correctCount / totalExercises;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.emoji_events, color: AppColors.warn, size: 96),
              const SizedBox(height: 16),
              Text('Leçon terminée !', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(lesson.title, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statCard(context, Icons.bolt, '+$xpEarned', 'XP', AppColors.warn),
                  _statCard(context, Icons.check_circle, '${(accuracy * 100).round()}%', 'Précision', AppColors.primary),
                ],
              ),
              if (mistakes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('À revoir', style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: mistakes
                        .map((e) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.replay, color: AppColors.danger),
                              title: Text(e.russian.isEmpty ? e.prompt : e.russian),
                              subtitle: e.french.isEmpty ? null : Text(e.french),
                            ))
                        .toList(),
                  ),
                ),
              ] else
                const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('CONTINUER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String value, String label, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
