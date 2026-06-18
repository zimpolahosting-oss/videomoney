import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../theme/app_theme.dart';

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
        const SnackBar(content: Text('Reward confirmed. Views added.')),
      );
    } else if (lastStatusMessage == null) {
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
        final viewsRemaining = views >= FirestoreService.minimumPayoutCoins
            ? 0
            : FirestoreService.minimumPayoutCoins - views;
        final isReadyForPayout = views >= FirestoreService.minimumPayoutCoins;

        final todayKey = FirestoreService.formatLocalDateKey(DateTime.now());
        final dailyCount = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyVideosWatched ?? 0)
            : 0;
        final dailyBonusAwarded = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyBonusAwarded ?? false)
            : false;
        final dailyProgress = (dailyCount / FirestoreService.dailyBonusTargetVideos)
            .clamp(0, 1)
            .toDouble();
        final payoutProgress =
            (views / FirestoreService.minimumPayoutCoins).clamp(0, 1).toDouble();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              const _TopTitle(title: 'Home'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
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
                  border: Border.all(color: AppTheme.outline.withOpacity(0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
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
                            Navigator.of(context).pushNamed(AppRoutes.settings);
                          },
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppTheme.primarySoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? 'Signed-in user',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Watch videos, earn views, and get paid!',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/illustrations/home_movie_v2.jpg',
                            height: 118,
                            width: 118,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.visibility_outlined,
                            title: 'Current Views',
                            value: NumberFormat.decimalPattern().format(views),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.ondemand_video_outlined,
                            title: 'Videos Watched',
                            value:
                                NumberFormat.decimalPattern().format(videosWatched),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                      'Progress to payout',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You're on your way!",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${NumberFormat.decimalPattern().format(views)} / ${NumberFormat.decimalPattern().format(FirestoreService.minimumPayoutCoins)} views',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${(payoutProgress * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: payoutProgress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _watchVideo,
                        icon: Icon(
                          _isLoading
                              ? Icons.hourglass_top_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_isLoading ? 'Loading...' : 'Watch Video'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Earn views now!',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isReadyForPayout
                          ? 'Payout unlocked. You can request payout in the Wallet.'
                          : '${NumberFormat.decimalPattern().format(viewsRemaining)} more views until payout.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            color: AppTheme.primarySoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Daily Bonus',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppTheme.primary.withOpacity(0.12),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.28),
                            ),
                          ),
                          child: Text(
                            '+${FirestoreService.dailyBonusViews}',
                            style: const TextStyle(
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
                      'Watch ${FirestoreService.dailyBonusTargetVideos} videos daily to get bonus views!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$dailyCount / ${FirestoreService.dailyBonusTargetVideos} videos watched',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          dailyBonusAwarded ? 'Bonus claimed' : 'Bonus',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: dailyProgress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor:
                            const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        border: Border.all(color: AppTheme.outline.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primarySoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
