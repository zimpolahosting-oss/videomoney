import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
            'You earned ${FirestoreService.rewardCoinsPerVideo} view.',
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
        final views = appUser?.views ?? 0;
        final videosWatched = appUser?.videosWatched ?? 0;
        final estimatedEarnings = FirestoreService.estimateEarningsEuro(views);
        final viewsRemaining = views >= FirestoreService.minimumPayoutCoins
            ? 0
            : FirestoreService.minimumPayoutCoins - views;
        final isReadyForPayout = views >= FirestoreService.minimumPayoutCoins;

        return Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF11261C),
                        Color(0xFF08120E),
                        Color(0xFF04100A),
                      ],
                    ),
                    border: Border.all(color: AppTheme.outline.withOpacity(0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.10),
                        blurRadius: 26,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email ?? 'Signed-in user',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricPill(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Views',
                            value: '$views views',
                            color: AppTheme.coin,
                          ),
                          _MetricPill(
                            icon: Icons.movie_creation_outlined,
                            label: 'Watched',
                            value: '$videosWatched videos',
                            color: AppTheme.primarySoft,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isReadyForPayout
                            ? 'You are ready to request a payout.'
                            : '$viewsRemaining more views needed to reach the payout minimum.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _watchVideo,
                          icon: Icon(
                            _isLoading
                                ? Icons.hourglass_top_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          label: Text(
                            _isLoading ? 'Loading ad...' : 'Watch Video',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatCard(
                title: 'View balance',
                value: '$views',
                icon: Icons.monetization_on,
                color: AppTheme.coin,
                caption: 'Available for future payout requests',
              ),
              const SizedBox(height: 14),
              StatCard(
                title: 'Estimated earnings',
                value: '€${estimatedEarnings.toStringAsFixed(2)}',
                icon: Icons.query_stats,
                color: AppTheme.primarySoft,
                caption:
                    'Estimate only. 50 completed views ≈ €0.01 and actual earnings may vary.',
              ),
              const SizedBox(height: 14),
              StatCard(
                title: 'Videos watched',
                value: '$videosWatched',
                icon: Icons.ondemand_video,
                color: AppTheme.primary,
                caption:
                    '${FirestoreService.rewardCoinsPerVideo} view is granted only after each completed rewarded ad',
              ),
              const SizedBox(height: 14),
              StatCard(
                title: 'Payout access',
                value: isReadyForPayout ? 'Unlocked' : 'Locked',
                icon: Icons.request_quote_outlined,
                color: isReadyForPayout ? AppTheme.primary : Colors.orangeAccent,
                caption:
                    'Minimum payout: ${FirestoreService.minimumPayoutCoins} views, processing time: ${FirestoreService.payoutProcessingDays} days',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
