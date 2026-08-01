import 'package:flutter/material.dart';
import '../services/srs_service.dart';
import '../theme/app_theme.dart';
import 'review_screen.dart';

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  @override
  Widget build(BuildContext context) {
    final srs = SrsService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Pratique')),
      body: AnimatedBuilder(
        animation: srs,
        builder: (context, _) {
          final due = srs.dueCards();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.style, color: AppColors.info, size: 40),
                      const SizedBox(height: 8),
                      Text('${due.length}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.info)),
                      const Text('mots à réviser aujourd\'hui'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: due.isEmpty
                              ? null
                              : () async {
                                  await Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ReviewScreen(cards: due),
                                  ));
                                  setState(() {});
                                },
                          child: const Text('COMMENCER LA RÉVISION'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('${srs.totalCount} mots dans ta banque de vocabulaire', style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                const Icon(Icons.psychology_alt, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'La répétition espacée te fait revoir chaque mot juste avant que tu ne l\'oublies.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
