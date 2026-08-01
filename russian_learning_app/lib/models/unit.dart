import 'package:flutter/material.dart';
import 'lesson.dart';

class LearningUnit {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<Lesson> lessons;

  const LearningUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.lessons,
  });
}
