import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/course_level.dart';

/// Single source of truth for everything that must survive an app restart:
/// completed lessons, in-progress lesson position (save & resume), XP,
/// streak, daily goal tracking and user settings.
///
/// Backed by a local Hive box only - no network, no account, no third-party
/// service. Everything stays on the device.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const _boxName = 'ruspath_box';
  late Box _box;
  bool _ready = false;
  bool get ready => _ready;

  final _dateFmt = DateFormat('yyyy-MM-dd');
  String _todayStr() => _dateFmt.format(DateTime.now());

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _rolloverDailyCountersIfNeeded();
    _ready = true;
    notifyListeners();
  }

  void _rolloverDailyCountersIfNeeded() {
    final today = _todayStr();
    final storedDay = _box.get('studySecondsDay') as String?;
    if (storedDay != today) {
      _box.put('studySecondsDay', today);
      _box.put('studySecondsToday', 0);
      _box.put('xpToday', 0);
    }
  }

  // ---------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------
  bool get onboardingDone => _box.get('onboardingDone', defaultValue: false);
  Future<void> completeOnboarding() async {
    await _box.put('onboardingDone', true);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Lesson completion & save/resume
  // ---------------------------------------------------------------------
  Set<String> get completedLessonIds => (_box.get('completedLessons', defaultValue: <String>[]) as List)
      .cast<String>()
      .toSet();

  bool isLessonCompleted(String lessonId) => completedLessonIds.contains(lessonId);

  /// Returns true if [lessonId] is the first lesson in [level], or the
  /// lesson immediately before it (within that level) is already completed.
  bool isLessonUnlocked(CourseLevel level, String lessonId) {
    final ids = level.units.expand((u) => u.lessons.map((l) => l.id)).toList();
    final idx = ids.indexOf(lessonId);
    if (idx <= 0) return true;
    return isLessonCompleted(ids[idx - 1]);
  }

  Future<void> completeLesson(String lessonId, {required int xpEarned}) async {
    final ids = completedLessonIds..add(lessonId);
    await _box.put('completedLessons', ids.toList());
    await clearLessonProgress(lessonId);
    await addXp(xpEarned);
    await _bumpStreak();
    notifyListeners();
  }

  /// Save which exercise the learner reached in a lesson so they can close
  /// the app and resume exactly where they left off.
  Future<void> saveLessonProgress(String lessonId, int exerciseIndex) async {
    final map = Map<String, dynamic>.from(_box.get('lessonProgress', defaultValue: <String, dynamic>{}));
    map[lessonId] = exerciseIndex;
    await _box.put('lessonProgress', map);
  }

  int? getLessonProgress(String lessonId) {
    final map = Map<String, dynamic>.from(_box.get('lessonProgress', defaultValue: <String, dynamic>{}));
    return map[lessonId] as int?;
  }

  Future<void> clearLessonProgress(String lessonId) async {
    final map = Map<String, dynamic>.from(_box.get('lessonProgress', defaultValue: <String, dynamic>{}));
    map.remove(lessonId);
    await _box.put('lessonProgress', map);
  }

  // ---------------------------------------------------------------------
  // XP, streak, daily goal
  // ---------------------------------------------------------------------
  int get xpTotal => _box.get('xpTotal', defaultValue: 0);
  int get xpToday {
    _rolloverDailyCountersIfNeeded();
    return _box.get('xpToday', defaultValue: 0);
  }

  Future<void> addXp(int amount) async {
    _rolloverDailyCountersIfNeeded();
    await _box.put('xpTotal', xpTotal + amount);
    await _box.put('xpToday', xpToday + amount);
    notifyListeners();
  }

  int get streak => _box.get('streak', defaultValue: 0);
  String? get lastStudyDate => _box.get('lastStudyDate') as String?;

  Future<void> _bumpStreak() async {
    final today = _todayStr();
    if (lastStudyDate == today) return;
    final yesterday = _dateFmt.format(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = (lastStudyDate == yesterday) ? streak + 1 : 1;
    await _box.put('streak', newStreak);
    await _box.put('lastStudyDate', today);
  }

  int get studySecondsToday {
    _rolloverDailyCountersIfNeeded();
    return _box.get('studySecondsToday', defaultValue: 0);
  }

  Future<void> recordStudySeconds(int seconds) async {
    _rolloverDailyCountersIfNeeded();
    await _box.put('studySecondsToday', studySecondsToday + seconds);
    notifyListeners();
  }

  int get dailyGoalMinutes => _box.get('dailyGoalMinutes', defaultValue: 10);
  Future<void> setDailyGoalMinutes(int minutes) async {
    await _box.put('dailyGoalMinutes', minutes);
    notifyListeners();
  }

  bool get dailyGoalMet => studySecondsToday >= dailyGoalMinutes * 60;
  double get dailyGoalProgress =>
      (studySecondsToday / (dailyGoalMinutes * 60)).clamp(0.0, 1.0);

  // ---------------------------------------------------------------------
  // Selected level & settings (fully personalisable)
  // ---------------------------------------------------------------------
  Cefr get selectedLevel {
    final code = _box.get('selectedLevel', defaultValue: 'a1') as String;
    return Cefr.values.firstWhere((c) => c.name == code, orElse: () => Cefr.a1);
  }

  Future<void> setSelectedLevel(Cefr level) async {
    await _box.put('selectedLevel', level.name);
    notifyListeners();
  }

  bool get soundEnabled => _box.get('soundEnabled', defaultValue: true);
  Future<void> setSoundEnabled(bool value) async {
    await _box.put('soundEnabled', value);
    notifyListeners();
  }

  double get ttsRate => _box.get('ttsRate', defaultValue: 0.42);
  Future<void> setTtsRate(double value) async {
    await _box.put('ttsRate', value);
    notifyListeners();
  }

  bool get notificationsEnabled => _box.get('notificationsEnabled', defaultValue: false);
  Future<void> setNotificationsEnabled(bool value) async {
    await _box.put('notificationsEnabled', value);
    notifyListeners();
  }

  TimeOfDay get reminderTime => TimeOfDay(
        hour: _box.get('reminderHour', defaultValue: 19),
        minute: _box.get('reminderMinute', defaultValue: 0),
      );

  Future<void> setReminderTime(TimeOfDay time) async {
    await _box.put('reminderHour', time.hour);
    await _box.put('reminderMinute', time.minute);
    notifyListeners();
  }

  ThemeMode get themeMode {
    final v = _box.get('themeMode', defaultValue: 'system');
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> resetAllProgress() async {
    await _box.clear();
    notifyListeners();
  }
}
