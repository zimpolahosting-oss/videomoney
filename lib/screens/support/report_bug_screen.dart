import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.submitBugReport(
        uid: user.uid,
        email: user.email ?? '',
        title: _titleController.text,
        description: _descController.text,
      );

      if (!mounted) return;
      _titleController.clear();
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bugReportSubmitted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportBug)),
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
                  l10n.tellUsWhatHappened,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.includeStepsExpected,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.title,
                    hintText: l10n.shortSummary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    hintText: l10n.describeBug,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(_isSubmitting ? l10n.sending : l10n.submit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.inbox);
                        },
                        icon: const Icon(Icons.inbox_outlined),
                        label: Text(l10n.openInbox),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
