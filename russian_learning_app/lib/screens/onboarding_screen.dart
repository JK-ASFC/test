import 'package:flutter/material.dart';
import '../models/course_level.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Cefr _level = Cefr.a1;
  int _goal = 10;

  Future<void> _finish() async {
    final progress = ProgressService.instance;
    await progress.setSelectedLevel(_level);
    await progress.setDailyGoalMinutes(_goal);
    await progress.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Привет! 👋', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Bienvenue sur RusPath. Apprends le russe de zéro (A1) jusqu\'au niveau professionnel (C1), à ton rythme.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              const Text('Quel est ton niveau actuel ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: Cefr.values.map((c) {
                  final selected = c == _level;
                  return ChoiceChip(
                    label: Text('${c.code} — ${c.title}'),
                    selected: selected,
                    selectedColor: c.color,
                    labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _level = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              const Text('Combien de minutes par jour ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [5, 10, 15, 20, 30].map((m) {
                  final selected = m == _goal;
                  return ChoiceChip(
                    label: Text('$m min'),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _goal = m),
                  );
                }).toList(),
              ),
              const Spacer(),
              ElevatedButton(onPressed: _finish, child: const Text('COMMENCER')),
            ],
          ),
        ),
      ),
    );
  }
}
