import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/leaderboard_entry.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/presence_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/watermark_hero_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _earningsService = EarningsService();
  late final Stream<int> _onlineUsersCountStream =
      PresenceService.instance.watchOnlineUsersCount();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _earningsService.preloadRewardedVideo();
  }

  Future<void> _watchVideo() async {
    final l10n = context.l10n;
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
        SnackBar(content: Text(l10n.rewardConfirmedViewsAdded)),
      );
    } else if (lastStatusMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rewardedAdNotCompleted)),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.noUserSessionFound)),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final views = appUser?.views ?? 0;
        final videosWatched = appUser?.videosWatched ?? 0;
        final todayKey = FirestoreService.formatLocalDateKey(DateTime.now());
        final dailyCount = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyVideosWatched ?? 0)
            : 0;
        final dailyBonusAwarded = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyBonusAwarded ?? false)
            : false;
        final dailyProgress =
            (dailyCount / FirestoreService.dailyBonusTargetVideos)
                .clamp(0, 1)
                .toDouble();
        final payoutProgress = (views / FirestoreService.minimumPayoutCoins)
            .clamp(0, 1)
            .toDouble();

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _TopTitle(title: l10n.home),
                const SizedBox(height: 14),
                StreamBuilder<int>(
                  stream: _onlineUsersCountStream,
                  builder: (context, onlineSnapshot) {
                    final onlineUsers = onlineSnapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: AppTheme.outline.withOpacity(0.55),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            color: AppTheme.primary,
                            size: 12,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${NumberFormat.decimalPattern().format(onlineUsers)} users online',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                RepaintBoundary(
                  child: SizedBox(
                    height: 290,
                    child: WatermarkHeroCard(
                      key: const ValueKey('home-top-hero-card'),
                      imageAsset: 'assets/illustrations/home_movie_v2.jpg',
                      imageOpacity: 0.18,
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
                              StreamBuilder<int>(
                                stream: _firestoreService.watchUnreadInboxCount(
                                  user.uid,
                                ),
                                builder: (context, inboxSnapshot) {
                                  final unread = inboxSnapshot.data ?? 0;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          Navigator.of(
                                            context,
                                          ).pushNamed(AppRoutes.inbox);
                                        },
                                        icon: const Icon(
                                          Icons.mail_outline_rounded,
                                          color: AppTheme.primarySoft,
                                        ),
                                      ),
                                      if (unread > 0)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              unread > 99 ? '99+' : '$unread',
                                              style: const TextStyle(
                                                color: Color(0xFF04110A),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.settings);
                                },
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: AppTheme.primarySoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 230),
                            child: Text(
                              l10n.welcomeBackShort,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 230),
                            child: Text(
                              user.email ?? l10n.signedInUser,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 235),
                            child: Text(
                              l10n.watchVideosEarnPaid,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.visibility_outlined,
                                  title: l10n.currentViews,
                                  value:
                                      NumberFormat.decimalPattern().format(
                                        views,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.ondemand_video_outlined,
                                  title: l10n.videosWatched,
                                  value: NumberFormat.decimalPattern().format(
                                    videosWatched,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border:
                        Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.progressToPayout,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.youAreOnYourWay,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${NumberFormat.decimalPattern().format(views)} / ${NumberFormat.decimalPattern().format(FirestoreService.minimumPayoutCoins)} ${l10n.viewsUnit}',
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
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.primary),
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
                          label: Text(
                            _isLoading ? l10n.loading : l10n.watchVideo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                    border:
                        Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            color: AppTheme.primarySoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.dailyBonus,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
                        l10n.watchDailyVideosBonus(
                          '${FirestoreService.dailyBonusTargetVideos}',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$dailyCount / ${FirestoreService.dailyBonusTargetVideos} ${l10n.videosWatched.toLowerCase()}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            dailyBonusAwarded ? l10n.bonusClaimed : l10n.bonus,
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
                const SizedBox(height: 14),
                StreamBuilder<List<LeaderboardEntry>>(
                  stream: _firestoreService.watchLeaderboard(limit: 50),
                  builder: (context, leaderboardSnapshot) {
                    final entries =
                        leaderboardSnapshot.data ?? const <LeaderboardEntry>[];
                    return StreamBuilder<Set<String>>(
                      stream: PresenceService.instance.watchOnlineUserIds(),
                      builder: (context, onlineSnapshot) {
                        final onlineUserIds =
                            onlineSnapshot.data ?? const <String>{};
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: AppTheme.outline.withOpacity(0.55),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    color: AppTheme.primarySoft,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Leaderboard',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Top views en geschatte inkomsten van spelers.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 14),
                              if (entries.isEmpty)
                                Text(
                                  'Nog geen leaderboard-data beschikbaar.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )
                              else
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 360,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: ListView.separated(
                                      primary: false,
                                      shrinkWrap: true,
                                      physics: entries.length > 5
                                          ? const ClampingScrollPhysics()
                                          : const NeverScrollableScrollPhysics(),
                                      itemCount: entries.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final entry = entries[index];
                                        return _LeaderboardTile(
                                          rank: index + 1,
                                          entry: entry,
                                          isCurrentUser: entry.uid == user.uid,
                                          isOnline: onlineUserIds.contains(
                                            entry.uid,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.58),
        border: Border.all(color: AppTheme.outline.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primarySoft, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.isOnline,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final earnings = FirestoreService.estimateEarningsEuro(entry.views);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isCurrentUser
            ? AppTheme.primary.withOpacity(0.12)
            : Theme.of(context).colorScheme.surface.withOpacity(0.45),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primary.withOpacity(0.35)
              : AppTheme.outline.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3
                  ? AppTheme.coin.withOpacity(0.18)
                  : AppTheme.primarySoft.withOpacity(0.12),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
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
                  isCurrentUser
                      ? '${entry.publicName} (jij)'
                      : entry.publicName,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? const Color(0xFF35E06A)
                            : Colors.white.withOpacity(0.22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${NumberFormat.decimalPattern().format(entry.views)} views',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€${earnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primarySoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'inkomen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
