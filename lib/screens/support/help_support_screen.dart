import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/support_ticket.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.submitSupportTicket(
        uid: user.uid,
        email: user.email ?? '',
        type: 'support',
        subject: _subjectController.text,
        message: _messageController.text,
      );

      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportMessageSent)),
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
      appBar: AppBar(title: Text(l10n.helpSupport)),
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
                  l10n.openSupportTicket,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.describeIssueAdminReply,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: l10n.subject,
                    hintText: l10n.helpSubjectHint,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l10n.message,
                    hintText: l10n.messageHint,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(_isSubmitting ? l10n.sending : l10n.send),
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
          const SizedBox(height: 14),
          Text(
            l10n.yourTickets,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<SupportTicket>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? const Stream<List<SupportTicket>>.empty()
                : _firestoreService.watchSupportTicketsForUser(
                    FirebaseAuth.instance.currentUser!.uid,
                  ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tickets = snapshot.data ?? const <SupportTicket>[];
              if (tickets.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(l10n.noSupportTicketsYet),
                  ),
                );
              }

              return Column(
                children: tickets.map((ticket) {
                  final updated = ticket.updatedAt == null
                      ? l10n.pendingTimestamp
                      : DateFormat.yMMMd().add_jm().format(ticket.updatedAt!);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ticket.subject,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusBadge(status: ticket.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.message,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (ticket.hasReply) ...[
                          const SizedBox(height: 10),
                          Text(
                            l10n.adminReply(ticket.latestReply ?? ''),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.supportType(ticket.type)} • $updated',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'processing' => AppTheme.primary,
      'fixed' => AppTheme.primarySoft,
      'closed' => AppTheme.textMuted,
      _ => const Color(0xFFFFD166),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.supportStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
