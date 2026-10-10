import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/project.dart';
import '../services/github_service.dart';
import '../services/project_files.dart';
import 'presets.dart';

/// Progress of a running download, shown on the project's card.
class SyncStatus {
  SyncStatus(this.progress, this.message);
  final double? progress;
  final String message;
}

/// App state: the projects, the settings, and running downloads.
class HubController extends ChangeNotifier {
  HubController(this._prefs, this.files)
      : github = GithubService();

  final SharedPreferences _prefs;
  final ProjectFiles files;
  final GithubService github;

  static const _kProjects = 'projects_v1';
  static const _kSettings = 'settings_v1';
  static const _kSeenPresets = 'seen_presets_v1';

  /// Presets shipped with the first version, before [_kSeenPresets] existed.
  static const _firstPresets = ['preset-burgerquiz', 'preset-ruspath', 'preset-portfolio'];

  List<Project> projects = [];
  AppSettings settings = AppSettings();
  final Map<String, SyncStatus> syncing = {};

  static Future<HubController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final files = await ProjectFiles.create();
    final c = HubController(prefs, files);
    c.restore();
    return c;
  }

  @visibleForTesting
  void restore() {
    final s = _prefs.getString(_kSettings);
    if (s != null) {
      try {
        settings = AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    github.token = settings.githubToken;
    final p = _prefs.getString(_kProjects);
    if (p == null) {
      projects = defaultProjects();
      _saveProjects();
    } else {
      try {
        projects = (jsonDecode(p) as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        projects = defaultProjects();
      }
      _addNewPresets();
    }
    _prefs.setStringList(_kSeenPresets, defaultProjects().map((d) => d.id).toList());
  }

  /// Presets added in an app update show up on existing installs too, but a
  /// preset the user already saw (and maybe deleted) never comes back.
  void _addNewPresets() {
    final seen = _prefs.getStringList(_kSeenPresets) ?? _firstPresets;
    var added = false;
    for (final d in defaultProjects()) {
      if (!seen.contains(d.id) && byId(d.id) == null) {
        projects.add(d);
        added = true;
      }
    }
    // v2 pointed Fondu musique at a GitHub repo; it is now built in.
    final fondu = byId('preset-fondu-musique');
    if (fondu != null && fondu.type == SourceType.github && fondu.repo == 'fondu-musique') {
      final b = fonduMusique();
      fondu
        ..type = b.type
        ..builtin = b.builtin
        ..owner = ''
        ..repo = ''
        ..entry = b.entry
        ..installedSha = null
        ..remoteSha = null;
      if (fondu.description.startsWith('Fondu enchaîné entre musiques')) fondu.description = b.description;
      added = true;
    }
    if (added) _saveProjects();
  }

  Future<void> _saveProjects() =>
      _prefs.setString(_kProjects, jsonEncode(projects.map((p) => p.toJson()).toList()));

  Future<void> saveSettings() async {
    github.token = settings.githubToken;
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  static String newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 30).toRadixString(36)}';
  }

  Project? byId(String id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<String> get categories {
    final set = <String>{};
    for (final p in projects) {
      if (p.category.trim().isNotEmpty) set.add(p.category.trim());
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Projects filtered by [query]/[category] ('★' = favorites) and sorted
  /// according to the settings. Favorites always come first.
  List<Project> visible({String query = '', String? category}) {
    final q = query.trim().toLowerCase();
    final list = projects.where((p) {
      if (category == '★' && !p.favorite) return false;
      if (category != null && category != '★' && p.category.trim() != category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.sourceSummary.toLowerCase().contains(q);
    }).toList();
    final order = {for (var i = 0; i < projects.length; i++) projects[i].id: i};
    int byMode(Project a, Project b) => switch (settings.sortMode) {
          SortMode.custom => order[a.id]!.compareTo(order[b.id]!),
          SortMode.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          SortMode.recent => (b.lastOpened ?? DateTime(2000))
              .compareTo(a.lastOpened ?? DateTime(2000)),
          SortMode.mostUsed => b.openCount.compareTo(a.openCount),
        };
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return byMode(a, b);
    });
    return list;
  }

  Future<void> upsert(Project p) async {
    final i = projects.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      projects[i] = p;
    } else {
      projects.add(p);
    }
    await _saveProjects();
    notifyListeners();
  }

  Future<void> remove(Project p) async {
    projects.removeWhere((x) => x.id == p.id);
    await _saveProjects();
    notifyListeners();
    await files.deleteProject(p.id);
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final p = projects.removeAt(oldIndex);
    projects.insert(newIndex, p);
    await _saveProjects();
    notifyListeners();
  }

  Future<void> toggleFavorite(Project p) async {
    p.favorite = !p.favorite;
    await _saveProjects();
    notifyListeners();
  }

  Future<void> markOpened(Project p) async {
    p.lastOpened = DateTime.now();
    p.openCount++;
    await _saveProjects();
    notifyListeners();
  }

  /// Downloads the latest commit of a GitHub project.
  Future<void> sync(Project p) async {
    if (p.type != SourceType.github || syncing.containsKey(p.id)) return;
    syncing[p.id] = SyncStatus(null, 'Préparation…');
    notifyListeners();
    try {
      String? sha;
      try {
        sha = await github.latestSha(p.owner, p.repo, p.branch);
      } on GithubException {
        // Rate limited etc.: the ZIP download may still work.
      }
      await files.syncFromGithub(p, github, onProgress: (prog, msg) {
        syncing[p.id] = SyncStatus(prog, msg);
        notifyListeners();
      });
      p.installedSha = sha ?? p.remoteSha ?? 'unknown';
      p.remoteSha = sha ?? p.installedSha;
      p.lastSync = DateTime.now();
      await _saveProjects();
    } finally {
      syncing.remove(p.id);
      notifyListeners();
    }
  }

  /// Asks GitHub for the latest commit of every GitHub project (cheap: one
  /// API call per project) so cards can show "update available".
  Future<void> checkUpdates() async {
    var changed = false;
    for (final p in projects.where((p) => p.type == SourceType.github)) {
      try {
        final sha = await github.latestSha(p.owner, p.repo, p.branch);
        if (sha != p.remoteSha) {
          p.remoteSha = sha;
          changed = true;
        }
      } catch (_) {
        // Offline or rate-limited: keep what we know.
      }
    }
    if (changed) {
      await _saveProjects();
      notifyListeners();
    }
  }

  // ---------- Backup ----------

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'projects_hub',
        'version': 1,
        'settings': settings.toJson(includeSecrets: false),
        'projects': projects.map((p) {
          final j = p.toJson();
          // Download state is device-specific.
          j.remove('installedSha');
          return j;
        }).toList(),
      });

  /// Replaces settings (except the token) and merges projects by id.
  Future<int> importJson(String raw) async {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['settings'] is Map) {
      final token = settings.githubToken;
      settings = AppSettings.fromJson((j['settings'] as Map).cast<String, dynamic>())
        ..githubToken = token;
      await saveSettings();
    }
    var count = 0;
    for (final e in (j['projects'] as List? ?? const [])) {
      final p = Project.fromJson((e as Map).cast<String, dynamic>());
      final existing = byId(p.id);
      if (existing != null) p.installedSha = existing.installedSha;
      final i = projects.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        projects[i] = p;
      } else {
        projects.add(p);
      }
      count++;
    }
    await _saveProjects();
    notifyListeners();
    return count;
  }

  Future<void> restoreDefaults() async {
    for (final d in defaultProjects()) {
      if (byId(d.id) == null) projects.add(d);
    }
    await _saveProjects();
    notifyListeners();
  }

  Future<void> clearDownloads() async {
    for (final p in projects) {
      if (p.type == SourceType.github) {
        final d = files.contentDir(p.id);
        if (d.existsSync()) await d.delete(recursive: true);
        p.installedSha = null;
      }
    }
    await _saveProjects();
    notifyListeners();
  }

  bool isAvailableOffline(Project p) => switch (p.type) {
        SourceType.github || SourceType.zipImport => files.isDownloaded(p),
        SourceType.localFolder => p.localPath != null && Directory(p.localPath!).existsSync(),
        _ => true,
      };
}
