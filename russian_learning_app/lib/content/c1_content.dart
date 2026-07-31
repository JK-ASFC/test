import 'package:flutter/material.dart';
import '../models/unit.dart';
import 'builders.dart';

/// Niveau C1 - Avancé / Professionnel : russe des affaires, nuances,
/// correspondance formelle et négociation.
List<LearningUnit> buildC1Units() {
  return [
    LearningUnit(
      id: 'c1_u1',
      title: 'Russe des affaires',
      description: 'Réunions, présentations et vocabulaire professionnel',
      icon: Icons.business_center,
      lessons: [
        lesson('c1_u1_l1', 'En réunion', [
          flashcard('c1_u1_l1_e1', 'повестка дня', "l'ordre du jour"),
          flashcard('c1_u1_l1_e2', 'принять решение', 'prendre une décision'),
          flashcard('c1_u1_l1_e3', 'подвести итоги', 'faire le bilan / résumer'),
          flashcard('c1_u1_l1_e4', 'сотрудничество', 'la coopération'),
          mc('c1_u1_l1_e5', '"Prendre une décision" se dit :', 'принять решение', 'prendre une décision', ['повестка дня', 'принять решение', 'подвести итоги'], 'принять решение'),
          translate('c1_u1_l1_e6', 'Давайте подведём итоги встречи.', 'Faisons le bilan de la réunion.', answerInRussian: false),
          listen('c1_u1_l1_e7', 'Нам нужно принять решение сегодня.', "Nous devons prendre une décision aujourd'hui.", ["Nous devons prendre une décision aujourd'hui.", "Nous avons pris une décision hier.", "Ils prendront une décision demain."], "Nous devons prendre une décision aujourd'hui."),
        ]),
        lesson('c1_u1_l2', 'Présenter un projet', [
          flashcard('c1_u1_l2_e1', 'на мой взгляд', 'à mon sens / de mon point de vue'),
          flashcard('c1_u1_l2_e2', 'следует отметить, что...', 'il convient de noter que...'),
          flashcard('c1_u1_l2_e3', 'в связи с этим', "à cet égard / en lien avec cela"),
          flashcard('c1_u1_l2_e4', 'рентабельность, бюджет', 'rentabilité, budget'),
          mc('c1_u1_l2_e5', '"Il convient de noter que" se dit :', 'следует отметить, что', 'il convient de noter que', ['на мой взгляд', 'следует отметить, что', 'в связи с этим'], 'следует отметить, что'),
          translate('c1_u1_l2_e6', 'На мой взгляд, бюджет слишком маленький.', 'À mon sens, le budget est trop petit.', answerInRussian: false),
          speak('c1_u1_l2_e7', 'Следует отметить, что рентабельность проекта высокая.', 'Il convient de noter que la rentabilité du projet est élevée.'),
        ]),
      ],
    ),
    LearningUnit(
      id: 'c1_u2',
      title: 'Correspondance formelle',
      description: "Rédige des e-mails et lettres professionnelles",
      icon: Icons.mail_outline,
      lessons: [
        lesson('c1_u2_l1', "Formules d'ouverture et de clôture", [
          flashcard('c1_u2_l1_e1', 'Уважаемый господин / Уважаемая госпожа', 'Cher Monsieur / Chère Madame'),
          flashcard('c1_u2_l1_e2', 'Прошу вас...', 'Je vous prie de...'),
          flashcard('c1_u2_l1_e3', 'С уважением,', 'Cordialement, / Veuillez agréer mes salutations distinguées,'),
          flashcard('c1_u2_l1_e4', 'Заранее благодарю за ответ.', "Je vous remercie d'avance pour votre réponse."),
          mc('c1_u2_l1_e5', 'On termine une lettre formelle par :', 'С уважением,', 'Cordialement,', ['Прошу вас,', 'С уважением,', 'Заранее благодарю,'], 'С уважением,'),
          translate('c1_u2_l1_e6', 'Прошу вас подтвердить получение письма.', 'Je vous prie de confirmer la réception de la lettre.', answerInRussian: false),
        ]),
        lesson('c1_u2_l2', 'Réclamations et demandes formelles', [
          flashcard('c1_u2_l2_e1', 'В связи с вышеизложенным...', 'Compte tenu de ce qui précède...'),
          flashcard('c1_u2_l2_e2', 'выражаю недовольство', "j'exprime mon mécontentement"),
          flashcard('c1_u2_l2_e3', 'прошу принять меры', 'je vous prie de prendre des mesures'),
          mc('c1_u2_l2_e4', '"Je vous prie de prendre des mesures" :', 'прошу принять меры', 'je vous prie de prendre des mesures', ['выражаю недовольство', 'прошу принять меры', 'в связи с вышеизложенным'], 'прошу принять меры'),
          translate('c1_u2_l2_e5', 'Прошу вас принять меры в кратчайшие сроки.', 'Je vous prie de prendre des mesures dans les plus brefs délais.', answerInRussian: false),
          speak('c1_u2_l2_e6', 'В связи с вышеизложенным прошу принять меры и заранее благодарю за ответ.', "Compte tenu de ce qui précède, je vous prie de prendre des mesures et vous remercie d'avance pour votre réponse."),
        ]),
      ],
    ),
    LearningUnit(
      id: 'c1_u3',
      title: 'Nuances et négociation',
      description: 'Idiomes avancés, connecteurs subtils, négociation',
      icon: Icons.handshake,
      lessons: [
        lesson('c1_u3_l1', 'Connecteurs logiques avancés', [
          flashcard('c1_u3_l1_e1', 'тем не менее', 'néanmoins'),
          flashcard('c1_u3_l1_e2', 'несмотря на то, что...', 'bien que... / malgré le fait que...'),
          flashcard('c1_u3_l1_e3', 'вследствие этого', 'par conséquent'),
          flashcard('c1_u3_l1_e4', 'иными словами', "autrement dit"),
          mc('c1_u3_l1_e5', '"Néanmoins" se dit :', 'тем не менее', 'néanmoins', ['вследствие этого', 'тем не менее', 'иными словами'], 'тем не менее'),
          translate('c1_u3_l1_e6', 'Несмотря на трудности, мы достигли цели.', "Malgré les difficultés, nous avons atteint l'objectif.", answerInRussian: false),
        ]),
        lesson('c1_u3_l2', 'Négocier un accord', [
          flashcard('c1_u3_l2_e1', 'пойти на компромисс', 'faire un compromis'),
          flashcard('c1_u3_l2_e2', 'взаимовыгодное решение', 'une solution mutuellement avantageuse'),
          flashcard('c1_u3_l2_e3', 'заключить сделку', 'conclure un accord / un marché'),
          flashcard('c1_u3_l2_e4', 'в разумных пределах', 'dans des limites raisonnables'),
          mc('c1_u3_l2_e5', '"Conclure un accord" se dit :', 'заключить сделку', 'conclure un accord', ['пойти на компромисс', 'заключить сделку', 'взаимовыгодное решение'], 'заключить сделку'),
          translate('c1_u3_l2_e6', 'Мы готовы пойти на компромисс.', 'Nous sommes prêts à faire un compromis.', answerInRussian: false),
          speak('c1_u3_l2_e7', 'Давайте найдём взаимовыгодное решение и заключим сделку.', 'Trouvons une solution mutuellement avantageuse et concluons un accord.'),
        ]),
      ],
    ),
  ];
}
