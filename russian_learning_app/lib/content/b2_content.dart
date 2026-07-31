import 'package:flutter/material.dart';
import '../models/unit.dart';
import 'builders.dart';

/// Niveau B2 - Intermédiaire avancé : discours indirect, participes,
/// vocabulaire des médias et de l'actualité.
List<LearningUnit> buildB2Units() {
  return [
    LearningUnit(
      id: 'b2_u1',
      title: 'Le discours indirect',
      description: 'Rapporte ce que quelqu\'un a dit',
      icon: Icons.chat_bubble_outline,
      lessons: [
        lesson('b2_u1_l1', 'Он сказал, что...', [
          flashcard('b2_u1_l1_e1', 'Он сказал, что...', 'Il a dit que...', example: 'Он сказал, что придёт завтра.', exampleTranslation: "Il a dit qu'il viendrait demain."),
          flashcard('b2_u1_l1_e2', 'Она спросила, ...ли...', 'Elle a demandé si...', example: 'Она спросила, знаю ли я его.', exampleTranslation: 'Elle a demandé si je le connaissais.'),
          flashcard('b2_u1_l1_e3', 'Он попросил, чтобы...', 'Il a demandé que...'),
          mc('b2_u1_l1_e4', '"Elle a demandé si" se dit :', 'Она спросила, ...ли...', 'Elle a demandé si', ['Она сказала, что', 'Она спросила, ...ли...', 'Она попросила, чтобы'], 'Она спросила, ...ли...'),
          translate('b2_u1_l1_e5', 'Он сказал, что он занят.', "Il a dit qu'il était occupé.", answerInRussian: false),
          listen('b2_u1_l1_e6', 'Она спросила, где я живу.', "Elle a demandé où j'habitais.", ["Elle a demandé où j'habitais.", "Elle a dit où j'habitais.", "Elle a demandé si j'habitais ici."], "Elle a demandé où j'habitais."),
        ]),
        lesson('b2_u1_l2', 'Rapporter des ordres et des questions', [
          flashcard('b2_u1_l2_e1', 'Он попросил меня прийти.', "Il m'a demandé de venir."),
          flashcard('b2_u1_l2_e2', 'Она сказала, чтобы я подождал.', "Elle m'a dit d'attendre."),
          mc('b2_u1_l2_e3', '"Il m\'a demandé de venir" se dit :', 'Он попросил меня прийти.', "Il m'a demandé de venir.", ['Он сказал, что я приду.', 'Он попросил меня прийти.', 'Он спросил, приду ли я.'], 'Он попросил меня прийти.'),
          translate('b2_u1_l2_e4', 'Она сказала, чтобы я подождал.', "Elle m'a dit d'attendre.", answerInRussian: false),
          speak('b2_u1_l2_e5', 'Он сказал, что придёт, но попросил меня подождать.', "Il a dit qu'il viendrait, mais il m'a demandé d'attendre."),
        ]),
      ],
    ),
    LearningUnit(
      id: 'b2_u2',
      title: 'Les participes',
      description: 'Introduction aux participes actifs et passifs',
      icon: Icons.auto_awesome_motion,
      lessons: [
        lesson('b2_u2_l1', 'Participe présent actif', [
          flashcard('b2_u2_l1_e1', 'читающий человек', "l'homme qui lit (litt. lisant)"),
          flashcard('b2_u2_l1_e2', 'работающая женщина', "la femme qui travaille"),
          mc('b2_u2_l1_e3', '"L\'homme qui lit" se dit :', 'читающий человек', "l'homme qui lit", ['читающий человек', 'читавший человек', 'прочитанный человек'], 'читающий человек'),
          translate('b2_u2_l1_e4', 'Студент, изучающий русский язык.', "L'étudiant qui étudie le russe.", answerInRussian: false),
        ]),
        lesson('b2_u2_l2', 'Participe passé passif', [
          flashcard('b2_u2_l2_e1', 'написанная книга', 'le livre écrit'),
          flashcard('b2_u2_l2_e2', 'построенный дом', 'la maison construite'),
          mc('b2_u2_l2_e3', '"Le livre écrit" se dit :', 'написанная книга', 'le livre écrit', ['написанная книга', 'пишущая книга', 'написавшая книга'], 'написанная книга'),
          translate('b2_u2_l2_e4', 'Дом, построенный в 1990 году.', 'La maison construite en 1990.', answerInRussian: false),
          speak('b2_u2_l2_e5', 'Книга, написанная известным писателем, очень интересная.', "Le livre écrit par un écrivain célèbre est très intéressant."),
        ]),
      ],
    ),
    LearningUnit(
      id: 'b2_u3',
      title: 'Actualité et médias',
      description: 'Comprends les infos et discute de sujets de société',
      icon: Icons.newspaper,
      lessons: [
        lesson('b2_u3_l1', 'Vocabulaire des médias', [
          flashcard('b2_u3_l1_e1', 'новости', 'les informations / les nouvelles'),
          flashcard('b2_u3_l1_e2', 'статья, журналист', 'article, journaliste'),
          flashcard('b2_u3_l1_e3', 'по данным...', 'selon..., d\'après...'),
          mc('b2_u3_l1_e4', '"Selon..." se dit :', 'по данным...', 'selon...', ['новости', 'статья', 'по данным...'], 'по данным...'),
          translate('b2_u3_l1_e5', 'По данным журналиста, ситуация улучшается.', "Selon le journaliste, la situation s'améliore.", answerInRussian: false),
        ]),
        lesson('b2_u3_l2', 'Discuter de sujets de société', [
          flashcard('b2_u3_l2_e1', 'с одной стороны... с другой стороны...', "d'un côté... de l'autre côté..."),
          flashcard('b2_u3_l2_e2', 'проблема, решение', 'problème, solution'),
          flashcard('b2_u3_l2_e3', 'влияние, общество', 'influence, société'),
          mc('b2_u3_l2_e4', '"Problème" se dit :', 'проблема', 'problème', ['решение', 'проблема', 'влияние'], 'проблема'),
          translate('b2_u3_l2_e5', 'Это влияет на общество.', 'Cela influence la société.', answerInRussian: false),
          speak('b2_u3_l2_e6', 'С одной стороны, это проблема, а с другой стороны — есть решение.', "D'un côté c'est un problème, mais de l'autre il y a une solution."),
        ]),
      ],
    ),
  ];
}
