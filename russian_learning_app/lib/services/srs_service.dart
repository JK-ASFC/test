import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/lesson.dart';

/// One vocabulary item tracked for spaced repetition review, using a
/// simplified SM-2 algorithm (like Anki/Duolingo's "Practice" tab).
class SrsCard {
  final String key; // the Russian word/phrase, used as unique id
  final String russian;
  final String french;
  final DateTime due;
  final int interval; // days until next review
  final double ease;
  final int repetitions;

  const SrsCard({
    required this.key,
    required this.russian,
    required this.french,
    required this.due,
    required this.interval,
    required this.ease,
    required this.repetitions,
  });

  factory SrsCard.fromMap(String key, Map map) => SrsCard(
        key: key,
        russian: map['russian'] as String,
        french: map['french'] as String,
        due: DateTime.parse(map['due'] as String),
        interval: map['interval'] as int,
        ease: (map['ease'] as num).toDouble(),
        repetitions: map['repetitions'] as int,
      );

  Map<String, dynamic> toMap() => {
        'russian': russian,
        'french': french,
        'due': due.toIso8601String(),
        'interval': interval,
        'ease': ease,
        'repetitions': repetitions,
      };
}

class SrsService extends ChangeNotifier {
  SrsService._();
  static final SrsService instance = SrsService._();

  static const _boxName = 'ruspath_srs';
  late Box _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox(_boxName);
    _ready = true;
  }

  /// Registers every vocabulary item taught in [lesson] into the review
  /// bank the first time the lesson is completed (idempotent).
  Future<void> registerLessonVocab(Lesson lesson) async {
    for (final e in lesson.vocabItems) {
      final key = e.russian;
      if (_box.containsKey(key)) continue;
      final card = SrsCard(
        key: key,
        russian: e.russian,
        french: e.french,
        due: DateTime.now(),
        interval: 0,
        ease: 2.5,
        repetitions: 0,
      );
      await _box.put(key, card.toMap());
    }
    notifyListeners();
  }

  List<SrsCard> get allCards =>
      _box.keys.map((k) => SrsCard.fromMap(k as String, _box.get(k) as Map)).toList();

  List<SrsCard> dueCards({int limit = 20}) {
    final now = DateTime.now();
    final due = allCards.where((c) => !c.due.isAfter(now)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return due.take(limit).toList();
  }

  int get dueCount => dueCards(limit: 100000).length;
  int get totalCount => _box.length;

  /// Updates a card after the learner reviewed it. [quality] true = they
  /// got it right, false = they got it wrong.
  Future<void> review(String key, bool quality) async {
    if (!_box.containsKey(key)) return;
    final card = SrsCard.fromMap(key, _box.get(key) as Map);
    int newReps;
    int newInterval;
    double newEase;

    if (quality) {
      newReps = card.repetitions + 1;
      newEase = (card.ease + 0.1).clamp(1.3, 3.0);
      newInterval = switch (newReps) {
        1 => 1,
        2 => 6,
        _ => (card.interval * newEase).round().clamp(1, 365),
      };
    } else {
      newReps = 0;
      newEase = (card.ease - 0.2).clamp(1.3, 3.0);
      newInterval = 1;
    }

    final updated = SrsCard(
      key: key,
      russian: card.russian,
      french: card.french,
      due: DateTime.now().add(Duration(days: newInterval)),
      interval: newInterval,
      ease: newEase,
      repetitions: newReps,
    );
    await _box.put(key, updated.toMap());
    notifyListeners();
  }
}
