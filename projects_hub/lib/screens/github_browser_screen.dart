import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/github_service.dart';
import '../state/hub_controller.dart';

const _palette = [
  0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1, 0xFF3949AB, 0xFF1E88E5,
  0xFF00ACC1, 0xFF00897B, 0xFF43A047, 0xFFC0CA33, 0xFFFFB300, 0xFFF4511E,
];

/// Lists the user's repositories and lets them pick a repo + branch + page.
/// Pops with a draft [Project].
class GithubBrowserScreen extends StatefulWidget {
  const GithubBrowserScreen({super.key, required this.hub});

  final HubController hub;

  @override
  State<GithubBrowserScreen> createState() => _GithubBrowserScreenState();
}

class _GithubBrowserScreenState extends State<GithubBrowserScreen> {
  late final _user = TextEditingController(text: widget.hub.settings.githubUser);
  final _link = TextEditingController();
  List<GithubRepo>? _repos;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_user.text.isNotEmpty) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = await widget.hub.github.listRepos(_user.text.trim());
      if (widget.hub.settings.githubUser != _user.text.trim()) {
        widget.hub.settings.githubUser = _user.text.trim();
        widget.hub.saveSettings();
      }
      setState(() => _repos = repos);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRepo(String owner, String repo, {String? branch, String subdir = ''}) async {
    final draft = await Navigator.of(context).push<Project>(MaterialPageRoute(
      builder: (_) => _RepoScreen(hub: widget.hub, owner: owner, repo: repo, branch: branch, subdir: subdir),
    ));
    if (draft != null && mounted) Navigator.of(context).pop(draft);
  }

  void _openLink() {
    final r = GithubService.parseRepoUrl(_link.text);
    if (r == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lien GitHub non reconnu (ex : github.com/moi/projet)')));
      return;
    }
    _openRepo(r.owner, r.repo, branch: r.branch, subdir: r.subdir);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projet GitHub')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _link,
          decoration: InputDecoration(
            labelText: 'Coller un lien GitHub (optionnel)',
            hintText: 'github.com/JK-ASFC/SW/tree/main',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _openLink),
          ),
          onSubmitted: (_) => _openLink(),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Compte GitHub',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _loading ? null : _load, child: const Text('Charger')),
        ]),
        if (widget.hub.settings.githubToken.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Dépôts publics seulement. Ajoute un jeton GitHub dans Personnaliser → GitHub '
                'pour voir aussi tes dépôts privés.',
                style: TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          ),
        for (final r in _repos ?? const <GithubRepo>[])
          Card(
            child: ListTile(
              leading: Icon(r.isPrivate ? Icons.lock_outline : Icons.book_outlined),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([
                if (r.description.isNotEmpty) r.description,
                [if (r.language != null) r.language!, 'branche ${r.defaultBranch}'].join(' · '),
              ].join('\n')),
              isThreeLine: r.description.isNotEmpty,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openRepo(r.owner, r.name),
            ),
          ),
      ]),
    );
  }
}

class _RepoScreen extends StatefulWidget {
  const _RepoScreen({
    required this.hub,
    required this.owner,
    required this.repo,
    this.branch,
    this.subdir = '',
  });

  final HubController hub;
  final String owner;
  final String repo;
  final String? branch;
  final String subdir;

  @override
  State<_RepoScreen> createState() => _RepoScreenState();
}

class _RepoScreenState extends State<_RepoScreen> {
  GithubService get gh => widget.hub.github;

  List<String> _branches = [];
  String? _branch;
  BranchScan? _scan;
  List<GithubApk> _apks = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final branches = await gh.listBranches(widget.owner, widget.repo);
      _branches = branches;
      _branch = widget.branch != null && branches.contains(widget.branch)
          ? widget.branch
          : (branches.contains('main') ? 'main' : (branches.isNotEmpty ? branches.first : null));
      try {
        _apks = await gh.listApks(widget.owner, widget.repo);
      } catch (_) {}
      await _scanBranch();
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _scanBranch() async {
    if (_branch == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scan = await gh.scanBranch(widget.owner, widget.repo, _branch!);
      setState(() => _scan = scan);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _color => _palette[widget.repo.hashCode.abs() % _palette.length];

  void _pickHtml(String path) {
    // Serve from the repository root (or the linked sub-folder) so links
    // going up a level (../assets/...) keep working; the page is the entry.
    final slash = path.lastIndexOf('/');
    final dir = slash < 0 ? '' : path.substring(0, slash);
    final file = slash < 0 ? path : path.substring(slash + 1);
    final subdir = widget.subdir;
    final entry = subdir.isEmpty ? path : path.substring(subdir.length + 1);
    Navigator.of(context).pop(Project(
      id: HubController.newId(),
      name: _prettyName(dir.isEmpty ? widget.repo : dir.split('/').last, file),
      type: SourceType.github,
      owner: widget.owner,
      repo: widget.repo,
      branch: _branch!,
      subdir: subdir,
      entry: entry,
      emoji: '🌐',
      color: _color,
      category: 'Web',
    ));
  }

  Future<void> _pickApp(String appDir) async {
    setState(() => _loading = true);
    final id = await gh.findApplicationId(widget.owner, widget.repo, _branch!, appDir);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop(Project(
      id: HubController.newId(),
      name: _prettyName(appDir.isEmpty ? widget.repo : appDir, ''),
      type: SourceType.androidApp,
      owner: widget.owner,
      repo: widget.repo,
      branch: _branch!,
      packageName: id ?? '',
      apkUrl: _apks.isNotEmpty ? _apks.first.url : null,
      emoji: '📱',
      color: _color,
      category: 'Applis',
    ));
  }

  static String _prettyName(String folder, String file) {
    var base = folder;
    final f = file.replaceFirst(RegExp(r'\.html?$'), '');
    if (f.isNotEmpty && f != 'index') base = folder == f ? f : '$folder · $f';
    base = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return base.isEmpty ? folder : base[0].toUpperCase() + base.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    var html = scan?.htmlFiles ?? const <String>[];
    if (widget.subdir.isNotEmpty) {
      html = html.where((h) => h.startsWith('${widget.subdir}/')).toList();
    }
    return Scaffold(
      appBar: AppBar(title: Text('${widget.owner}/${widget.repo}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_branches.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _branch,
            decoration: const InputDecoration(
              labelText: 'Branche',
              prefixIcon: Icon(Icons.account_tree_outlined),
              border: OutlineInputBorder(),
            ),
            items: [for (final b in _branches) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (b) {
              _branch = b;
              _scanBranch();
            },
          ),
        if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          ),
        if (!_loading && scan != null) ...[
          if (scan.flutterApps.isNotEmpty || _apks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Applications Android', style: Theme.of(context).textTheme.titleMedium),
            for (final a in scan.flutterApps)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.android),
                  title: Text(a.isEmpty ? widget.repo : a),
                  subtitle: Text(_apks.isEmpty
                      ? 'Appli Flutter/Android (à installer)'
                      : 'APK disponible : ${_apks.first.release}'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _pickApp(a),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('Pages HTML (${html.length})', style: Theme.of(context).textTheme.titleMedium),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Choisis la page d\'accueil du projet. Tu pourras la changer ensuite.',
                style: TextStyle(fontSize: 12)),
          ),
          if (html.isEmpty)
            const Card(child: ListTile(title: Text('Aucune page HTML dans cette branche.'))),
          for (final h in html)
            Card(
              child: ListTile(
                leading: Icon(h.endsWith('index.html') ? Icons.home_outlined : Icons.description_outlined),
                title: Text(h),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => _pickHtml(h),
              ),
            ),
        ],
      ]),
    );
  }
}
