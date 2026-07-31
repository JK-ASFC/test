import 'package:flutter/material.dart';

enum LessonState { locked, available, completed }

class LessonNode extends StatelessWidget {
  final String title;
  final LessonState state;
  final Color color;
  final Alignment align;
  final VoidCallback? onTap;

  const LessonNode({
    super.key,
    required this.title,
    required this.state,
    required this.color,
    required this.align,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = state == LessonState.locked;
    final completed = state == LessonState.completed;
    final bgColor = locked ? Theme.of(context).colorScheme.outlineVariant : color;

    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        child: Column(
          children: [
            GestureDetector(
              onTap: locked ? null : onTap,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  boxShadow: locked
                      ? []
                      : [BoxShadow(color: bgColor.withOpacity(0.5), blurRadius: 0, offset: const Offset(0, 4))],
                ),
                child: Icon(
                  completed ? Icons.check : (locked ? Icons.lock : Icons.star),
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 90,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
