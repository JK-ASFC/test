import 'package:flutter/material.dart';
import '../content/course_data.dart';
import '../models/course_level.dart';
import '../services/progress_service.dart';
import '../widgets/lesson_node.dart';
import 'lesson_screen.dart';

class LearnTab extends StatefulWidget {
  const LearnTab({super.key});

  @override
  State<LearnTab> createState() => _LearnTabState();
}

class _LearnTabState extends State<LearnTab> {
  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    final level = progress.selectedLevel;
    final course = CourseData.forLevel(level);
    final completed = course.units.expand((u) => u.lessons).where((l) => progress.isLessonCompleted(l.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.deepOrange),
            const SizedBox(width: 4),
            Text('${progress.streak}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            const Icon(Icons.bolt, color: Colors.amber),
            const SizedBox(width: 4),
            Text('${progress.xpTotal} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          _levelSelector(level),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text('${level.code} · ${level.title}', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('$completed/${course.lessonCount} leçons', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: course.units.length,
              itemBuilder: (context, unitIndex) {
                final unit = course.units[unitIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: level.color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(unit.icon, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(unit.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(unit.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < unit.lessons.length; i++)
                      AnimatedBuilder(
                        animation: progress,
                        builder: (context, _) {
                          final lesson = unit.lessons[i];
                          final isDone = progress.isLessonCompleted(lesson.id);
                          final isUnlocked = progress.isLessonUnlocked(course, lesson.id);
                          final state = isDone
                              ? LessonState.completed
                              : (isUnlocked ? LessonState.available : LessonState.locked);
                          final align = i.isEven ? Alignment.center : (i % 4 == 1 ? const Alignment(0.5, 0) : const Alignment(-0.5, 0));
                          return LessonNode(
                            title: lesson.title,
                            state: state,
                            color: level.color,
                            align: align,
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => LessonScreen(lesson: lesson, level: level),
                              ));
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelSelector(Cefr selected) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: Cefr.values.map((c) {
          final isSelected = c == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(c.code),
              selected: isSelected,
              selectedColor: c.color,
              labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold),
              onSelected: (_) {
                ProgressService.instance.setSelectedLevel(c);
                setState(() {});
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
