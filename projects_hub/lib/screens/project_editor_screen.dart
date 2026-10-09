import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/project_files.dart';
import '../state/hub_controller.dart';
import '../widgets/color_choice.dart';

const projectEmojis = [
  '🍔', '🇷🇺', '💼', '🎮', '🎲', '🧠', '❓', '🏆', '🎵', '🎬', '📚', '✏️',
  '🧪', '🧮', '🌐', '📱', '💻', '🖥️', '🛠️', '⚙️', '🚀', '⭐', '🔥', '💡',
  '🎨', '📷', '🗺️', '🏠', '🛒', '💬', '📊', '🔒', '🤖', '🐱', '⚽', '🍕',
];

/// Create or customise a project. Pops with the edited [Project] on save.
class ProjectEditorScreen extends StatefulWidget {
  const ProjectEditorScreen({super.key, required this.hub, required this.project, this.isNew = false});

  final HubController hub;
  final Project project;
  final bool isNew;

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final Project p = widget.project;

  late final _name = TextEditingController(text: p.name);
  late final _desc = TextEditingController(text: p.description);
  late final _emoji = TextEditingController(text: p.emoji);
  late final _category = TextEditingController(text: p.category);
  late final _owner = TextEditingController(text: p.owner);
  late final _repo = TextEditingController(text: p.repo);
  late final _branch = TextEditingController(text: p.branch);
  late final _subdir = TextEditingController(text: p.subdir);
  late final _entry = TextEditingController(text: p.entry);
  late final _url = TextEditingController(text: p.url ?? '');
  late final _pkg = TextEditingController(text: p.packageName ?? '');
  late final _apk = TextEditingController(text: p.apkUrl ?? '');

  List<String>? _branches;

