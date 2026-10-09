import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/project.dart';
import '../services/launcher.dart';
import '../services/native_bridge.dart';
import '../services/project_files.dart';
import '../state/hub_controller.dart';
import '../widgets/project_card.dart';
import 'github_browser_screen.dart';
import 'project_editor_screen.dart';
import 'reorder_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.hub});

  final HubController hub;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HubController get hub => widget.hub;

  String _query = '';
  bool _searching = false;

  /// null = all, '★' = favorites, otherwise a category name.
  String? _category;

  @override
  void initState() {
    super.initState();
    hub.checkUpdates();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _open(Project p) async {
    if (hub.syncing.containsKey(p.id)) return;
    await openProject(context, hub, p);
  }

  Future<void> _edit(Project p, {bool isNew = false}) async {
    final saved = await Navigator.of(context).push<Project>(MaterialPageRoute(
      builder: (_) => ProjectEditorScreen(hub: hub, project: p.copy(), isNew: isNew),
    ));
    if (saved == null) {
      if (isNew && p.type == SourceType.zipImport) await hub.files.deleteProject(p.id);
      return;
    }
    await hub.upsert(saved);
    if (isNew && saved.type == SourceType.github) {
      hub.sync(saved).catchError((Object e) {
        if (mounted) _toast('Téléchargement de ${saved.name} impossible : $e');
      });
    }
  }

  Future<void> _sync(Project p) async {
    try {
      await hub.sync(p);
      if (mounted) _toast('${p.name} est à jour.');
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  void _actions(Project p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Text(p.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p.sourceSummary, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Ouvrir'),
              onTap: () {
                Navigator.pop(ctx);
                _open(p);
              },
            ),
            if (p.type == SourceType.github)
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(hub.files.isDownloaded(p) ? 'Mettre à jour depuis GitHub' : 'Télécharger'),
                subtitle: p.lastSync == null ? null : Text('Dernière synchro : ${_date(p.lastSync!)}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sync(p);
                },
              ),
            if (p.type == SourceType.androidApp && p.apkUrl?.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Télécharger / mettre à jour l\'APK'),
                onTap: () {
                  Navigator.pop(ctx);
                  NativeBridge.openUrl(p.apkUrl!);
                },
              ),
            ListTile(
              leading: Icon(p.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(p.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris'),
              onTap: () {
                Navigator.pop(ctx);
                hub.toggleFavorite(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Personnaliser / modifier'),
              onTap: () {
                Navigator.pop(ctx);
                _edit(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Dupliquer (ex : autre branche)'),
              onTap: () {
                Navigator.pop(ctx);
                final copy = p.copy(id: HubController.newId())
                  ..name = '${p.name} (copie)'
                  ..installedSha = null
                  ..openCount = 0
                  ..lastOpened = null;
                _edit(copy, isNew: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Supprimer', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Supprimer « ${p.name} » ?'),
                    content: Text(p.type == SourceType.localFolder
                        ? 'Le projet est retiré de l\'appli. Ton dossier sur le téléphone n\'est pas touché.'
                        : 'Le projet et sa copie sur le téléphone seront supprimés.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                    ],
                  ),
                );
                if (ok == true) await hub.remove(p);
              },
            ),
          ]),
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---------- Adding projects ----------

  void _addMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget item(IconData icon, String title, String sub, Future<void> Function() action) => ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(title),
              subtitle: Text(sub),
              onTap: () {
                Navigator.pop(ctx);
                action();
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Ajouter un projet', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              item(Icons.code, 'Depuis GitHub', 'Un dépôt et une branche, mis à jour automatiquement', _addGithub),
              item(Icons.folder_outlined, 'Dossier du téléphone', 'Un dossier HTML déjà sur l\'appareil', _addFolder),
              item(Icons.archive_outlined, 'Importer un ZIP', 'Copié dans l\'appli, fonctionne hors-ligne', _addZip),
              item(Icons.public, 'Site ou serveur distant',
                  'GitHub Pages, ton PC sur le Wi-Fi (http://192.168…)', () => _addSimple(SourceType.url)),
              item(Icons.android, 'Application Android', 'Lancer une appli installée (ex : RusPath)',
                  () => _addSimple(SourceType.androidApp)),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _addGithub() async {
    final draft = await Navigator.of(context).push<Project>(MaterialPageRoute(
      builder: (_) => GithubBrowserScreen(hub: hub),
    ));
    if (draft != null) await _edit(draft, isNew: true);
  }

  Future<void> _addFolder() async {
    if (Platform.isAndroid && !await NativeBridge.hasAllFilesAccess()) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accès aux fichiers'),
          content: const Text(
              'Pour lire un dossier de ton téléphone, Mes Projets a besoin de « Accès à tous les fichiers ». '
              'Active-le dans l\'écran qui va s\'ouvrir, puis reviens et appuie à nouveau sur « Dossier du téléphone ».\n\n'
              'Astuce : sans cette autorisation, utilise « Importer un ZIP ».'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Autoriser')),
          ],
        ),
      );
      if (go == true) await NativeBridge.requestAllFilesAccess();
      return;
    }
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Dossier du projet');
    if (path == null) return;
    final pages = ProjectFiles.listHtml(path);
    final name = path.split('/').where((s) => s.isNotEmpty).last;
    await _edit(
      Project(
        id: HubController.newId(),
        name: name,
        type: SourceType.localFolder,
        localPath: path,
        entry: pages.isNotEmpty ? pages.first : 'index.html',
        emoji: '📂',
        color: 0xFF00897B,
      ),
      isNew: true,
    );
  }

  Future<void> _addZip() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = res.isEmpty ? null : res.first.path;
    if (path == null) return;
    final id = HubController.newId();
    try {
      await hub.files.installZip(id, File(path));
    } catch (e) {
      _toast('ZIP illisible : $e');
      return;
    }
    final root = hub.files.contentDir(id).path;
    final pages = ProjectFiles.listHtml(root);
    final name = res.first.name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
    await _edit(
      Project(
        id: id,
        name: name,
        type: SourceType.zipImport,
        entry: pages.isNotEmpty ? pages.first : 'index.html',
        emoji: '🗜️',
        color: 0xFF8E24AA,
      ),
      isNew: true,
    );
  }

  Future<void> _addSimple(SourceType type) => _edit(
        Project(
          id: HubController.newId(),
          name: type == SourceType.url ? 'Mon site' : 'Mon appli',
          type: type,
          emoji: type == SourceType.url ? '🌐' : '📱',
          color: type == SourceType.url ? 0xFF1E88E5 : 0xFF43A047,
          url: type == SourceType.url ? 'https://' : null,
        ),
        isNew: true,
      );

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final s = hub.settings;
        final cats = hub.categories;
        if (_category != null && _category != '★' && !cats.contains(_category)) _category = null;
        final list = hub.visible(query: _query, category: _category);
        final hasFav = hub.projects.any((p) => p.favorite);
        final bg = s.backgroundImage;

        final content = RefreshIndicator(
          onRefresh: hub.checkUpdates,
          child: CustomScrollView(slivers: [
            SliverAppBar.large(
              backgroundColor: bg != null ? Colors.transparent : null,
              title: _searching
                  ? TextField(
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Rechercher un projet…', border: InputBorder.none),
                      onChanged: (v) => setState(() => _query = v),
                    )
                  : Text(s.hubTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    _query = '';
                  }),
                ),
                IconButton(
                  icon: Icon(s.layout == HubLayout.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  tooltip: 'Changer l\'affichage',
                  onPressed: () {
                    s.layout = s.layout == HubLayout.grid ? HubLayout.list : HubLayout.grid;
                    hub.saveSettings();
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'reorder':
                        await Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => ReorderScreen(hub: hub)));
                      case 'updates':
                        await hub.checkUpdates();
                        final n = hub.projects.where((p) => p.updateAvailable).length;
                        _toast(n == 0 ? 'Tout est à jour.' : '$n mise(s) à jour disponible(s).');
                      case 'settings':
                        await Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(hub: hub)));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'reorder', child: Text('Réorganiser')),
                    PopupMenuItem(value: 'updates', child: Text('Vérifier les mises à jour')),
                    PopupMenuItem(value: 'settings', child: Text('Personnaliser l\'appli')),
                  ],
                ),
              ],
            ),
            if (cats.isNotEmpty || hasFav)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in [null, if (hasFav) '★', ...cats])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c == null ? 'Tous' : c == '★' ? '★ Favoris' : c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🗂️', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text(_query.isEmpty ? 'Aucun projet pour l\'instant' : 'Aucun résultat',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_query.isEmpty)
                        const Text('Appuie sur « Ajouter » pour importer un projet GitHub, un dossier ou un site.',
                            textAlign: TextAlign.center),
                    ]),
                  ),
                ),
              )
            else if (s.layout == HubLayout.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: s.gridColumns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: switch (s.gridColumns) { 1 => 1.9, 2 => 0.8, 3 => 0.62, _ => 0.55 },
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ProjectTile(
                    project: list[i],
                    settings: s,
                    status: hub.syncing[list[i].id],
                    offline: hub.isAvailableOffline(list[i]),
                    onTap: () => _open(list[i]),
                    onLongPress: () => _actions(list[i]),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => ProjectRow(
                    project: list[i],
                    settings: s,
                    status: hub.syncing[list[i].id],
                    offline: hub.isAvailableOffline(list[i]),
                    onTap: () => _open(list[i]),
                    onLongPress: () => _actions(list[i]),
                    trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _actions(list[i])),
                  ),
                ),
              ),
          ]),
        );

        return Scaffold(
          body: bg != null && File(bg).existsSync()
              ? Stack(children: [
                  Positioned.fill(child: Image.file(File(bg), fit: BoxFit.cover)),
                  Positioned.fill(
                    child: ColoredBox(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55)),
                  ),
                  content,
                ])
              : content,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addMenu,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        );
      },
    );
  }
}
