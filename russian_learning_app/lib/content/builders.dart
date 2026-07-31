import '../models/exercise.dart';
import '../models/lesson.dart';

/// Compact helpers used by the lib/content/*.dart files so a whole exercise
/// fits on one line. Keeping content authoring terse makes it realistic to
/// hand-write hundreds of exercises and to extend the course later.

Exercise mc(
  String id,
  String prompt,
  String russian,
  String french,
  List<String> options,
  String correctOption, {
  String? transliteration,
}) {
  return Exercise(
    id: id,
    type: ExerciseType.multipleChoice,
    prompt: prompt,
    russian: russian,
    french: french,
    transliteration: transliteration,
    options: options,
    correctOption: correctOption,
  );
}

/// Listening exercise: the app speaks [russian] aloud (TTS) and the learner
/// picks its meaning among [options].
Exercise listen(
  String id,
  String russian,
  String french,
  List<String> options,
  String correctOption,
) {
  return Exercise(
    id: id,
    type: ExerciseType.listening,
    prompt: 'Écoute et choisis la bonne traduction',
    russian: russian,
    french: french,
    options: options,
    correctOption: correctOption,
  );
}

/// Typed translation. [answerInRussian] = true means the prompt is French
/// and the learner types the Russian; false is the reverse.
Exercise translate(
  String id,
  String russian,
  String french, {
  bool answerInRussian = true,
  List<String> acceptableAnswers = const [],
}) {
  return Exercise(
    id: id,
    type: ExerciseType.translate,
    prompt: answerInRussian ? 'Traduis en russe' : 'Traduis en français',
    russian: russian,
    french: french,
    answerInRussian: answerInRussian,
    acceptableAnswers: acceptableAnswers,
  );
}

Exercise wordBank(
  String id,
  String russian,
  String french,
  List<String> shuffledTokens,
  List<String> correctOrder,
) {
  return Exercise(
    id: id,
    type: ExerciseType.wordBank,
    prompt: 'Reconstitue la phrase en russe',
    russian: russian,
    french: french,
    wordBankTokens: shuffledTokens,
    wordBankCorrectOrder: correctOrder,
  );
}

Exercise matchPairs(String id, List<MapEntry<String, String>> pairs) {
  return Exercise(
    id: id,
    type: ExerciseType.matchPairs,
    prompt: 'Associe chaque mot russe à sa traduction',
    russian: '',
    french: '',
    pairs: pairs,
  );
}

Exercise speak(String id, String russian, String french) {
  return Exercise(
    id: id,
    type: ExerciseType.speaking,
    prompt: 'Prononce cette phrase à voix haute',
    russian: russian,
    french: french,
  );
}

Exercise flashcard(
  String id,
  String russian,
  String french, {
  String? transliteration,
  String? example,
  String? exampleTranslation,
}) {
  return Exercise(
    id: id,
    type: ExerciseType.flashcard,
    prompt: 'Nouveau mot',
    russian: russian,
    french: french,
    transliteration: transliteration,
    example: example,
    exampleTranslation: exampleTranslation,
  );
}

Lesson lesson(String id, String title, List<Exercise> exercises) {
  return Lesson(id: id, title: title, exercises: exercises);
}
