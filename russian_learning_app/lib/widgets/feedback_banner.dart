import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The green/red banner shown at the bottom of an exercise after the
/// learner submits an answer, Duolingo-style.
class FeedbackBanner extends StatelessWidget {
  final bool correct;
  final String? correctAnswerText;
  final VoidCallback onContinue;

  const FeedbackBanner({
    super.key,
    required this.correct,
    required this.onContinue,
    this.correctAnswerText,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.primary : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text(
                  correct ? 'Bien joué !' : 'Pas tout à fait...',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            if (!correct && correctAnswerText != null) ...[
              const SizedBox(height: 6),
              Text('Réponse : $correctAnswerText',
                  style: TextStyle(color: color, fontSize: 15)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(backgroundColor: color),
                child: const Text('CONTINUER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
