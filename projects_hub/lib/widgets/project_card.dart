import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/project.dart';
import '../state/hub_controller.dart';

IconData sourceIcon(SourceType t) => switch (t) {
      SourceType.github => Icons.code,
      SourceType.localFolder => Icons.folder_outlined,
      SourceType.zipImport => Icons.archive_outlined,
      SourceType.url => Icons.public,
      SourceType.androidApp => Icons.android,
    };

/// Big square-ish tile used in grid mode.
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.settings,
    required this.status,
    required this.offline,
    required this.onTap,
    required this.onLongPress,
  });

  final Project project;
  final AppSettings settings;
  final SyncStatus? status;
  final bool offline;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Color(project.color);
    final style = settings.cardStyle;
    final onColor = style == CardStyle.outlined
        ? scheme.onSurface
        : (ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black87);

    final decoration = switch (style) {
      CardStyle.gradient => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c, Color.lerp(c, Colors.black, 0.45)!],
          ),
        ),
      CardStyle.filled => BoxDecoration(color: c),
      CardStyle.outlined => BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: c, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
    };
    final hasCover = project.coverPath != null && File(project.coverPath!).existsSync();

    return Card(
      elevation: style == CardStyle.outlined ? 0 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: decoration,
          child: Stack(children: [
            if (hasCover)
              Positioned.fill(
                child: Image.file(File(project.coverPath!), fit: BoxFit.cover),
              ),
            if (hasCover)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!hasCover)
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (style == CardStyle.outlined ? c : Colors.white).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(project.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  const Spacer(),
                  if (project.favorite)
                    Icon(Icons.star_rounded, color: hasCover ? Colors.amber : onColor, size: 22),
                ]),
                const Spacer(),
                Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: hasCover ? Colors.white : onColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (settings.showDescriptions && project.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: (hasCover ? Colors.white : onColor).withValues(alpha: 0.85),
                        ),
                  ),
                ],
                if (settings.showSourceBadges) ...[
                  const SizedBox(height: 8),
                  _Badges(project: project, offline: offline, color: hasCover ? Colors.white : onColor),
                ],
              ]),
            ),
            if (status != null) Positioned.fill(child: _SyncOverlay(status: status!)),
          ]),
        ),
      ),
    );
  }
}

/// Row used in list mode.
class ProjectRow extends StatelessWidget {
  const ProjectRow({
    super.key,
    required this.project,
    required this.settings,
    required this.status,
    required this.offline,
    required this.onTap,
    required this.onLongPress,
    this.trailing,
  });

  final Project project;
  final AppSettings settings;
  final SyncStatus? status;
  final bool offline;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Color(project.color);
    final hasCover = project.coverPath != null && File(project.coverPath!).existsSync();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: c,
            child: hasCover
                ? Image.file(File(project.coverPath!), fit: BoxFit.cover, width: 48, height: 48)
                : Text(project.emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        title: Row(children: [
          Flexible(
            child: Text(project.name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (project.favorite) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
          ],
        ]),
        subtitle: status != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(status!.message),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: status!.progress),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (settings.showDescriptions && project.description.isNotEmpty)
                  Text(project.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (settings.showSourceBadges) ...[
                  const SizedBox(height: 4),
                  _Badges(
                      project: project,
                      offline: offline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ]),
        trailing: trailing,
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.project, required this.offline, required this.color});

  final Project project;
  final bool offline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(color: color);
    Widget chip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(child: Text(text, style: small, overflow: TextOverflow.ellipsis)),
        ]);
    final label = project.type == SourceType.github ? project.branch : project.type.label;
    return Wrap(spacing: 10, runSpacing: 2, children: [
      chip(sourceIcon(project.type), label),
      if (project.updateAvailable) chip(Icons.system_update_alt, 'Mise à jour'),
      if (project.type == SourceType.github && !offline) chip(Icons.cloud_download_outlined, 'À télécharger'),
    ]);
  }
}

class _SyncOverlay extends StatelessWidget {
  const _SyncOverlay({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(value: status.progress, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(status.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
  }
}
