import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../state/hub_controller.dart';

class ReorderScreen extends StatelessWidget {
  const ReorderScreen({super.key, required this.hub});

  final HubController hub;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Réorganiser')),
        body: Column(children: [
          if (hub.settings.sortMode != SortMode.custom)
            MaterialBanner(
              content: Text('L\'accueil est trié par « ${hub.settings.sortMode.label} ». '
                  'Passe en « Mon ordre » pour utiliser cet ordre.'),
              actions: [
                TextButton(
                  onPressed: () {
                    hub.settings.sortMode = SortMode.custom;
                    hub.saveSettings();
                  },
                  child: const Text('Utiliser mon ordre'),
                ),
              ],
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: hub.projects.length,
              onReorderItem: hub.reorder,
              itemBuilder: (_, i) {
                final p = hub.projects[i];
                return Card(
                  key: ValueKey(p.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(p.color),
                      child: Text(p.emoji),
                    ),
                    title: Text(p.name),
                    subtitle: p.category.isEmpty ? null : Text(p.category),
                    trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
