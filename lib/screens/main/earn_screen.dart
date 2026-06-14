import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _firestoreService = FirestoreService();
  final _earningsService = EarningsService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _earningsService.preloadRewardedVideo();
  }

  Future<void> _watchVideo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLoading) return;

    setState(() => _isLoading = true);
    String? lastStatusMessage;

    final rewardGranted = await _earningsService.watchRewardedVideo(
      uid: user.uid,
      onAdStatus: (message) {
        lastStatusMessage = message;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );

    if (!mounted) return;

    if (rewardGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You earned ${FirestoreService.rewardCoinsPerVideo} coins.',
          ),
        ),
      );
    } else if (lastStatusMessage != RewardedAdService.adUnavailableMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rewarded ad was not completed.'),
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final currentCoins = appUser?.coins ?? 0;
        final totalVideos = appUser?.videosWatched ?? 0;

        return Scaffold(
          appBar: AppBar(title: const Text('Earn')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF13241D),
                      Color(0xFF0B1511),
                    ],
                  ),
                  border: Border.all(color: AppTheme.outline.withOpacity(0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rewarded videos',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Start the same rewarded ad flow used on the Home page and collect ${FirestoreService.rewardCoinsPerVideo} coins per completed video.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _StepChip(
                          icon: Icons.play_circle_outline,
                          text: 'Watch the full ad',
                        ),
                        _StepChip(
                          icon: Icons.verified_outlined,
                          text: 'Reward is confirmed',
                        ),
                        _StepChip(
                          icon: Icons.savings_outlined,
                          text: 'Coins land in your wallet',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _watchVideo,
                        icon: Icon(
                          _isLoading
                              ? Icons.hourglass_top_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          _isLoading ? 'Loading ad...' : 'Watch Video',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StatCard(
                title: 'Current balance',
                value: '$currentCoins coins',
                icon: Icons.savings,
                color: AppTheme.primary,
                caption: 'Ready for payout once you reach the minimum threshold',
              ),
              const SizedBox(height: 14),
              StatCard(
                title: 'Total rewarded videos',
                value: '$totalVideos',
                icon: Icons.movie_filter,
                color: AppTheme.primarySoft,
                caption:
                    '${totalVideos * FirestoreService.rewardCoinsPerVideo} total coins generated from completed rewarded ads',
              ),
              const SizedBox(height: 14),
              StatCard(
                title: 'Minimum payout target',
                value: '${FirestoreService.minimumPayoutCoins} coins',
                icon: Icons.flag_circle_outlined,
                color: AppTheme.coin,
                caption:
                    'Processing time remains ${FirestoreService.payoutProcessingDays} days after request approval',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline.withOpacity(0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primarySoft),
          const SizedBox(width: 10),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
