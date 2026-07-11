import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class PayoutHistoryScreen extends StatelessWidget {
  const PayoutHistoryScreen({super.key});

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
      appBar: AppBar(title: Text(l10n.payoutHistoryTitle)),
      body: StreamBuilder<List<PayoutRequest>>(
        stream: firestoreService.watchPayouts(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.unableLoadPayoutHistory),
              ),
            );
          }

          final payouts = snapshot.data ?? const <PayoutRequest>[];
          if (payouts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noPayoutRequestsYet),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: payouts.length,
            itemBuilder: (context, index) {
              final payout = payouts[index];
              final formattedDate = payout.createdAt == null
                  ? l10n.pendingTimestamp
                  : DateFormat.yMMMd().add_jm().format(payout.createdAt!);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${NumberFormat.decimalPattern().format(payout.viewsRequested)} ${l10n.viewsUnit}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.currencyLabel(payout.normalizedCurrency),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payout.destinationSummary,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.accountHolderLabel(
                              payout.accountHolderName.isEmpty
                                  ? l10n.notProvided
                                  : payout.accountHolderName,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(status: payout.status),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();
    final color = switch (normalizedStatus) {
      'approved' => AppTheme.primary,
      'paid' => AppTheme.primarySoft,
      'rejected' => const Color(0xFFFF7B7B),
      _ => AppTheme.coin,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        context.l10n.payoutStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
