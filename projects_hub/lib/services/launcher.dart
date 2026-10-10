import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../screens/player_screen.dart';
import '../state/hub_controller.dart';
import 'local_server.dart';
import 'music_library.dart';
import 'native_bridge.dart';

/// Kept for the whole session so the music scan is only redone on demand.
MusicLibrary? _music;

/// Opens a project whatever its source: launches the Android app, or makes
/// sure the files are on the phone, serves them and shows them full screen.
Future<void> openProject(BuildContext context, HubController hub, Project project) async {
  final messenger = ScaffoldMessenger.of(context);
  void toast(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));

  if (project.type == SourceType.androidApp) {
    final ok = await NativeBridge.launchApp(project.packageName ?? '');
    if (ok) {
      await hub.markOpened(project);
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${project.name} n\'est pas installée'),
        content: Text(project.apkUrl?.isNotEmpty == true
            ? 'Télécharge l\'APK puis installe-le (autorise « Sources inconnues » si Android le demande). '
                'Reviens ensuite ici pour l\'ouvrir.'
            : 'Aucune application avec l\'identifiant « ${project.packageName} » n\'a été trouvée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (project.apkUrl?.isNotEmpty == true)
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Télécharger l\'APK'),
              onPressed: () {
                Navigator.pop(ctx);
                NativeBridge.openUrl(project.apkUrl!);
              },
            ),
        ],
      ),
    );
    return;
  }

  String url;
  if (project.type == SourceType.url) {
    url = project.url?.trim() ?? '';
    if (url.isEmpty) return toast('Aucune adresse renseignée.');
    if (!url.contains('://')) url = 'https://$url';
  } else {
    if (project.type == SourceType.github) {
      final ready = await _ensureGithubCopy(hub, project, toast);
      if (!ready) return;
    }
    if (project.type == SourceType.builtin) {
      try {
        await hub.files.installBuiltin(project);
      } catch (e) {
        return toast('$e');
      }
    }
    if (project.type == SourceType.localFolder && Platform.isAndroid) {
      if (!await NativeBridge.hasAllFilesAccess()) {
        if (!context.mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Accès aux fichiers'),
            content: const Text(
                'Pour ouvrir un dossier du téléphone, autorise « Accès à tous les fichiers » pour Mes Projets, puis reviens et réessaie.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Autoriser')),
            ],
          ),
        );
        if (go == true) await NativeBridge.requestAllFilesAccess();
        return;
      }
    }
    final root = hub.files.serveRoot(project);
    if (root == null) {
      return toast(switch (project.type) {
        SourceType.localFolder => 'Dossier introuvable : ${project.localPath}',
        SourceType.github when project.subdir.isNotEmpty =>
          'Le sous-dossier « ${project.subdir} » n\'existe pas dans la branche.',
        _ => 'Fichiers du projet introuvables.',
      });
    }
    // Only built-in apps get to see the phone's music library.
    final music = project.type == SourceType.builtin
        ? (_music ??= MusicLibrary(
            roots: Platform.isAndroid ? MusicLibrary.androidRoots() : [Platform.environment['HOME'] ?? '/'],
            hasPermission: Platform.isAndroid ? NativeBridge.hasAllFilesAccess : null,
          ))
        : null;
    final server = await LocalServer.start(root, LocalServer.portFor(project.id), music: music);
    final entry = project.entry.trim().replaceFirst(RegExp(r'^/+'), '');
    url = '${server.origin}/${entry.split('/').map(Uri.encodeComponent).join('/')}';
  }

  await hub.markOpened(project);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PlayerScreen(project: project, url: url),
  ));
  await LocalServer.stopCurrent();
}

/// Downloads the branch if it isn't on the phone yet, or if a newer commit
/// exists and auto-update is on. Returns false if nothing can be shown.
Future<bool> _ensureGithubCopy(
    HubController hub, Project p, void Function(String) toast) async {
  final hasCopy = hub.files.isDownloaded(p);
  if (hasCopy && !hub.settings.autoUpdate) return true;
  if (hasCopy) {
    try {
      final sha = await hub.github
          .latestSha(p.owner, p.repo, p.branch)
          .timeout(const Duration(seconds: 4));
      p.remoteSha = sha;
      if (sha == p.installedSha) return true;
    } catch (_) {
      return true; // offline: use the copy we have
    }
  }
  try {
    await hub.sync(p);
    return true;
  } catch (e) {
    toast(hasCopy
        ? 'Mise à jour impossible ($e). Ouverture de la version enregistrée.'
        : '${p.owner}/${p.repo} (${p.branch}) : $e');
    return hasCopy;
  }
}
