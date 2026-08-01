import 'package:flutter/material.dart';
import '../models/unit.dart';
import 'builders.dart';

/// Niveau B1 - Intermédiaire : aspects des verbes, comparaisons et opinions,
/// instrumental et métiers.
List<LearningUnit> buildB1Units() {
  return [
    LearningUnit(
      id: 'b1_u1',
      title: "L'aspect des verbes",
      description: 'Imperfectif vs perfectif : la clé du russe',
      icon: Icons.sync_alt,
      lessons: [
        lesson('b1_u1_l1', 'Imperfectif ou perfectif ?', [
          flashcard('b1_u1_l1_e1', 'делать / сделать', 'faire (en cours) / faire (fini)', example: 'Я делал домашнее задание.', exampleTranslation: 'Je faisais mes devoirs (processus).'),
          flashcard('b1_u1_l1_e2', 'читать / прочитать', 'lire / avoir fini de lire'),
          flashcard('b1_u1_l1_e3', 'писать / написать', 'écrire / avoir fini d\'écrire'),
          mc('b1_u1_l1_e4', '"J\'ai fini de lire le livre" (résultat) :', 'Я прочитал книгу.', "J'ai fini de lire le livre.", ['Я читал книгу.', 'Я прочитал книгу.', 'Я читаю книгу.'], 'Я прочитал книгу.'),
          listen('b1_u1_l1_e5', 'Я писал письмо два часа.', "J'écrivais une lettre pendant deux heures.", ["J'écrivais une lettre pendant deux heures.", "J'ai écrit une lettre en deux heures.", "J'écrirai une lettre."], "J'écrivais une lettre pendant deux heures."),
          translate('b1_u1_l1_e6', 'Я сделал домашнее задание.', "J'ai fini mes devoirs.", answerInRussian: false),
        ]),
        lesson('b1_u1_l2', "Aspect au futur et à l'impératif", [
          flashcard('b1_u1_l2_e1', 'я сделаю', 'je ferai (et ce sera fini)'),
          flashcard('b1_u1_l2_e2', 'я буду делать', 'je ferai (processus, en cours)'),
          flashcard('b1_u1_l2_e3', 'Сделай это!', 'Fais ça (maintenant, jusqu\'au bout) !'),
          mc('b1_u1_l2_e4', '"Je vais lire ce livre en entier ce soir" :', 'Я прочитаю эту книгу вечером.', 'Je vais lire ce livre en entier ce soir.', ['Я буду читать эту книгу вечером.', 'Я прочитаю эту книгу вечером.', 'Я читал эту книгу вечером.'], 'Я прочитаю эту книгу вечером.'),
          translate('b1_u1_l2_e5', 'Я сделаю это завтра.', "Je le ferai (jusqu'au bout) demain.", answerInRussian: false),
          speak('b1_u1_l2_e6', 'Завтра я прочитаю эту книгу и напишу письмо.', 'Demain je finirai de lire ce livre et j\'écrirai une lettre.'),
        ]),
      ],
    ),
    LearningUnit(
      id: 'b1_u2',
      title: 'Comparaisons et opinions',
      description: 'Compare et donne ton avis',
      icon: Icons.compare_arrows,
      lessons: [
        lesson('b1_u2_l1', 'Le comparatif', [
          flashcard('b1_u2_l1_e1', 'больше / меньше', 'plus / moins'),
          flashcard('b1_u2_l1_e2', 'лучше / хуже', 'mieux / pire'),
          flashcard('b1_u2_l1_e3', 'быстрее / медленнее', 'plus rapide / plus lent'),
          mc('b1_u2_l1_e4', '"Mieux" se dit :', 'лучше', 'mieux', ['хуже', 'лучше', 'больше'], 'лучше'),
          translate('b1_u2_l1_e5', 'Этот фильм лучше, чем тот.', 'Ce film est mieux que celui-là.', answerInRussian: false),
          wordBank('b1_u2_l1_e6', 'Русский язык труднее, чем английский.', 'Le russe est plus difficile que l\'anglais.', ['чем', 'труднее,', 'английский.', 'Русский', 'язык'], ['Русский', 'язык', 'труднее,', 'чем', 'английский.']),
        ]),
        lesson('b1_u2_l2', 'Donner son opinion', [
          flashcard('b1_u2_l2_e1', 'По-моему...', 'À mon avis...'),
          flashcard('b1_u2_l2_e2', 'Я думаю, что...', 'Je pense que...'),
          flashcard('b1_u2_l2_e3', 'Я согласен / согласна', "Je suis d'accord (homme / femme)"),
          flashcard('b1_u2_l2_e4', 'Я не согласен / не согласна', "Je ne suis pas d'accord"),
          mc('b1_u2_l2_e5', '"Je pense que" se dit :', 'Я думаю, что', 'Je pense que', ['По-моему', 'Я думаю, что', 'Я согласен'], 'Я думаю, что'),
          translate('b1_u2_l2_e6', 'По-моему, это интересно.', "À mon avis, c'est intéressant.", answerInRussian: false),
          speak('b1_u2_l2_e7', 'Я думаю, что русский язык очень интересный, но трудный.', 'Je pense que le russe est très intéressant, mais difficile.'),
        ]),
      ],
    ),
    LearningUnit(
      id: 'b1_u3',
      title: "L'instrumental et les métiers",
      description: 'Parle de ta profession et de tes outils',
      icon: Icons.work,
      lessons: [
        lesson('b1_u3_l1', 'Métiers et "работать + instrumental"', [
          flashcard('b1_u3_l1_e1', 'врач, инженер', 'médecin, ingénieur'),
          flashcard('b1_u3_l1_e2', 'учитель, юрист', 'enseignant, avocat'),
          flashcard('b1_u3_l1_e3', 'Я работаю врачом.', 'Je travaille comme médecin.', example: 'Она работает учителем.', exampleTranslation: 'Elle travaille comme enseignante.'),
          mc('b1_u3_l1_e4', '"Je travaille comme ingénieur" :', 'Я работаю инженером.', 'Je travaille comme ingénieur.', ['Я работаю инженер.', 'Я работаю инженером.', 'Я инженер работаю.'], 'Я работаю инженером.'),
          translate('b1_u3_l1_e5', 'Он работает врачом.', 'Il travaille comme médecin.', answerInRussian: false),
          listen('b1_u3_l1_e6', 'Я работаю юристом.', "Je travaille comme avocat.", ["Je travaille comme avocat.", "Je travaille comme enseignant.", "Je travaille comme médecin."], "Je travaille comme avocat."),
        ]),
        lesson('b1_u3_l2', 'Avec qui, avec quoi (instrumental)', [
          flashcard('b1_u3_l2_e1', 'с другом, с семьёй', 'avec un ami, avec la famille'),
          flashcard('b1_u3_l2_e2', 'ручкой, ножом', 'avec un stylo, avec un couteau'),
          flashcard('b1_u3_l2_e3', 'Я пишу ручкой.', "J'écris avec un stylo."),
          mc('b1_u3_l2_e4', '"Avec un ami" se dit :', 'с другом', 'avec un ami', ['друг', 'с другом', 'другом'], 'с другом'),
          translate('b1_u3_l2_e5', 'Я иду в кино с семьёй.', 'Je vais au cinéma avec ma famille.', answerInRussian: false),
          speak('b1_u3_l2_e6', 'Я работаю инженером и часто хожу на работу с другом.', "Je travaille comme ingénieur et je vais souvent au travail avec un ami."),
        ]),
      ],
    ),
  ];
}
