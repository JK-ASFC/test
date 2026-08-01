import 'package:flutter/material.dart';
import '../models/unit.dart';
import 'builders.dart';

/// Niveau A2 - Élémentaire : passé, lieux (prépositionnel), datif, futur.
List<LearningUnit> buildA2Units() {
  return [
    LearningUnit(
      id: 'a2_u1',
      title: 'Le passé',
      description: 'Raconte ce que tu as fait hier',
      icon: Icons.history,
      lessons: [
        lesson('a2_u1_l1', 'Former le passé (-л / -ла / -ло / -ли)', [
          flashcard('a2_u1_l1_e1', 'был / была / было / были', "j'étais / j'étais (fém.) / c'était / ils étaient", example: 'Я была дома.', exampleTranslation: "J'étais à la maison."),
          flashcard('a2_u1_l1_e2', 'я работал / я работала', "j'ai travaillé (homme / femme)"),
          flashcard('a2_u1_l1_e3', 'я читал / я читала', "j'ai lu (homme / femme)"),
          mc('a2_u1_l1_e4', 'Une femme dit "j\'ai travaillé" :', 'Я работала.', "J'ai travaillé.", ['Я работал.', 'Я работала.', 'Я работать.'], 'Я работала.'),
          listen('a2_u1_l1_e5', 'Он читал книгу.', 'Il a lu un livre.', ['Il lit un livre.', 'Il a lu un livre.', 'Il va lire un livre.'], 'Il a lu un livre.'),
          translate('a2_u1_l1_e6', 'Я был дома.', "J'étais à la maison.", answerInRussian: false),
          wordBank('a2_u1_l1_e7', 'Вчера я работал.', "Hier j'ai travaillé.", ['я', 'работал.', 'Вчера'], ['Вчера', 'я', 'работал.']),
        ]),
        lesson('a2_u1_l2', 'Hier, la semaine dernière', [
          flashcard('a2_u1_l2_e1', 'вчера', 'hier'),
          flashcard('a2_u1_l2_e2', 'позавчера', "avant-hier"),
          flashcard('a2_u1_l2_e3', 'на прошлой неделе', 'la semaine dernière'),
          flashcard('a2_u1_l2_e4', 'Я ходил в кино.', 'Je suis allé au cinéma.'),
          mc('a2_u1_l2_e5', 'Que veut dire "на прошлой неделе" ?', 'на прошлой неделе', 'la semaine dernière', ['la semaine prochaine', 'la semaine dernière', 'hier'], 'la semaine dernière'),
          translate('a2_u1_l2_e6', 'Вчера я ходил в кино.', 'Hier je suis allé au cinéma.', answerInRussian: false),
          speak('a2_u1_l2_e7', 'На прошлой неделе я работал и читал.', "La semaine dernière j'ai travaillé et j'ai lu."),
        ]),
      ],
    ),
    LearningUnit(
      id: 'a2_u2',
      title: 'Où ? Le cas prépositionnel',
      description: 'Dis où tu es et demande ton chemin',
      icon: Icons.map,
      lessons: [
        lesson('a2_u2_l1', 'В / на + prépositionnel', [
          flashcard('a2_u2_l1_e1', 'в школе', "à l'école"),
          flashcard('a2_u2_l1_e2', 'на работе', 'au travail'),
          flashcard('a2_u2_l1_e3', 'в Москве', 'à Moscou'),
          flashcard('a2_u2_l1_e4', 'в России', 'en Russie'),
          mc('a2_u2_l1_e5', '"Au travail" se dit :', 'на работе', 'au travail', ['в работе', 'на работе', 'в работа'], 'на работе'),
          listen('a2_u2_l1_e6', 'Я живу в Москве.', 'Je vis à Moscou.', ['Je vis à Moscou.', 'Je travaille à Moscou.', 'Je vais à Moscou.'], 'Je vis à Moscou.'),
          translate('a2_u2_l1_e7', 'Я в школе.', "Je suis à l'école.", answerInRussian: false),
        ]),
        lesson('a2_u2_l2', 'Demander son chemin', [
          flashcard('a2_u2_l2_e1', 'Где находится...?', 'Où se trouve...?'),
          flashcard('a2_u2_l2_e2', 'налево, направо', 'à gauche, à droite'),
          flashcard('a2_u2_l2_e3', 'прямо', 'tout droit'),
          flashcard('a2_u2_l2_e4', 'близко, далеко', 'proche, loin'),
          mc('a2_u2_l2_e5', '"Tout droit" se dit :', 'прямо', 'tout droit', ['налево', 'направо', 'прямо'], 'прямо'),
          wordBank('a2_u2_l2_e6', 'Идите прямо, потом налево.', "Allez tout droit, puis à gauche.", ['потом', 'прямо,', 'налево.', 'Идите'], ['Идите', 'прямо,', 'потом', 'налево.']),
          speak('a2_u2_l2_e7', 'Где находится метро? Это далеко?', 'Où se trouve le métro ? C\'est loin ?'),
        ]),
      ],
    ),
    LearningUnit(
      id: 'a2_u3',
      title: 'Le datif : goûts et besoins',
      description: 'Exprime ce que tu aimes et ce dont tu as besoin',
      icon: Icons.favorite,
      lessons: [
        lesson('a2_u3_l1', 'Мне нравится...', [
          flashcard('a2_u3_l1_e1', 'мне, тебе, ему, ей', 'à moi, à toi, à lui, à elle'),
          flashcard('a2_u3_l1_e2', 'Мне нравится...', "J'aime bien... (litt. ça me plaît)", example: 'Мне нравится музыка.', exampleTranslation: "J'aime la musique."),
          flashcard('a2_u3_l1_e3', 'Ей нравится...', 'Elle aime bien...'),
          mc('a2_u3_l1_e4', '"Il aime bien" se dit :', 'Ему нравится', 'Il aime bien', ['Мне нравится', 'Ему нравится', 'Ей нравится'], 'Ему нравится'),
          translate('a2_u3_l1_e5', 'Мне нравится Россия.', "J'aime bien la Russie.", answerInRussian: false),
          listen('a2_u3_l1_e6', 'Ей нравится читать.', 'Elle aime lire.', ['Elle aime lire.', 'Il aime lire.', 'Ils aiment lire.'], 'Elle aime lire.'),
        ]),
        lesson('a2_u3_l2', "L'âge et le besoin", [
          flashcard('a2_u3_l2_e1', 'Мне нужно / нужен / нужна', "J'ai besoin de..."),
          flashcard('a2_u3_l2_e2', 'Сколько тебе лет?', 'Quel âge as-tu ?'),
          flashcard('a2_u3_l2_e3', 'Мне 20 лет.', "J'ai 20 ans."),
          mc('a2_u3_l2_e4', '"J\'ai 20 ans" se dit :', 'Мне 20 лет.', "J'ai 20 ans.", ['Я 20 лет.', 'Мне 20 лет.', 'У меня 20 лет.'], 'Мне 20 лет.'),
          translate('a2_u3_l2_e5', 'Сколько тебе лет?', 'Quel âge as-tu ?', answerInRussian: false),
          speak('a2_u3_l2_e6', 'Мне 25 лет, и мне нужна вода.', "J'ai 25 ans, et j'ai besoin d'eau."),
        ]),
      ],
    ),
    LearningUnit(
      id: 'a2_u4',
      title: 'Le futur et les projets',
      description: 'Parle de tes projets et de demain',
      icon: Icons.event,
      lessons: [
        lesson('a2_u4_l1', 'Le futur avec быть', [
          flashcard('a2_u4_l1_e1', 'я буду делать', 'je vais faire / je ferai'),
          flashcard('a2_u4_l1_e2', 'ты будешь читать', 'tu vas lire / tu liras'),
          flashcard('a2_u4_l1_e3', 'завтра', 'demain'),
          mc('a2_u4_l1_e4', '"Je vais lire" se dit :', 'Я буду читать.', 'Je vais lire.', ['Я читал.', 'Я буду читать.', 'Я читаю.'], 'Я буду читать.'),
          translate('a2_u4_l1_e5', 'Завтра я буду работать.', 'Demain je vais travailler.', answerInRussian: false),
          wordBank('a2_u4_l1_e6', 'Что ты будешь делать завтра?', 'Que vas-tu faire demain?', ['завтра?', 'ты', 'будешь', 'делать', 'Что'], ['Что', 'ты', 'будешь', 'делать', 'завтра?']),
        ]),
        lesson('a2_u4_l2', 'Faire des projets', [
          flashcard('a2_u4_l2_e1', 'в следующем году', "l'année prochaine"),
          flashcard('a2_u4_l2_e2', 'на следующей неделе', 'la semaine prochaine'),
          flashcard('a2_u4_l2_e3', 'Я планирую...', 'Je prévois de...'),
          mc('a2_u4_l2_e4', '"L\'année prochaine" se dit :', 'в следующем году', "l'année prochaine", ['в прошлом году', 'в следующем году', 'на следующей неделе'], 'в следующем году'),
          translate('a2_u4_l2_e5', 'Я планирую поехать в Россию.', 'Je prévois de partir en Russie.', answerInRussian: false),
          speak('a2_u4_l2_e6', 'В следующем году я буду учить русский язык.', "L'année prochaine j'apprendrai le russe."),
        ]),
      ],
    ),
  ];
}
