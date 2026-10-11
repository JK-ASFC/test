import 'package:flutter/material.dart';

import '../services/background_player.dart';
import '../services/launcher.dart';
import '../state/hub_controller.dart';

/// Bar shown at the bottom of the hub while the music player runs in the
/// background: what's playing, ⏮ ⏯ ⏭, ✕ to stop; tap to reopen the player.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.hub});

  final HubController hub;

  @override
  Widget build(BuildContext context) {
    final bg = BackgroundPlayer.instance;
    return ListenableBuilder(
      listenable: bg,
      builder: (context, _) {
        final session = bg.session;
        final now = session?.nowPlaying.value;
        if (!bg.showMiniPlayer || session == null || now == null) return const SizedBox.shrink();
        final project = hub.byId(session.project.id) ?? session.project;
        final color = Color(project.color);
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Material(
              color: scheme.surfaceContainerHigh,
              elevation: 6,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openProject(context, hub, project),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.pink, 0.5)!]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(project.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(now.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          now.playing ? '${now.artist} · en arrière-plan' : '${now.artist} · en pause',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Précédent',
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: () => bg.action('prev'),
                    ),
                    IconButton.filled(
                      tooltip: now.playing ? 'Pause' : 'Lecture',
                      style: IconButton.styleFrom(backgroundColor: color),
                      icon: Icon(now.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      onPressed: () => bg.action(now.playing ? 'pause' : 'play'),
                    ),
                    IconButton(
                      tooltip: 'Suivant',
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => bg.action('next'),
                    ),
                    IconButton(
                      tooltip: 'Arrêter la musique',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: bg.stop,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
