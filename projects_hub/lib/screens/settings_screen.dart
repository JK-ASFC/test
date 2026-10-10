import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../state/hub_controller.dart';
import '../widgets/color_choice.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.hub});

  final HubController hub;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HubController get hub => widget.hub;
  AppSettings get s => hub.settings;

  late final _title = TextEditingController(text: s.hubTitle);
  late final _user = TextEditingController(text: s.githubUser);
  late final _token = TextEditingController(text: s.githubToken);
  bool _showToken = false;
  int? _size;

  @override
  void initState() {
    super.initState();
    hub.files.totalSize().then((v) {
      if (mounted) setState(() => _size = v);
    });
  }

  void _save() => hub.saveSettings();

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickBackground() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    final path = res.isEmpty ? null : res.first.path;
    if (path == null) return;
    s.backgroundImage = await hub.files.keepImage(path, 'wallpaper');
    _save();
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: hub.exportJson()));
    _toast('Configuration copiée dans le presse-papiers (sans ton jeton GitHub).');
  }

  Future<void> _import() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return _toast('Copie d\'abord une configuration exportée.');
    try {
      final n = await hub.importJson(text);
      _title.text = s.hubTitle;
      _user.text = s.githubUser;
      _toast('$n projet(s) importé(s).');
    } catch (e) {
      _toast('Configuration invalide : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(t,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        );

    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Personnaliser')),
        body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          section('Apparence'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre de l\'accueil', border: OutlineInputBorder()),
              onChanged: (v) {
                s.hubTitle = v.trim().isEmpty ? 'Mes Projets' : v.trim();
                _save();
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Clair')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Sombre')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) {
                s.themeMode = v.first;
                _save();
              },
            ),
          ),
          const ListTile(title: Text('Couleur principale')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ColorChoice(
              selected: s.seedColor,
              onChanged: (c) {
                s.seedColor = c;
                _save();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Fond d\'écran de l\'accueil'),
            subtitle: Text(s.backgroundImage == null ? 'Aucun' : 'Image personnalisée'),
            trailing: s.backgroundImage == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      s.backgroundImage = null;
                      _save();
                    },
                  ),
            onTap: _pickBackground,
          ),
          section('Cartes des projets'),
          ListTile(
            title: const Text('Affichage'),
            trailing: SegmentedButton<HubLayout>(
              segments: const [
                ButtonSegment(value: HubLayout.grid, icon: Icon(Icons.grid_view_rounded)),
                ButtonSegment(value: HubLayout.list, icon: Icon(Icons.view_list_rounded)),
              ],
              selected: {s.layout},
              onSelectionChanged: (v) {
                s.layout = v.first;
                _save();
              },
            ),
          ),
          if (s.layout == HubLayout.grid)
            ListTile(
              title: const Text('Colonnes'),
              subtitle: Slider(
                value: s.gridColumns.toDouble(),
                min: 1,
                max: 4,
                divisions: 3,
                label: '${s.gridColumns}',
                onChanged: (v) {
                  s.gridColumns = v.round();
                  _save();
                },
              ),
            ),
          ListTile(
            title: const Text('Style'),
            trailing: DropdownButton<CardStyle>(
              value: s.cardStyle,
              items: [
                for (final c in CardStyle.values) DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) {
                s.cardStyle = v!;
                _save();
              },
            ),
          ),
          ListTile(
            title: const Text('Trier par'),
            trailing: DropdownButton<SortMode>(
              value: s.sortMode,
              items: [
                for (final m in SortMode.values) DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) {
                s.sortMode = v!;
                _save();
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Afficher les descriptions'),
            value: s.showDescriptions,
            onChanged: (v) {
              s.showDescriptions = v;
              _save();
            },
          ),
          SwitchListTile(
            title: const Text('Afficher la source (branche, dossier…)'),
            value: s.showSourceBadges,
            onChanged: (v) {
              s.showSourceBadges = v;
              _save();
            },
          ),
          section('GitHub'),
          SwitchListTile(
            title: const Text('Mise à jour automatique'),
            subtitle: const Text('Télécharge le dernier commit de la branche à l\'ouverture d\'un projet'),
            value: s.autoUpdate,
            onChanged: (v) {
              s.autoUpdate = v;
              _save();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Compte GitHub',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                s.githubUser = v.trim();
                _save();
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _token,
              obscureText: !_showToken,
              decoration: InputDecoration(
                labelText: 'Jeton d\'accès (optionnel)',
                helperText: 'Pour les dépôts privés. GitHub → Settings → Developer settings → '
                    'Fine-grained tokens, accès « Contents: Read-only ». Stocké uniquement sur ce téléphone.',
                helperMaxLines: 4,
                prefixIcon: const Icon(Icons.key_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showToken = !_showToken),
                ),
              ),
              onChanged: (v) {
                s.githubToken = v.trim();
                _save();
              },
            ),
          ),
          section('Sauvegarde'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Exporter ma configuration'),
            subtitle: const Text('Copie projets + personnalisation (à coller dans une note, un mail…)'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Importer une configuration'),
            subtitle: const Text('Depuis le presse-papiers'),
            onTap: _import,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurer les projets d\'origine'),
            subtitle: const Text('Burger Quiz, RusPath, Portfolio, Fondu musique'),
            onTap: () async {
              await hub.restoreDefaults();
              _toast('Projets d\'origine restaurés.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Vider les téléchargements GitHub'),
            subtitle: Text(_size == null
                ? 'Calcul…'
                : '${(_size! / 1024 / 1024).toStringAsFixed(1)} Mo utilisés · re-téléchargés à la prochaine ouverture'),
            onTap: () async {
              await hub.clearDownloads();
              final v = await hub.files.totalSize();
              if (mounted) setState(() => _size = v);
            },
          ),
        ]),
      ),
    );
  }
}