  @override
  void initState() {
    super.initState();
    if (p.type == SourceType.github && p.owner.isNotEmpty && p.repo.isNotEmpty) _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final b = await widget.hub.github.listBranches(_owner.text.trim(), _repo.text.trim());
      if (mounted) setState(() => _branches = b);
    } catch (_) {
      if (mounted) setState(() => _branches = null);
    }
  }

  Future<void> _chooseEntry() async {
    List<String> pages;
    if (p.type == SourceType.github && !widget.hub.files.isDownloaded(p)) {
      try {
        final scan = await widget.hub.github.scanBranch(_owner.text.trim(), _repo.text.trim(), _branch.text.trim());
        final sub = _subdir.text.trim();
        pages = scan.htmlFiles
            .where((h) => sub.isEmpty || h.startsWith('$sub/'))
            .map((h) => sub.isEmpty ? h : h.substring(sub.length + 1))
            .toList();
      } catch (e) {
        _toast('$e');
        return;
      }
    } else {
      p.subdir = _subdir.text.trim();
      final root = widget.hub.files.serveRoot(p);
      pages = root == null ? [] : ProjectFiles.listHtml(root);
    }
    if (!mounted) return;
    if (pages.isEmpty) {
      _toast('Aucune page HTML trouvée.');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        builder: (ctx, sc) => ListView(controller: sc, children: [
          for (final h in pages)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(h),
              onTap: () => Navigator.pop(ctx, h),
            ),
        ]),
      ),
    );
    if (chosen != null) setState(() => _entry.text = chosen);
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final path = res.isEmpty ? null : res.first.path;
    if (path == null) return;
    final kept = await widget.hub.files.keepImage(path, 'cover_${p.id}');
    setState(() => p.coverPath = kept);
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Dossier du projet');
    if (path != null) setState(() => p.localPath = path);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _save() {
    if (!_form.currentState!.validate()) return;
    final sourceChanged = p.type == SourceType.github &&
        (p.owner != _owner.text.trim() || p.repo != _repo.text.trim() || p.branch != _branch.text.trim());
    p
      ..name = _name.text.trim()
      ..description = _desc.text.trim()
      ..emoji = _emoji.text.trim().isEmpty ? '📁' : _emoji.text.trim()
      ..category = _category.text.trim()
      ..owner = _owner.text.trim()
      ..repo = _repo.text.trim()
      ..branch = _branch.text.trim().isEmpty ? 'main' : _branch.text.trim()
      ..subdir = _subdir.text.trim().replaceAll(RegExp(r'^/+|/+$'), '')
      ..entry = _entry.text.trim().isEmpty ? 'index.html' : _entry.text.trim()
      ..url = _url.text.trim()
      ..packageName = _pkg.text.trim()
      ..apkUrl = _apk.text.trim();
    if (sourceChanged) {
      // Another repo/branch: force a fresh download on next open.
      p.installedSha = null;
      p.remoteSha = null;
      widget.hub.files.deleteProject(p.id);
    }
    Navigator.of(context).pop(p);
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    final color = Color(p.color);
    final cats = widget.hub.categories;
    InputDecoration deco(String label, {IconData? icon, String? hint, String? helper}) => InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        );
    const gap = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Nouveau projet' : 'Personnaliser'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Enregistrer')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Live preview
          Center(
            child: Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.45)!]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(_emoji.text, style: const TextStyle(fontSize: 56)),
            ),
          ),
          gap,
          TextFormField(controller: _name, decoration: deco('Nom', icon: Icons.title), validator: _required),
          gap,
          TextFormField(
            controller: _desc,
            decoration: deco('Description', icon: Icons.notes),
            maxLines: 2,
          ),
          gap,
          Text('Icône', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final e in projectEmojis)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _emoji.text = e),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _emoji.text == e ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emoji,
            decoration: deco('…ou n\'importe quel emoji / texte court', icon: Icons.emoji_emotions_outlined),
            maxLength: 4,
            onChanged: (_) => setState(() {}),
          ),
          Text('Couleur', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ColorChoice(selected: p.color, onChanged: (c) => setState(() => p.color = c)),
          gap,
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickCover,
                icon: const Icon(Icons.image_outlined),
                label: Text(p.coverPath == null ? 'Image de couverture' : 'Changer l\'image'),
              ),
            ),
            if (p.coverPath != null)
              IconButton(
                tooltip: 'Retirer l\'image',
                onPressed: () => setState(() => p.coverPath = null),
                icon: const Icon(Icons.close),
              ),
          ]),
          gap,
          TextFormField(controller: _category, decoration: deco('Catégorie', icon: Icons.label_outline, hint: 'Jeux, Web, École…')),
          if (cats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, children: [
                for (final c in cats)
                  ActionChip(label: Text(c), onPressed: () => setState(() => _category.text = c)),
              ]),
            ),
          const Divider(height: 36),
          Text('Source : ${p.type.label}', style: Theme.of(context).textTheme.titleMedium),
          gap,
          ..._sourceFields(deco, gap),
          if (p.isWeb) ...[
            const Divider(height: 36),
            Text('Affichage', style: Theme.of(context).textTheme.titleMedium),
            gap,
            SegmentedButton<PlayerOrientation>(
              segments: [
                for (final o in PlayerOrientation.values)
                  ButtonSegment(value: o, label: Text(o.label)),
              ],
              selected: {p.orientation},
              onSelectionChanged: (s) => setState(() => p.orientation = s.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Plein écran'),
              subtitle: const Text('Cache les barres (un petit bouton ⋮ reste pour le menu)'),
              value: p.fullscreen,
              onChanged: (v) => setState(() => p.fullscreen = v),
            ),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  List<Widget> _sourceFields(
    InputDecoration Function(String, {IconData? icon, String? hint, String? helper}) deco,
    Widget gap,
  ) {
    final entryField = TextFormField(
      controller: _entry,
      decoration: deco('Page d\'accueil', icon: Icons.home_outlined, hint: 'index.html').copyWith(
        suffixIcon: IconButton(icon: const Icon(Icons.list), tooltip: 'Choisir', onPressed: _chooseEntry),
      ),
    );
    switch (p.type) {
      case SourceType.github:
        return [
          Row(children: [
            Expanded(child: TextFormField(controller: _owner, decoration: deco('Compte'), validator: _required)),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _repo,
                decoration: deco('Dépôt'),
                validator: _required,
                onEditingComplete: _loadBranches,
              ),
            ),
          ]),
          gap,
          if (_branches != null && _branches!.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _branches!.contains(_branch.text) ? _branch.text : null,
              decoration: deco('Branche', icon: Icons.account_tree_outlined),
              items: [for (final b in _branches!) DropdownMenuItem(value: b, child: Text(b))],
              onChanged: (b) => setState(() => _branch.text = b ?? 'main'),
            )
          else
            TextFormField(controller: _branch, decoration: deco('Branche', icon: Icons.account_tree_outlined)),
          gap,
          TextFormField(
            controller: _subdir,
            decoration: deco('Sous-dossier (optionnel)',
                icon: Icons.folder_outlined, helper: 'Si le projet est dans un dossier du dépôt, ex : site/'),
          ),
          gap,
          entryField,
        ];
      case SourceType.localFolder:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(p.localPath ?? 'Aucun dossier'),
            trailing: TextButton(onPressed: _pickFolder, child: const Text('Changer')),
          ),
          gap,
          entryField,
        ];
      case SourceType.zipImport:
        return [
          const Text('Fichiers copiés dans l\'appli (hors-ligne).'),
          gap,
          TextFormField(controller: _subdir, decoration: deco('Sous-dossier (optionnel)', icon: Icons.folder_outlined)),
          gap,
          entryField,
        ];
      case SourceType.url:
        return [
          TextFormField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: deco('Adresse', icon: Icons.link,
                hint: 'https://moi.github.io/projet',
                helper: 'Site en ligne, GitHub Pages, ou ton PC sur le même Wi-Fi '
                    '(ex : http://192.168.1.20:8000 avec « python -m http.server »).'),
            validator: (v) => (v == null || v.trim().isEmpty || v.trim() == 'https://') ? 'Obligatoire' : null,
          ),
        ];
      case SourceType.androidApp:
        return [
          TextFormField(
            controller: _pkg,
            decoration: deco('Identifiant de l\'appli', icon: Icons.android, hint: 'com.exemple.appli'),
            validator: _required,
          ),
          gap,
          TextFormField(
            controller: _apk,
            keyboardType: TextInputType.url,
            decoration: deco('Lien de l\'APK (optionnel)',
                icon: Icons.download,
                helper: 'Proposé au téléchargement si l\'appli n\'est pas installée.'),
          ),
        ];
    }
  }
}
