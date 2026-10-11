import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/background_player.dart';
import 'services/native_bridge.dart';
import 'state/hub_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NativeBridge.init();
  BackgroundPlayer.instance; // routes media-notification buttons from now on
  final hub = await HubController.load();
  runApp(ProjectsHubApp(hub: hub));
}

class ProjectsHubApp extends StatelessWidget {
  const ProjectsHubApp({super.key, required this.hub});

  final HubController hub;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final seed = Color(hub.settings.seedColor);
        ThemeData theme(Brightness b) => ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
              cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
            );
        return MaterialApp(
          title: hub.settings.hubTitle,
          debugShowCheckedModeBanner: false,
          themeMode: hub.settings.themeMode,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          home: HomeScreen(hub: hub),
        );
      },
    );
  }
}
