import 'dart:convert';
import 'dart:io';

class GithubRepo {
  GithubRepo({
    required this.owner,
    required this.name,
    required this.description,
    required this.defaultBranch,
    required this.isPrivate,
    required this.pushedAt,
    this.language,
  });

  final String owner;
  final String name;
  final String description;
  final String defaultBranch;
  final bool isPrivate;
  final DateTime? pushedAt;
  final String? language;

  String get fullName => '$owner/$name';
}

class GithubApk {
  GithubApk({required this.name, required this.url, required this.release});
  final String name;
  final String url;
  final String release;
}

/// What a branch contains, used to pre-fill a new project.
class BranchScan {
  BranchScan({
    required this.htmlFiles,
    required this.flutterApps,
    required this.androidPackages,
  });

  /// Every .html page of the branch, shortest paths first.
  final List<String> htmlFiles;

  /// Folders containing a pubspec.yaml with an android/ folder.
  final List<String> flutterApps;

  /// applicationId values found in Gradle files.
  final List<String> androidPackages;
}

class GithubException implements Exception {
  GithubException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin client over the public GitHub REST API (no extra dependency).
class GithubService {
  GithubService({this.token = ''});

  String token;

  static const _api = 'https://api.github.com';

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ProjectsHub-Android',
        if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      };

