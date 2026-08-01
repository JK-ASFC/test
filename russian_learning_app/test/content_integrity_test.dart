import 'package:flutter_test/flutter_test.dart';
import 'package:russian_learning_app/content/course_data.dart';
import 'package:russian_learning_app/models/exercise.dart';

/// These tests don't touch the widget tree or any platform channel - they
/// just walk every hand-authored exercise (A1 through C1) and check for the
/// kind of typos that are easy to make when writing hundreds of exercises
/// by hand: a correct answer that isn't among the options, a shuffled word
/// bank that doesn't contain the same words as the target sentence, etc.
void main() {
  test('every lesson has at least one exercise', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          expect(lesson.exercises, isNotEmpty, reason: '${lesson.id} has no exercises');
        }
      }
    }
  });

  test('exercise ids are globally unique', () {
    final seen = <String>{};
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            expect(seen.contains(e.id), isFalse, reason: 'Duplicate exercise id ${e.id}');
            seen.add(e.id);
          }
        }
      }
    }
  });

  test('lesson ids are globally unique', () {
    final seen = <String>{};
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          expect(seen.contains(lesson.id), isFalse, reason: 'Duplicate lesson id ${lesson.id}');
          seen.add(lesson.id);
        }
      }
    }
  });

  test('multiple choice / listening: correctOption is among options', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            if (e.type == ExerciseType.multipleChoice || e.type == ExerciseType.listening) {
              expect(e.options, isNotNull, reason: '${e.id} missing options');
              expect(e.correctOption, isNotNull, reason: '${e.id} missing correctOption');
              expect(e.options!.contains(e.correctOption), isTrue,
                  reason: '${e.id}: correctOption "${e.correctOption}" not in options ${e.options}');
              expect(e.options!.toSet().length, e.options!.length,
                  reason: '${e.id} has duplicate options');
            }
          }
        }
      }
    }
  });

  test('translate exercises have non-empty russian and french', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            if (e.type == ExerciseType.translate) {
              expect(e.russian.trim(), isNotEmpty, reason: '${e.id} empty russian');
              expect(e.french.trim(), isNotEmpty, reason: '${e.id} empty french');
            }
          }
        }
      }
    }
  });

  test('word bank tokens contain exactly the words of the correct order', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            if (e.type == ExerciseType.wordBank) {
              expect(e.wordBankTokens, isNotNull, reason: '${e.id} missing tokens');
              expect(e.wordBankCorrectOrder, isNotNull, reason: '${e.id} missing correct order');
              final tokensSorted = [...e.wordBankTokens!]..sort();
              final orderSorted = [...e.wordBankCorrectOrder!]..sort();
              expect(tokensSorted, orderSorted,
                  reason: '${e.id}: shuffled tokens ${e.wordBankTokens} do not match correct order ${e.wordBankCorrectOrder}');
            }
          }
        }
      }
    }
  });

  test('match pairs have at least 3 pairs and unique russian keys', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            if (e.type == ExerciseType.matchPairs) {
              expect(e.pairs, isNotNull, reason: '${e.id} missing pairs');
              expect(e.pairs!.length, greaterThanOrEqualTo(3), reason: '${e.id} too few pairs');
              final keys = e.pairs!.map((p) => p.key).toSet();
              expect(keys.length, e.pairs!.length, reason: '${e.id} has duplicate russian keys');
            }
          }
        }
      }
    }
  });

  test('flashcard and speaking exercises have russian and french text', () {
    for (final course in CourseData.levels) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          for (final e in lesson.exercises) {
            if (e.type == ExerciseType.flashcard || e.type == ExerciseType.speaking) {
              expect(e.russian.trim(), isNotEmpty, reason: '${e.id} empty russian');
              expect(e.french.trim(), isNotEmpty, reason: '${e.id} empty french');
            }
          }
        }
      }
    }
  });

  test('course has real content at every CEFR level', () {
    for (final course in CourseData.levels) {
      expect(course.units, isNotEmpty, reason: '${course.level} has no units');
      expect(course.lessonCount, greaterThan(0), reason: '${course.level} has no lessons');
    }
  });
}
