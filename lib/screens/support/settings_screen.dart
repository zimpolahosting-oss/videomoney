import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
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

  void _showProductionLinkMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label link can be added in the production build.'),
      ),
    );
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUserSettings(
        uid: user.uid,
        notificationsEnabled: _notificationsEnabled,
        dailyReminderEnabled: _dailyReminderEnabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                  title: const Text('Enable notifications'),
                  subtitle: const Text('General app notifications'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _dailyReminderEnabled,
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _dailyReminderEnabled = value);
                  },
                  title: const Text('Daily reminder'),
                  subtitle: const Text('Get a reminder to complete daily bonus'),
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
                  'Privacy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Links can be configured for your production build.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showProductionLinkMessage('Privacy Policy'),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy Policy'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showProductionLinkMessage('Terms of Service'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Terms of Service'),
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
                    'App version',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  'v1.3',
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
              child: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
