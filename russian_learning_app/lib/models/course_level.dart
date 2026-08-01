import 'package:flutter/material.dart';
import 'unit.dart';

/// The six CEFR levels the app covers, from complete beginner (A1) to
/// advanced / professional fluency (C1).
enum Cefr { a1, a2, b1, b2, c1 }

extension CefrLabel on Cefr {
  String get code => switch (this) {
        Cefr.a1 => 'A1',
        Cefr.a2 => 'A2',
        Cefr.b1 => 'B1',
        Cefr.b2 => 'B2',
        Cefr.c1 => 'C1',
      };

  String get title => switch (this) {
        Cefr.a1 => 'Débutant',
        Cefr.a2 => 'Élémentaire',
        Cefr.b1 => 'Intermédiaire',
        Cefr.b2 => 'Intermédiaire avancé',
        Cefr.c1 => 'Avancé / Professionnel',
      };

  Color get color => switch (this) {
        Cefr.a1 => const Color(0xFF58CC02),
        Cefr.a2 => const Color(0xFF1CB0F6),
        Cefr.b1 => const Color(0xFFFF9600),
        Cefr.b2 => const Color(0xFFCE82FF),
        Cefr.c1 => const Color(0xFFFF4B4B),
      };
}

class CourseLevel {
  final Cefr level;
  final List<LearningUnit> units;

  const CourseLevel({required this.level, required this.units});

  int get lessonCount => units.fold(0, (sum, u) => sum + u.lessons.length);
}
