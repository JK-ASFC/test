import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/progress_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RusPathApp());
}

class RusPathApp extends StatelessWidget {
  const RusPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProgressService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'RusPath',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ProgressService.instance.ready ? ProgressService.instance.themeMode : ThemeMode.system,
          home: const SplashScreen(),
        );
      },
    );
  }
}
