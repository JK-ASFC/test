import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../services/notification_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final progress = ProgressService.instance;

  Future<void> _pickGoal() async {
    final options = [5, 10, 15, 20, 30];
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((m) => ListTile(
                    title: Text('$m minutes / jour'),
                    trailing: progress.dailyGoalMinutes == m ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(m),
                  ))
              .toList(),
        ),
      ),
    );
    if (choice != null) {
      await progress.setDailyGoalMinutes(choice);
      setState(() {});
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: progress.reminderTime);
    if (picked != null) {
      await progress.setReminderTime(picked);
      if (progress.notificationsEnabled) {
        await NotificationService.instance.scheduleDailyReminder(picked);
      }
      setState(() {});
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    await progress.setNotificationsEnabled(value);
    if (value) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleDailyReminder(progress.reminderTime);
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    setState(() {});
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réinitialiser la progression ?'),
        content: const Text('Toutes tes leçons, ton XP et ta série seront définitivement effacés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (ok == true) {
      await progress.resetAllProgress();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          return ListView(
            children: [
              const _SectionHeader('Objectif quotidien'),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Minutes par jour'),
                subtitle: Text('${progress.dailyGoalMinutes} minutes'),
                onTap: _pickGoal,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Rappel quotidien'),
                subtitle: const Text('Une notification pour ne pas rater ta série'),
                value: progress.notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
              if (progress.notificationsEnabled)
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Heure du rappel'),
                  subtitle: Text(progress.reminderTime.format(context)),
                  onTap: _pickReminderTime,
                ),
              const Divider(),
              const _SectionHeader('Audio'),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('Son automatique'),
                subtitle: const Text('Prononcer les mots russes automatiquement'),
                value: progress.soundEnabled,
                onChanged: (v) async {
                  await progress.setSoundEnabled(v);
                  setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Vitesse de la voix'),
                subtitle: Slider(
                  value: progress.ttsRate,
                  min: 0.2,
                  max: 0.7,
                  onChanged: (v) async {
                    await progress.setTtsRate(v);
                    setState(() {});
                  },
                ),
              ),
              const Divider(),
              const _SectionHeader('Apparence'),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Thème'),
                trailing: DropdownButton<ThemeMode>(
                  value: progress.themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Système')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await progress.setThemeMode(v);
                    setState(() {});
                  },
                ),
              ),
              const Divider(),
              const _SectionHeader('Données'),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Réinitialiser la progression', style: TextStyle(color: Colors.red)),
                onTap: _confirmReset,
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'RusPath — Apprends le russe hors-ligne, sans compte, sans publicité et sans abonnement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
      ),
    );
  }
}
