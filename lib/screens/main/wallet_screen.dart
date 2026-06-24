import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../models/app_user.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/watermark_hero_card.dart';

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const _TopTitle(title: 'Wallet'),
            const SizedBox(height: 14),
            StreamBuilder<AppUser?>(
              stream: firestoreService.watchUser(user.uid),
              builder: (context, snapshot) {
                final appUser = snapshot.data;
                final currentViews = appUser?.views ?? 0;
                final estimatedEarnings =
                    FirestoreService.estimateEarningsEuro(currentViews);
                final remaining = currentViews >= FirestoreService.minimumPayoutCoins
                    ? 0
                    : FirestoreService.minimumPayoutCoins - currentViews;

                return SizedBox(
                  height: 248,
                  child: WatermarkHeroCard(
                    imageAsset: 'assets/illustrations/wallet_purse_v2.jpg',
                    imageOpacity: 0.17,
                    imageScale: 1.42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'VideoMoney',
                                style: TextStyle(
                                  color: AppTheme.primarySoft,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.payoutHistory);
                              },
                              icon: const Icon(
                                Icons.history_toggle_off,
                                color: AppTheme.primarySoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your Wallet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: Text(
                            'Available Views',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          NumberFormat.decimalPattern().format(currentViews),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _SmallStat(
                                label: 'Estimated Payout',
                                value: '€${estimatedEarnings.toStringAsFixed(2)}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SmallStat(
                                label: 'Remaining to Payout',
                                value: '${NumberFormat.decimalPattern().format(remaining)} views',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Estimate only. 50 views ≈ €0.01 and actual earnings may vary.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.payoutRequest);
                            },
                            icon: const Icon(Icons.request_quote_outlined),
                            label: const Text('Request Payout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RuleMiniCard(
                    icon: Icons.flag_circle_outlined,
                    title: 'Min. Payout',
                    value: NumberFormat.decimalPattern()
                        .format(FirestoreService.minimumPayoutCoins),
                    suffix: 'views',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RuleMiniCard(
                    icon: Icons.schedule_outlined,
                    title: 'Processing Time',
                    value: '${FirestoreService.payoutProcessingDays}',
                    suffix: 'days',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: _RuleMiniCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Approval',
                    value: 'Admin',
                    suffix: 'review',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle(title: 'Payout Methods'),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.payments_outlined,
              title: 'PayPal',
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'paypal',
                );
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Revolut',
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'revolut',
                );
              },
            ),
            const SizedBox(height: 16),
            const _SectionTitle(title: 'Payout History'),
            const SizedBox(height: 10),
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

                final preview = payouts.take(3).toList(growable: false);
                return Column(
                  children: [
                    ...preview.map((payout) {
                      final formattedDate = payout.createdAt == null
                          ? 'Pending timestamp'
                          : DateFormat.yMMMd().format(payout.createdAt!);
                      final method = payout.payoutMethod.isNotEmpty
                          ? payout.payoutMethod
                          : (payout.revolutUsername.isNotEmpty ? 'revolut' : 'paypal');
                      final destination = method == 'revolut'
                          ? 'Revolut: ${payout.revolutUsername.isNotEmpty ? payout.revolutUsername : payout.ibanOrBankAccount}'
                          : 'PayPal: ${payout.payPalEmail}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${NumberFormat.decimalPattern().format(payout.viewsRequested)} views',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    destination,
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
                            _StatusBadge(status: payout.status),
                          ],
                        ),
                      );
                    }),
                    if (payouts.length > preview.length)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.payoutHistory);
                          },
                          child: const Text('View full history'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleMiniCard extends StatelessWidget {
  const _RuleMiniCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String title;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primarySoft, size: 18),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            '$value $suffix',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.12),
              ),
              child: Icon(icon, color: AppTheme.primarySoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
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
