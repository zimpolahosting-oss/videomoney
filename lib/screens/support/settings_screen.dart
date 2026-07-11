import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestoreService = FirestoreService();

  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final settings = await _firestoreService.getUserSettings(user.uid);
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;
        _dailyReminderEnabled = settings['dailyReminderEnabled'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await NotificationService.instance.updateNotificationPreferences(
        uid: user.uid,
        notificationsEnabled: _notificationsEnabled,
        dailyReminderEnabled: _dailyReminderEnabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notifications,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                  title: Text(l10n.enableNotifications),
                  subtitle: Text(l10n.generalAppNotifications),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _dailyReminderEnabled,
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _dailyReminderEnabled = value);
                  },
                  title: Text(l10n.dailyReminder),
                  subtitle: Text(l10n.dailyReminderSubtitle),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.privacy,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);
                  },
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: Text(l10n.privacyPolicy),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.termsOfService);
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.termsOfService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primarySoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.appVersion,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '1.0.1+5',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving || _isLoading ? null : _save,
              child: Text(_isSaving ? l10n.saving : l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
