/// Where a project's files come from.
enum SourceType {
  /// A branch of a GitHub repository, downloaded as a ZIP and served offline.
  github,

  /// A folder already on the phone (e.g. /storage/emulated/0/Projets/quiz).
  localFolder,

  /// A ZIP archive imported once and copied into the app's storage.
  zipImport,

  /// Any website / remote server (GitHub Pages, PC on the Wi-Fi, ...).
  url,

  /// An installed Android application (e.g. RusPath), launched by package name.
  androidApp,

  /// A web app shipped inside Mes Projets itself (e.g. Fondu musique).
  builtin,
}

extension SourceTypeLabel on SourceType {
  String get label => switch (this) {
        SourceType.github => 'GitHub',
        SourceType.localFolder => 'Dossier local',
        SourceType.zipImport => 'ZIP importé',
        SourceType.url => 'Site distant',
        SourceType.androidApp => 'Appli Android',
        SourceType.builtin => 'Appli intégrée',
      };
}

/// Screen orientation forced while a project is open.
enum PlayerOrientation { auto, portrait, landscape }

extension PlayerOrientationLabel on PlayerOrientation {
  String get label => switch (this) {
        PlayerOrientation.auto => 'Automatique',
        PlayerOrientation.portrait => 'Portrait',
        PlayerOrientation.landscape => 'Paysage',
      };
}

class Project {
  Project({
    required this.id,
    required this.name,
    required this.type,
    this.description = '',
    this.emoji = '📁',
    this.color = 0xFF6750A4,
    this.coverPath,
    this.category = '',
    this.favorite = false,
    this.owner = '',
    this.repo = '',
    this.branch = 'main',
    this.subdir = '',
    this.localPath,
    this.url,
    this.entry = 'index.html',
    this.packageName,
    this.apkUrl,
    this.builtin,
    this.orientation = PlayerOrientation.auto,
    this.fullscreen = false,
    this.installedSha,
    this.remoteSha,
    this.lastSync,
    this.lastOpened,
    this.openCount = 0,
  });

  final String id;
  String name;
  String description;
  String emoji;
  int color;
  String? coverPath;
  String category;
  bool favorite;
  SourceType type;

  // GitHub source
  String owner;
  String repo;
  String branch;

  /// Sub-folder of the repository to serve (empty = repository root).
  String subdir;

  // Local folder (absolute path) for [SourceType.localFolder].
  String? localPath;

  // Remote site for [SourceType.url].
  String? url;

  /// Page opened first, relative to the served folder.
  String entry;

  // Android app source
  String? packageName;
  String? apkUrl;

  /// Which built-in app, for [SourceType.builtin] (folder under assets/builtin/).
  String? builtin;

  // Player options
  PlayerOrientation orientation;
  bool fullscreen;

  // Sync state (GitHub)
  String? installedSha;
  String? remoteSha;
  DateTime? lastSync;

  // Usage
  DateTime? lastOpened;
  int openCount;

  bool get isWeb => type != SourceType.androidApp;

  bool get updateAvailable =>
      type == SourceType.github &&
      installedSha != null &&
      remoteSha != null &&
      installedSha != remoteSha;

  String get sourceSummary => switch (type) {
        SourceType.github =>
          '$owner/$repo · $branch${subdir.isEmpty ? '' : ' · /$subdir'}',
        SourceType.localFolder => localPath ?? '',
        SourceType.zipImport => 'Copie locale',
        SourceType.url => url ?? '',
        SourceType.androidApp => packageName ?? '',
        SourceType.builtin => 'Intégrée à Mes Projets',
      };

  Project copy({String? id}) => Project.fromJson({...toJson(), 'id': id ?? this.id});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'color': color,
        'coverPath': coverPath,
        'category': category,
        'favorite': favorite,
        'type': type.name,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'subdir': subdir,
        'localPath': localPath,
        'url': url,
        'entry': entry,
        'packageName': packageName,
        'apkUrl': apkUrl,
        'builtin': builtin,
        'orientation': orientation.name,
        'fullscreen': fullscreen,
        'installedSha': installedSha,
        'remoteSha': remoteSha,
        'lastSync': lastSync?.toIso8601String(),
        'lastOpened': lastOpened?.toIso8601String(),
        'openCount': openCount,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Projet',
        description: j['description'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '📁',
        color: j['color'] as int? ?? 0xFF6750A4,
        coverPath: j['coverPath'] as String?,
        category: j['category'] as String? ?? '',
        favorite: j['favorite'] as bool? ?? false,
        type: SourceType.values.asNameMap()[j['type']] ?? SourceType.url,
        owner: j['owner'] as String? ?? '',
        repo: j['repo'] as String? ?? '',
        branch: j['branch'] as String? ?? 'main',
        subdir: j['subdir'] as String? ?? '',
        localPath: j['localPath'] as String?,
        url: j['url'] as String?,
        entry: j['entry'] as String? ?? 'index.html',
        packageName: j['packageName'] as String?,
        apkUrl: j['apkUrl'] as String?,
        builtin: j['builtin'] as String?,
        orientation: PlayerOrientation.values.asNameMap()[j['orientation']] ??
            PlayerOrientation.auto,
        fullscreen: j['fullscreen'] as bool? ?? false,
        installedSha: j['installedSha'] as String?,
        remoteSha: j['remoteSha'] as String?,
        lastSync: DateTime.tryParse(j['lastSync'] as String? ?? ''),
        lastOpened: DateTime.tryParse(j['lastOpened'] as String? ?? ''),
        openCount: j['openCount'] as int? ?? 0,
      );
}
