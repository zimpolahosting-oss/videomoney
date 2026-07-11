import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/watermark_hero_card.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _TopTitle(title: l10n.wallet),
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
                  height: 294,
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
                        Text(
                          l10n.yourWallet,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: Text(
                            l10n.availableViews,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.decimalPattern().format(currentViews),
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SmallStat(
                                label: l10n.estimatedPayout,
                                value: '€${estimatedEarnings.toStringAsFixed(2)}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SmallStat(
                                label: l10n.remainingToPayout,
                                value: '${NumberFormat.decimalPattern().format(remaining)} ${l10n.viewsUnit}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.estimateOnly,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.payoutRequest);
                            },
                            icon: const Icon(Icons.request_quote_outlined),
                            label: Text(l10n.requestPayout),
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
                    title: l10n.minPayout,
                    value: NumberFormat.decimalPattern()
                        .format(FirestoreService.minimumPayoutCoins),
                    suffix: l10n.viewsUnit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RuleMiniCard(
                    icon: Icons.schedule_outlined,
                    title: l10n.processingTime,
                    value: '${FirestoreService.payoutProcessingDays}',
                    suffix: 'days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RuleMiniCard(
                    icon: Icons.verified_user_outlined,
                    title: l10n.approval,
                    value: 'Admin',
                    suffix: 'review',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: l10n.payoutMethods),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.payments_outlined,
              title: 'PayPal',
              subtitle: l10n.paypalSubtitle,
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
              subtitle: l10n.revolutSubtitle,
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'revolut',
                );
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.account_balance_outlined,
              title: l10n.bankTransferTitle,
              subtitle: l10n.bankTransferSubtitle,
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'bank',
                );
              },
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: l10n.payoutHistory),
            const SizedBox(height: 10),
            StreamBuilder<List<PayoutRequest>>(
              stream: firestoreService.watchPayouts(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payouts = snapshot.data ?? const <PayoutRequest>[];
                if (payouts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.noPayoutRequestsYet),
                    ),
                  );
                }

                final preview = payouts.take(3).toList(growable: false);
                return Column(
                  children: [
                    ...preview.map((payout) {
                      final formattedDate = payout.createdAt == null
                          ? l10n.pendingTimestamp
                          : DateFormat.yMMMd().format(payout.createdAt!);
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
                                    '${NumberFormat.decimalPattern().format(payout.viewsRequested)} ${l10n.viewsUnit}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${payout.payoutMethodLabel} • ${payout.normalizedCurrency}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    payout.destinationSummary,
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
                          child: Text(l10n.viewFullHistory),
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
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
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
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
