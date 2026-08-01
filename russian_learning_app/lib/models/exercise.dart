/// The different exercise interactions the lesson runner knows how to play.
enum ExerciseType {
  multipleChoice,
  listening,
  translate,
  wordBank,
  matchPairs,
  speaking,
  flashcard,
}

/// A single learning card / question inside a [Lesson].
///
/// Not every field is used by every [ExerciseType] - see the widget for each
/// type under lib/widgets/exercises/ for which fields it reads.
class Exercise {
  final String id;
  final ExerciseType type;

  /// Instruction shown above the exercise, e.g. "Traduis en russe".
  final String prompt;

  /// The Russian word/sentence at the heart of the exercise (spoken by TTS,
  /// shown as the answer, etc).
  final String russian;

  /// The French meaning of [russian].
  final String french;

  /// Optional transliteration (Latin letters), mostly used in the very first
  /// alphabet unit to bridge the reader into Cyrillic.
  final String? transliteration;

  /// Multiple choice / listening: the options shown to the user.
  final List<String>? options;

  /// Multiple choice / listening: the option that is correct (must be a
  /// member of [options]).
  final String? correctOption;

  /// Translate exercises: extra spellings/synonyms accepted besides
  /// [russian] or [french] (already normalised versions are computed at
  /// runtime, this is for genuine alternative wordings).
  final List<String> acceptableAnswers;

  /// Translate exercises: true if the user must type the Russian answer,
  /// false if they type the French translation of a Russian sentence.
  final bool answerInRussian;

  /// Word bank: shuffled tokens the learner taps in order.
  final List<String>? wordBankTokens;

  /// Word bank: the correct order of tokens.
  final List<String>? wordBankCorrectOrder;

  /// Match pairs: list of (russian, french) pairs to connect.
  final List<MapEntry<String, String>>? pairs;

  /// Extra example sentence shown on flashcards for context.
  final String? example;
  final String? exampleTranslation;

  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.russian,
    required this.french,
    this.transliteration,
    this.options,
    this.correctOption,
    this.acceptableAnswers = const [],
    this.answerInRussian = true,
    this.wordBankTokens,
    this.wordBankCorrectOrder,
    this.pairs,
    this.example,
    this.exampleTranslation,
  });
}
