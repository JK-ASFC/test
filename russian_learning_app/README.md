# RusPath — Apprends le russe de A1 à C1

Application Android (Flutter) gratuite, sans compte et sans publicité pour
apprendre le russe du niveau complet débutant (A1) jusqu'au niveau
professionnel (C1), avec sauvegarde automatique de la progression.

## Fonctionnalités

- **5 niveaux CEFR (A1 → C1)**, chacun découpé en unités puis en leçons,
  dans l'esprit "parcours" de Duolingo (cercles à débloquer les uns après
  les autres).
- **7 types d'exercices** pour travailler tous les aspects de la langue :
  - Flashcards (nouveau vocabulaire, avec prononciation)
  - QCM de traduction
  - Écoute (la phrase russe est seulement prononcée, jamais affichée)
  - Traduction à l'écrit (saisie libre, tolérante aux fautes de frappe/ё-е)
  - Reconstitution de phrase (mots à remettre dans l'ordre)
  - Association de paires (russe ↔ français)
  - Expression orale (reconnaissance vocale sur l'appareil, feedback
    encourageant plutôt que sanction)
- **Sauvegarde et reprise** : la position exacte dans une leçon est
  enregistrée à chaque exercice, tu peux fermer l'appli et reprendre pile où
  tu en étais.
- **Répétition espacée (SRS)** : chaque mot appris est automatiquement ajouté
  à une banque de révision (algorithme façon SM-2/Anki) et ressort dans
  l'onglet "Pratique" juste avant que tu risques de l'oublier.
- **Objectif quotidien personnalisable** (5/10/15/20/30 min), série
  ("streak") de jours consécutifs, XP, statistiques par niveau.
- **Rappel quotidien** (notification locale, heure personnalisable).
- **100% hors-ligne et local** : toutes les données (progression, XP,
  paramètres, vocabulaire à réviser) sont stockées uniquement sur l'appareil
  via Hive, sans compte ni serveur. La synthèse vocale et la reconnaissance
  vocale utilisent les moteurs déjà intégrés à Android — aucune API tierce
  payante.
- Thème clair/sombre/système, vitesse de la voix réglable, son
  automatique activable/désactivable.

## Contenu du cours (v1)

| Niveau | Unités | Leçons | Thèmes |
|---|---|---|---|
| A1 | 6 | 18 | Alphabet, salutations, nombres/heure, famille, nourriture, verbes au présent |
| A2 | 4 | 8 | Passé, cas prépositionnel (lieux), datif (goûts/besoins), futur |
| B1 | 3 | 6 | Aspect des verbes, comparatifs/opinions, instrumental/métiers |
| B2 | 3 | 6 | Discours indirect, participes, vocabulaire des médias |
| C1 | 3 | 6 | Russe des affaires, correspondance formelle, nuances/négociation |

C'est un vrai cours complet et fonctionnel de bout en bout, pensé pour être
étendu facilement (voir "Ajouter du contenu" ci-dessous) jusqu'à une
couverture aussi dense que tu veux.

## Compiler l'APK

### Option A — automatique (recommandé)

Un workflow GitHub Actions (`.github/workflows/build-ruspath-apk.yml`) compile
l'APK à chaque `push` sur ce dossier et le publie :
- en artefact du run ("ruspath-apk"), et
- sur une release GitHub `ruspath-latest` (fichier `app-release.apk`
  toujours à jour avec le dernier commit).

Va dans l'onglet **Actions** ou **Releases** du dépôt GitHub pour télécharger
`app-release.apk` et l'installer sur ton téléphone Android (autorise
« sources inconnues » si demandé).

### Option B — en local

```bash
flutter pub get
flutter build apk --release
# APK généré dans build/app/outputs/flutter-apk/app-release.apk
```

Prérequis : Flutter 3.24+ et le SDK Android (`flutter doctor` doit être vert).

## Ajouter du contenu (nouvelles leçons/niveaux)

Tout le cours est défini en Dart pur dans `lib/content/` :
- `a1_content.dart`, `a2_content.dart`, `b1_content.dart`, `b2_content.dart`,
  `c1_content.dart` : une fonction `buildXXUnits()` qui retourne la liste des
  unités de ce niveau.
- `builders.dart` : petites fonctions d'aide (`mc`, `listen`, `translate`,
  `wordBank`, `matchPairs`, `speak`, `flashcard`, `lesson`) pour écrire un
  exercice en une seule ligne.

Pour ajouter une leçon, ajoute un appel à `lesson('id_unique', 'Titre', [...])`
dans la liste `lessons` de l'unité voulue, avec la liste d'exercices voulue.
`test/content_integrity_test.dart` vérifie automatiquement (via `flutter
test`) que chaque nouvel exercice est cohérent (options valides, banque de
mots complète, identifiants uniques, etc.) — lance-le après toute
modification de contenu.

## Architecture

```
lib/
  models/      Exercise, Lesson, LearningUnit, CourseLevel (CEFR)
  content/     Le cours complet, A1 à C1, en Dart
  services/    ProgressService (sauvegarde/XP/série/réglages, Hive),
               SrsService (répétition espacée), TtsService, SttService,
               NotificationService
  screens/     Onboarding, Accueil (Apprendre/Pratique/Progrès/Réglages),
               Leçon, Résumé de leçon, Révision
  widgets/     Un widget par type d'exercice + composants partagés
```

Aucune dépendance à un compte, un cloud, ou une API payante : c'est ce qui
permet de rester gratuit indéfiniment.
