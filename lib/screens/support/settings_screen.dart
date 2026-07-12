import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_language_service.dart';
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
  String _selectedLanguageCode = AppLanguageService.automaticValue;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _selectedLanguageCode =
        AppLanguageService.instance.selectedLanguageCodeOrAuto;
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
      await AppLanguageService.instance.setPreferredLanguageCode(
        _selectedLanguageCode == AppLanguageService.automaticValue
            ? null
            : _selectedLanguageCode,
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

  String _currentLanguageLabel(AppLocalizations l10n) {
    if (_selectedLanguageCode == AppLanguageService.automaticValue) {
      return l10n.automaticLanguage;
    }

    for (final option in AppLanguageService.instance.supportedLanguageOptions) {
      if (option.code == _selectedLanguageCode) {
        return option.label;
      }
    }

    return l10n.automaticLanguage;
  }

  Future<void> _showLanguagePicker(AppLocalizations l10n) async {
    if (_isSaving) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final languageOptions =
            AppLanguageService.instance.supportedLanguageOptions;

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      l10n.appLanguage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Icon(
                      _selectedLanguageCode == AppLanguageService.automaticValue
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(l10n.automaticLanguage),
                    onTap: () {
                      Navigator.of(sheetContext)
                          .pop(AppLanguageService.automaticValue);
                    },
                  ),
                  const SizedBox(height: 6),
                  ...languageOptions.map(
                    (option) => ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(
                        _selectedLanguageCode == option.code
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop(option.code);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _selectedLanguageCode = selected);
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
                  l10n.appLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appLanguageSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isSaving ? null : () => _showLanguagePicker(l10n),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.language_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                    ),
                    child: Text(
                      _currentLanguageLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  '1.0.1+6',
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
