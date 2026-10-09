import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';
import 'github_service.dart';

/// Where project files live on the phone, and how they get there.
class ProjectFiles {
  ProjectFiles(this.baseDir);

  /// `<app documents>/projects`
  final Directory baseDir;

  static Future<ProjectFiles> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'projects'));
    await dir.create(recursive: true);
    return ProjectFiles(dir);
  }

  Directory projectDir(String id) => Directory(p.join(baseDir.path, id));
  Directory contentDir(String id) => Directory(p.join(baseDir.path, id, 'content'));

  /// Folder served for [project], or null if it isn't available offline.
  String? serveRoot(Project project) {
    switch (project.type) {
      case SourceType.github:
        final c = contentDir(project.id);
        if (!c.existsSync()) return null;
        final root = project.subdir.isEmpty ? c.path : p.join(c.path, project.subdir);
        return Directory(root).existsSync() ? root : null;
      case SourceType.zipImport:
        final c = contentDir(project.id);
        if (!c.existsSync()) return null;
        return project.subdir.isEmpty ? c.path : p.join(c.path, project.subdir);
      case SourceType.localFolder:
        final lp = project.localPath;
        return lp != null && Directory(lp).existsSync() ? lp : null;
      case SourceType.url:
      case SourceType.androidApp:
        return null;
    }
  }

  bool isDownloaded(Project project) =>
      (project.type == SourceType.github || project.type == SourceType.zipImport) &&
      contentDir(project.id).existsSync();

  /// Downloads [project]'s branch and atomically replaces its local copy.
  Future<void> syncFromGithub(
    Project project,
    GithubService gh, {
    void Function(double? progress, String status)? onProgress,
  }) async {
    final dir = projectDir(project.id);
    await dir.create(recursive: true);
    final zip = File(p.join(dir.path, 'download.zip'));
    try {
      onProgress?.call(null, 'Téléchargement…');
      await gh.downloadZip(project.owner, project.repo, project.branch, zip,
          onProgress: (r, t) => onProgress?.call(
              t == null ? null : r / t, 'Téléchargement… ${_mb(r)}${t == null ? '' : ' / ${_mb(t)}'}'));
      onProgress?.call(null, 'Décompression…');
      await installZip(project.id, zip);
    } finally {
      if (zip.existsSync()) await zip.delete();
    }
  }

  /// Extracts [zip] as the new content of project [id]. When the archive has
  /// a single top-level folder (GitHub ZIPs always do), that folder becomes
  /// the content root.
  Future<void> installZip(String id, File zip) async {
    final dir = projectDir(id);
    await dir.create(recursive: true);
    final tmp = Directory(p.join(dir.path, '_extract'));
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    await tmp.create();
    final zipPath = zip.path, tmpPath = tmp.path;
    await Isolate.run(() => extractFileToDisk(zipPath, tmpPath));

    var root = tmp;
    final entries = tmp.listSync().where((e) => !p.basename(e.path).startsWith('__MACOSX')).toList();
    if (entries.length == 1 && entries.first is Directory) root = entries.first as Directory;

    final content = contentDir(id);
    if (content.existsSync()) await content.delete(recursive: true);
    await root.rename(content.path);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  }

  /// Lists .html files of a served folder (relative paths), to pick an entry page.
  static List<String> listHtml(String root, {int max = 200}) {
    final out = <String>[];
    final dir = Directory(root);
    if (!dir.existsSync()) return out;
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is File && RegExp(r'\.html?$', caseSensitive: false).hasMatch(e.path)) {
          final rel = p.relative(e.path, from: root).replaceAll('\\', '/');
          if (rel.split('/').any((s) => s.startsWith('.') || s == 'node_modules')) continue;
          out.add(rel);
          if (out.length >= max) break;
        }
      }
    } on FileSystemException {
      // Unreadable folder (missing permission) - return what we have.
    }
    out.sort((a, b) {
      final d = '/'.allMatches(a).length.compareTo('/'.allMatches(b).length);
      if (d != 0) return d;
      if (a.endsWith('index.html') != b.endsWith('index.html')) {
        return a.endsWith('index.html') ? -1 : 1;
      }
      return a.compareTo(b);
    });
    return out;
  }

  Future<void> deleteProject(String id) async {
    final d = projectDir(id);
    if (d.existsSync()) await d.delete(recursive: true);
  }

  Future<int> totalSize() async {
    var total = 0;
    if (!baseDir.existsSync()) return 0;
    await for (final e in baseDir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Copies a picked image (cover/wallpaper) into app storage so it survives
  /// the picker's cache being cleared.
  Future<String> keepImage(String sourcePath, String name) async {
    final dir = Directory(p.join(baseDir.parent.path, 'images'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path,
        '${name}_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}');
    await File(sourcePath).copy(dest);
    return dest;
  }

  static String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} Mo';
}
