import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/watermark_hero_card.dart';

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
        final totalVideos = appUser?.videosWatched ?? 0;
        final todayKey = FirestoreService.formatLocalDateKey(DateTime.now());
        final dailyCount = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyVideosWatched ?? 0)
            : 0;
        final dailyProgress = (dailyCount / FirestoreService.dailyBonusTargetVideos)
            .clamp(0, 1)
            .toDouble();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                const _TopTitle(title: 'Earn'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 230,
                  child: WatermarkHeroCard(
                    imageAsset: 'assets/illustrations/earn_phone.jpg',
                    imageOpacity: 0.17,
                    imageScale: 1.36,
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
                                Navigator.of(context).pushNamed(AppRoutes.about);
                              },
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.primarySoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: Text(
                            'Earn Views',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 235),
                          child: Text(
                            'Watch rewarded videos and earn views instantly.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const Spacer(),
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
                            label:
                                Text(_isLoading ? 'Loading...' : 'Watch Video'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Earn views',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
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
                        'How it works',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: const [
                          Expanded(
                            child: _HowStep(
                              icon: Icons.play_circle_outline,
                              title: 'Watch',
                              subtitle: 'Watch a short\nvideo',
                            ),
                          ),
                          _HowArrow(),
                          Expanded(
                            child: _HowStep(
                              icon: Icons.visibility_outlined,
                              title: 'Earn',
                              subtitle: 'Get views as\nreward',
                            ),
                          ),
                          _HowArrow(),
                          Expanded(
                            child: _HowStep(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Cash Out',
                              subtitle: 'Reach 10,000\nviews',
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
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined,
                              color: AppTheme.primarySoft),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Daily Challenge',
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
                        'Watch ${FirestoreService.dailyBonusTargetVideos} videos today and get bonus views!',
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
                          const Text(
                            'Bonus',
                            style: TextStyle(color: AppTheme.textMuted),
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ondemand_video_outlined,
                          color: AppTheme.primarySoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Total videos watched',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        NumberFormat.decimalPattern().format(totalVideos),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _HowArrow extends StatelessWidget {
  const _HowArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: AppTheme.outline.withOpacity(0.9),
        size: 18,
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
          ),
          child: Icon(icon, color: AppTheme.primarySoft),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