  Future<dynamic> _getJson(String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse('$_api$path'));
      _headers.forEach(req.headers.set);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) {
        throw GithubException(
            'Introuvable sur GitHub (dépôt privé ? ajoute un jeton dans les réglages).');
      }
      if (res.statusCode == 401) {
        throw GithubException('Jeton GitHub invalide ou expiré.');
      }
      if (res.statusCode == 403 || res.statusCode == 429) {
        throw GithubException(
            'Limite de l\'API GitHub atteinte. Réessaie plus tard ou ajoute un jeton dans les réglages.');
      }
      if (res.statusCode >= 400) {
        throw GithubException('Erreur GitHub ${res.statusCode}');
      }
      return jsonDecode(body);
    } on SocketException {
      throw GithubException('Pas de connexion Internet.');
    } finally {
      client.close();
    }
  }

  /// Repositories of [user]. With a token for that same account, private
  /// repositories are listed too.
  Future<List<GithubRepo>> listRepos(String user) async {
    final List<dynamic> raw;
    if (token.trim().isNotEmpty) {
      raw = await _getJson('/user/repos?per_page=100&sort=pushed') as List;
    } else {
      raw = await _getJson('/users/${Uri.encodeComponent(user)}/repos?per_page=100&sort=pushed')
          as List;
    }
    final repos = raw
        .cast<Map<String, dynamic>>()
        .map((r) => GithubRepo(
              owner: (r['owner'] as Map)['login'] as String,
              name: r['name'] as String,
              description: r['description'] as String? ?? '',
              defaultBranch: r['default_branch'] as String? ?? 'main',
              isPrivate: r['private'] as bool? ?? false,
              pushedAt: DateTime.tryParse(r['pushed_at'] as String? ?? ''),
              language: r['language'] as String?,
            ))
        .toList();
    if (token.trim().isNotEmpty && user.trim().isNotEmpty) {
      // /user/repos also returns repos of orgs the user belongs to; keep the
      // requested account first.
      repos.sort((a, b) {
        final am = a.owner.toLowerCase() == user.toLowerCase() ? 0 : 1;
        final bm = b.owner.toLowerCase() == user.toLowerCase() ? 0 : 1;
        return am.compareTo(bm);
      });
    }
    return repos;
  }

  Future<List<String>> listBranches(String owner, String repo) async {
    final raw = await _getJson('/repos/$owner/$repo/branches?per_page=100') as List;
    return raw.map((b) => (b as Map)['name'] as String).toList();
  }

  /// SHA of the last commit of [branch].
  Future<String> latestSha(String owner, String repo, String branch) async {
    final j = await _getJson(
        '/repos/$owner/$repo/commits/${Uri.encodeComponent(branch)}') as Map;
    return j['sha'] as String;
  }

  Future<BranchScan> scanBranch(String owner, String repo, String branch) async {
    final j = await _getJson(
        '/repos/$owner/$repo/git/trees/${Uri.encodeComponent(branch)}?recursive=1') as Map;
    final paths = (j['tree'] as List)
        .cast<Map>()
        .where((e) => e['type'] == 'blob')
        .map((e) => e['path'] as String)
        .toList();
    return scanPaths(paths);
  }

  /// Pure helper (unit tested): classifies the files of a branch.
  static BranchScan scanPaths(List<String> paths) {
    final html = paths
        .where((p) => p.toLowerCase().endsWith('.html') || p.toLowerCase().endsWith('.htm'))
        .where((p) => !p.contains('node_modules/') && !p.startsWith('.'))
        .toList()
      ..sort((a, b) {
        int score(String p) {
          final depth = '/'.allMatches(p).length;
          final name = p.split('/').last.toLowerCase();
          return depth * 10 + (name == 'index.html' ? 0 : 1);
        }

        final s = score(a).compareTo(score(b));
        return s != 0 ? s : a.compareTo(b);
      });
    final pubspecs = paths.where((p) => p == 'pubspec.yaml' || p.endsWith('/pubspec.yaml'));
    final flutterApps = <String>[];
    for (final p in pubspecs) {
      final dir = p.contains('/') ? p.substring(0, p.lastIndexOf('/')) : '';
      final androidPrefix = dir.isEmpty ? 'android/' : '$dir/android/';
      if (paths.any((x) => x.startsWith(androidPrefix))) flutterApps.add(dir);
    }
    return BranchScan(htmlFiles: html, flutterApps: flutterApps, androidPackages: const []);
  }

  /// Reads the applicationId of an Android/Flutter app folder.
  Future<String?> findApplicationId(
      String owner, String repo, String branch, String appDir) async {
    final prefix = appDir.isEmpty ? '' : '$appDir/';
    for (final f in ['android/app/build.gradle.kts', 'android/app/build.gradle']) {
      try {
        final j = await _getJson(
            '/repos/$owner/$repo/contents/$prefix$f?ref=${Uri.encodeComponent(branch)}') as Map;
        final content =
            utf8.decode(base64.decode((j['content'] as String).replaceAll('\n', '')));
        final id = parseApplicationId(content);
        if (id != null) return id;
      } on GithubException {
        continue;
      }
    }
    return null;
  }

  static String? parseApplicationId(String gradle) {
    final m = RegExp(r'''applicationId\s*=?\s*["']([\w.]+)["']''').firstMatch(gradle);
    return m?.group(1);
  }

  /// .apk files attached to the repository's releases (newest first).
  Future<List<GithubApk>> listApks(String owner, String repo) async {
    final raw = await _getJson('/repos/$owner/$repo/releases?per_page=20') as List;
    final out = <GithubApk>[];
    for (final r in raw.cast<Map>()) {
      for (final a in (r['assets'] as List).cast<Map>()) {
        final name = a['name'] as String;
        if (name.toLowerCase().endsWith('.apk')) {
          out.add(GithubApk(
            name: name,
            url: a['browser_download_url'] as String,
            release: (r['name'] as String?)?.isNotEmpty == true
                ? r['name'] as String
                : r['tag_name'] as String,
          ));
        }
      }
    }
    return out;
  }

  /// Downloads the ZIP of [branch] into [dest], reporting progress 0..1
  /// (or null when the size is unknown, which GitHub usually doesn't send).
  Future<void> downloadZip(
    String owner,
    String repo,
    String branch,
    File dest, {
    void Function(int received, int? total)? onProgress,
  }) async {
    // codeload is faster and doesn't count against the API rate limit, but
    // only works for public repositories; private ones go through the API.
    final uri = token.trim().isEmpty
        ? Uri.parse(
            'https://codeload.github.com/$owner/$repo/zip/refs/heads/${Uri.encodeComponent(branch)}')
        : Uri.parse('$_api/repos/$owner/$repo/zipball/${Uri.encodeComponent(branch)}');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.getUrl(uri);
      _headers.forEach(req.headers.set);
      req.followRedirects = true;
      final res = await req.close();
      if (res.statusCode == 404) {
        throw GithubException(
            'Branche ou dépôt introuvable (dépôt privé ? ajoute un jeton dans les réglages).');
      }
      if (res.statusCode >= 400) {
        throw GithubException('Téléchargement impossible (${res.statusCode}).');
      }
      final total = res.contentLength > 0 ? res.contentLength : null;
      var received = 0;
      final sink = dest.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
    } on SocketException {
      throw GithubException('Pas de connexion Internet.');
    } finally {
      client.close();
    }
  }

  /// Accepts "owner/repo", "https://github.com/owner/repo", ".../tree/branch/sub/dir".
  static ({String owner, String repo, String? branch, String subdir})? parseRepoUrl(
      String input) {
    var s = input.trim();
    s = s.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'^www\.'), '');
    s = s.replaceFirst(RegExp(r'^github\.com/'), '');
    s = s.replaceFirst(RegExp(r'\.git$'), '');
    final parts = s.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return null;
    String? branch;
    var subdir = '';
    if (parts.length >= 4 && (parts[2] == 'tree' || parts[2] == 'blob')) {
      branch = parts[3];
      subdir = parts.skip(4).join('/');
    }
    return (owner: parts[0], repo: parts[1], branch: branch, subdir: subdir);
  }
}
