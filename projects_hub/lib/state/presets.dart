import '../models/project.dart';

/// Projects added on first launch (and by "Restaurer les projets d'origine").
/// Fixed ids so restoring never duplicates them.
List<Project> defaultProjects() => [
      Project(
        id: 'preset-burgerquiz',
        name: 'Burger Quiz',
        description: 'Le jeu Burger Quiz (Nuggets, Sel ou Poivre, Menus, Addition, Burger de la mort).',
        emoji: '🍔',
        color: 0xFFEDB400,
        category: 'Jeux',
        type: SourceType.github,
        owner: 'JK-ASFC',
        repo: 'SW',
        branch: 'main',
        entry: 'index.html',
        orientation: PlayerOrientation.landscape,
        fullscreen: true,
      ),
      Project(
        id: 'preset-ruspath',
        name: 'RusPath — Russe',
        description: 'Apprendre le russe de A1 à C1 (appli Android).',
        emoji: '🇷🇺',
        color: 0xFFD52B1E,
        category: 'Apprentissage',
        type: SourceType.androidApp,
        owner: 'JK-ASFC',
        repo: 'test',
        packageName: 'com.ruspath.russian_learning_app',
        apkUrl:
            'https://github.com/JK-ASFC/test/releases/download/ruspath-latest/app-release.apk',
      ),
      Project(
        id: 'preset-portfolio',
        name: 'Portfolio',
        description: 'Mon portfolio (présentation, formation, réalisations, certifications).',
        emoji: '💼',
        color: 0xFF3F51B5,
        category: 'Web',
        type: SourceType.github,
        owner: 'JK-ASFC',
        repo: 'portfolio',
        branch: 'main',
        entry: 'index.html',
      ),
      fonduMusique(),
    ];

/// Built-in crossfade music player (assets/builtin/fondu_musique), reading the
/// music stored on the phone.
Project fonduMusique() => Project(
      id: 'preset-fondu-musique',
      name: 'Fondu musique',
      description: 'Boom Player version téléphone : tes musiques, playlists et repères, en fondu enchaîné.',
      emoji: '🎵',
      color: 0xFF8E24AA,
      category: 'Musique',
      type: SourceType.builtin,
      builtin: 'fondu_musique',
      entry: 'index.html',
      orientation: PlayerOrientation.portrait,
    );
