import '../models/course_level.dart';
import 'a1_content.dart';
import 'a2_content.dart';
import 'b1_content.dart';
import 'b2_content.dart';
import 'c1_content.dart';

/// The full course, all five CEFR levels. This is the single entry point
/// the rest of the app uses to read lesson content.
class CourseData {
  static final List<CourseLevel> levels = [
    CourseLevel(level: Cefr.a1, units: buildA1Units()),
    CourseLevel(level: Cefr.a2, units: buildA2Units()),
    CourseLevel(level: Cefr.b1, units: buildB1Units()),
    CourseLevel(level: Cefr.b2, units: buildB2Units()),
    CourseLevel(level: Cefr.c1, units: buildC1Units()),
  ];

  static CourseLevel forLevel(Cefr level) =>
      levels.firstWhere((c) => c.level == level);

  static int get totalLessonCount =>
      levels.fold(0, (sum, c) => sum + c.lessonCount);
}
