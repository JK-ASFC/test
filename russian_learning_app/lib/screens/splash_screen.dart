import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../services/srs_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ProgressService.instance.init();
    await SrsService.instance.init();
    if (!mounted) return;
    final next = ProgressService.instance.onboardingDone ? const HomeScreen() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🇷🇺', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('RusPath', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
