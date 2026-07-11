import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/inbox_message.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.noUserSessionFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inbox),
        actions: [
          TextButton(
            onPressed: () => firestoreService.markAllInboxMessagesRead(user.uid),
            child: Text(l10n.markAllRead),
          ),
        ],
      ),
      body: StreamBuilder<List<InboxMessage>>(
        stream: firestoreService.watchUserInbox(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? const <InboxMessage>[];
          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noInboxMessagesYet),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final formattedDate = message.createdAt == null
                  ? l10n.pendingTimestamp
                  : DateFormat.yMMMd().add_jm().format(message.createdAt!);

              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  await firestoreService.markInboxMessageRead(message.id);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: message.read
                          ? AppTheme.outline.withOpacity(0.45)
                          : AppTheme.primary.withOpacity(0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!message.read)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.newBadge,
                                style: TextStyle(
                                  color: AppTheme.primarySoft,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${l10n.supportType(message.type)} • $formattedDate',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
