import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../payout/payout_request_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          StreamBuilder<AppUser?>(
            stream: firestoreService.watchUser(user.uid),
            builder: (context, snapshot) {
              final appUser = snapshot.data;
              final currentCoins = appUser?.coins ?? 0;
              final shortfall =
                  currentCoins >= FirestoreService.minimumPayoutCoins
                  ? 0
                  : FirestoreService.minimumPayoutCoins - currentCoins;
              final readyForPayout =
                  currentCoins >= FirestoreService.minimumPayoutCoins;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF132319),
                      Color(0xFF08100C),
                    ],
                  ),
                  border: Border.all(color: AppTheme.outline.withOpacity(0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available balance',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$currentCoins coins',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      readyForPayout
                          ? 'You can submit a payout request now.'
                          : '$shortfall more coins are needed before payout becomes available.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PayoutRequestScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.request_quote),
                        label: const Text('Request Payout'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _WalletRuleCard(
            icon: Icons.flag_circle_outlined,
            title: 'Minimum payout',
            value: '${FirestoreService.minimumPayoutCoins} coins',
          ),
          const SizedBox(height: 12),
          _WalletRuleCard(
            icon: Icons.schedule_outlined,
            title: 'Processing time',
            value: '${FirestoreService.payoutProcessingDays} days',
          ),
          const SizedBox(height: 12),
          const _WalletRuleCard(
            icon: Icons.verified_user_outlined,
            title: 'Approval',
            value: 'Every payout request is reviewed by admin before processing',
          ),
          const SizedBox(height: 22),
          Text(
            'Payout history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<PayoutRequest>>(
            stream: firestoreService.watchPayouts(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final payouts = snapshot.data ?? const <PayoutRequest>[];
              if (payouts.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No payout requests yet.'),
                  ),
                );
              }

              return Column(
                children: payouts.map((payout) {
                  final formattedDate = payout.createdAt == null
                      ? 'Pending timestamp'
                      : DateFormat.yMMMd().add_jm().format(payout.createdAt!);
                  final payoutDestination = payout.payPalEmail.isNotEmpty
                      ? 'PayPal: ${payout.payPalEmail}'
                      : payout.ibanOrBankAccount.isNotEmpty
                          ? 'IBAN / bank: ${payout.ibanOrBankAccount}'
                          : 'Destination not saved';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: AppTheme.outline.withOpacity(0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.12),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: AppTheme.primarySoft,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${payout.coinsRequested} coins',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  _StatusBadge(status: payout.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                payoutDestination,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (payout.accountHolderName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Account holder: ${payout.accountHolderName}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Created: $formattedDate',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
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

class _WalletRuleCard extends StatelessWidget {
  const _WalletRuleCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.12),
            ),
            child: Icon(icon, color: AppTheme.primarySoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
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
    final normalizedStatus = status.toLowerCase();
    final color = switch (normalizedStatus) {
      'approved' => AppTheme.primary,
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
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
