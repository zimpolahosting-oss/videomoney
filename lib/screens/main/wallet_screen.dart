import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ad_transfer.dart';
import '../../models/app_user.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/payout_i18n.dart';
import '../../widgets/watermark_hero_card.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();
    const adsUnit = 'ads';

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.noUserSessionFound)),
      );
    }

    final processingUnit = Localizations.localeOf(context).languageCode.toLowerCase() == 'nl'
        ? 'uur'
        : 'hours';

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
                final currentAds = appUser?.views ?? 0;
                final estimatedEarnings =
                    FirestoreService.estimateEarningsEuro(currentAds);
                final remaining = currentAds >= FirestoreService.minimumPayoutCoins
                    ? 0
                    : FirestoreService.minimumPayoutCoins - currentAds;

                return WatermarkHeroCard(
                  height: 294,
                  imageAsset: 'assets/illustrations/wallet_purse_v2.jpg',
                  imageOpacity: 0.17,
                  imageScale: 1.42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VideoMoney',
                        style: TextStyle(
                          color: AppTheme.primarySoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                        Text(
                          l10n.yourWallet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
                          NumberFormat.decimalPattern().format(currentAds),
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
                                value: '${NumberFormat.decimalPattern().format(remaining)} $adsUnit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.estimateOnly,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 420;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 24) / 3
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _RuleMiniCard(
                        icon: Icons.flag_circle_outlined,
                        title: l10n.minPayout,
                        value: NumberFormat.decimalPattern()
                            .format(FirestoreService.minimumPayoutCoins),
                        suffix: adsUnit,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RuleMiniCard(
                        icon: Icons.schedule_outlined,
                        title: l10n.processingTime,
                        value: '${FirestoreService.payoutProcessingDays}',
                        suffix: processingUnit,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RuleMiniCard(
                        icon: Icons.verified_user_outlined,
                        title: l10n.approval,
                        value: 'Admin',
                        suffix: 'review',
                      ),
                    ),
                  ],
                );
              },
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
              icon: Icons.currency_bitcoin_rounded,
              title: l10n.bitcoinTitle,
              subtitle: l10n.bitcoinSubtitle,
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'btc',
                );
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.token_rounded,
              title: 'USDC',
              subtitle: l10n.usdcSubtitle,
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.payoutRequest,
                  arguments: 'usdc',
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<AppUser?>(
              stream: firestoreService.watchUser(user.uid),
              builder: (context, userSnapshot) {
                return _AdsTransferSection(
                  firestoreService: firestoreService,
                  firebaseUser: user,
                  appUser: userSnapshot.data,
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
                                    '${NumberFormat.decimalPattern().format(payout.viewsRequested)} $adsUnit',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${payout.payoutMethodLabel} • ${payout.normalizedCurrency}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    payout.destinationSummary,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (payout.status.toLowerCase() == 'rejected' &&
                                      (payout.rejectReasonCode.trim().isNotEmpty ||
                                          payout.rejectReasonNote.trim().isNotEmpty)) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${PayoutI18n.rejectReasonLabel(context)}: ${PayoutI18n.localizedRejectReason(
                                        context,
                                        code: payout.rejectReasonCode.trim(),
                                        minimumVersion: payout.minimumRequiredVersion,
                                        note: payout.rejectReasonNote,
                                      )}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
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
            const SizedBox(height: 16),
            _SectionTitle(title: l10n.leaderboardTitle),
            const SizedBox(height: 6),
            Text(
              l10n.leaderboardSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<LeaderboardEntry>>(
              stream: firestoreService.watchLeaderboard(limit: 10),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final entries = snapshot.data ?? const <LeaderboardEntry>[];
                if (entries.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.leaderboardEmpty),
                    ),
                  );
                }

                return Column(
                  children: entries
                      .map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: AppTheme.outline.withOpacity(0.55),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 38,
                                width: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: entry.uid == user.uid
                                      ? AppTheme.primary.withOpacity(0.18)
                                      : Colors.white.withOpacity(0.04),
                                ),
                                child: Text(
                                  '${entries.indexOf(entry) + 1}',
                                  style: TextStyle(
                                    color: entry.uid == user.uid
                                        ? AppTheme.primarySoft
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.customName.isNotEmpty
                                          ? entry.customName
                                          : entry.publicName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${NumberFormat.decimalPattern().format(entry.views)} ${l10n.viewsUnit} • ${entry.videosWatched} ${l10n.videosWatched.toLowerCase()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (entry.uid == user.uid)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: AppTheme.primary.withOpacity(0.12),
                                    border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.28),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppTheme.primarySoft,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdsTransferSection extends StatelessWidget {
  const _AdsTransferSection({
    required this.firestoreService,
    required this.firebaseUser,
    required this.appUser,
  });

  final FirestoreService firestoreService;
  final User firebaseUser;
  final AppUser? appUser;

  Future<void> _showTransferDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SendAdsDialog(
        firestoreService: firestoreService,
        currentAds: appUser?.views ?? 0,
      ),
    );
  }

  Future<void> _handleTransferAction(
    BuildContext context, {
    required bool accept,
    required AdTransfer transfer,
  }) async {
    try {
      if (accept) {
        await firestoreService.acceptAdsTransfer(transfer.id);
      } else {
        await firestoreService.rejectAdsTransfer(transfer.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Ads transfer accepted.' : 'Ads transfer rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: firestoreService.watchAdsTransferEnabled(),
      builder: (context, enabledSnapshot) {
        final enabled = enabledSnapshot.data ?? false;
        return StreamBuilder<List<AdTransfer>>(
          stream: firestoreService.watchUserAdTransfers(firebaseUser.uid),
          builder: (context, transferSnapshot) {
            final transfers = transferSnapshot.data ?? const <AdTransfer>[];
            final incomingPending = transfers
                .where(
                  (transfer) =>
                      transfer.isPending && transfer.isRecipient(firebaseUser.uid),
                )
                .toList(growable: false);
            final recentTransfers = transfers.take(4).toList(growable: false);

            if (!enabled && transfers.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'Share your ads'),
                const SizedBox(height: 6),
                Text(
                  'Send ads to family or friends by email. Max ${FirestoreService.maxAdsTransferPerDay} ads per day. Selling ads is forbidden and may lead to a ban.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (enabled)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showTransferDialog(context),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Share ads with friends'),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Ads transfer is currently disabled by admin.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                if (incomingPending.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Pending requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...incomingPending.map(
                    (transfer) => Container(
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
                          Text(
                            '${NumberFormat.decimalPattern().format(transfer.amountAds)} ads from ${transfer.senderEmail}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            transfer.createdAt == null
                                ? 'Waiting for timestamp'
                                : DateFormat.yMMMd().add_jm().format(transfer.createdAt!),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleTransferAction(
                                    context,
                                    accept: false,
                                    transfer: transfer,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _handleTransferAction(
                                    context,
                                    accept: true,
                                    transfer: transfer,
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (recentTransfers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Transfer overview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...recentTransfers.map(
                    (transfer) {
                      final isSender = transfer.isSender(firebaseUser.uid);
                      final counterpartyEmail = isSender
                          ? transfer.recipientEmail
                          : transfer.senderEmail;
                      final direction = isSender ? 'To' : 'From';
                      final color = switch (transfer.status.toLowerCase()) {
                        'accepted' => AppTheme.primary,
                        'rejected' => const Color(0xFFFF7B7B),
                        _ => AppTheme.coin,
                      };
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
                                    '$direction $counterpartyEmail',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat.decimalPattern().format(transfer.amountAds)} ads',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transfer.createdAt == null
                                        ? 'Waiting for timestamp'
                                        : DateFormat.yMMMd().add_jm().format(transfer.createdAt!),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: color.withOpacity(0.28)),
                              ),
                              child: Text(
                                transfer.status.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _SendAdsDialog extends StatefulWidget {
  const _SendAdsDialog({
    required this.firestoreService,
    required this.currentAds,
  });

  final FirestoreService firestoreService;
  final int currentAds;

  @override
  State<_SendAdsDialog> createState() => _SendAdsDialogState();
}

class _SendAdsDialogState extends State<_SendAdsDialog> {
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (email.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email and ads amount.')),
      );
      return;
    }
    if (amount > widget.currentAds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have enough ads to send.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.firestoreService.createAdsTransfer(
        recipientEmail: email,
        amountAds: amount,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ads transfer request sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share ads with friends'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Friend email',
                hintText: 'friend@email.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Ads amount',
                hintText: 'Max ${FirestoreService.maxAdsTransferPerDay} per day',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Only use this to help family or friends. Selling ads is forbidden and may lead to a ban.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Sending...' : 'Send'),
        ),
      ],
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
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$value $suffix',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
