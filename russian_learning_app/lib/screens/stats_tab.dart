import 'package:flutter/material.dart';
import '../content/course_data.dart';
import '../models/course_level.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Progression')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final goalMinutes = progress.dailyGoalMinutes;
          final doneMinutes = (progress.studySecondsToday / 60).clamp(0, goalMinutes.toDouble());
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: _bigStat(context, Icons.local_fire_department, '${progress.streak}', 'jours de série', Colors.deepOrange)),
                  const SizedBox(width: 12),
                  Expanded(child: _bigStat(context, Icons.bolt, '${progress.xpTotal}', 'XP total', Colors.amber)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Objectif du jour', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.dailyGoalProgress,
                        minHeight: 14,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                        color: progress.dailyGoalMet ? AppColors.primary : AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${doneMinutes.round()} / $goalMinutes minutes aujourd\'hui'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Par niveau', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final level in Cefr.values) _levelProgressRow(context, level, progress),
            ],
          );
        },
      ),
    );
  }

  Widget _bigStat(BuildContext context, IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _levelProgressRow(BuildContext context, Cefr level, ProgressService progress) {
    final course = CourseData.forLevel(level);
    final completed = course.units.expand((u) => u.lessons).where((l) => progress.isLessonCompleted(l.id)).length;
    final total = course.lessonCount;
    final ratio = total == 0 ? 0.0 : completed / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: level.color, radius: 18, child: Text(level.code, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                    color: level.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$completed/$total'),
        ],
      ),
    );
  }
}
