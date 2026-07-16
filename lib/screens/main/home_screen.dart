import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/short_video_item.dart';
import '../../services/firestore_service.dart';
import '../../services/presence_service.dart';
import '../../services/shorts_progress_service.dart';
import '../../services/video_feed_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_int_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _youtubeDesktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final _firestoreService = FirestoreService();
  final _videoFeedService = VideoFeedService();
  final _pageController = PageController();
  final _controllers = <int, YoutubePlayerController>{};
  final _countedShortIds = <String>{};
  late final Stream<int> _onlineUsersCountStream =
      PresenceService.instance.watchOnlineUsersCount();

  Timer? _watchTimer;
  Timer? _playlistRefreshTimer;
  List<ShortVideoItem> _feed = const [];
  int _currentIndex = 0;
  int _cycleCompletedShorts = 0;
  int _cycleWatchMs = 0;
  int _bonusProgressShorts = 0;
  int _lastTrackedPositionMs = 0;
  bool _isLoadingFeed = true;
  bool _isRewardHandling = false;
  bool _isProcessingCompletedShort = false;
  String? _feedError;

  YoutubePlayerParams get _playerParams => const YoutubePlayerParams(
        mute: false,
        showControls: false,
        showFullscreenButton: false,
        enableJavaScript: true,
        origin: 'https://www.youtube.com',
        playsInline: true,
        strictRelatedVideos: true,
        userAgent: _youtubeDesktopUserAgent,
      );

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingFeed = false);
      }
      return;
    }

    try {
      final feed = await _videoFeedService.loadFeed(userId: user.uid);
      final progress = await ShortsProgressService.instance.load(user.uid);

      if (!mounted) return;
      setState(() {
        _feed = feed;
        _cycleCompletedShorts = progress.completedShortsInCycle;
        _cycleWatchMs = progress.watchMsInCycle;
        _bonusProgressShorts = progress.bonusProgressShorts;
        _isLoadingFeed = false;
        _feedError = null;
      });

      await _ensureController(0);
      await _activateCurrentController();
      _watchTimer ??= Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => _trackWatchTime(),
      );
      _playlistRefreshTimer ??= Timer.periodic(
        const Duration(minutes: 20),
        (_) => _refreshFeedSilently(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingFeed = false;
        _feedError = error.toString();
      });
    }
  }

  Future<void> _refreshFeedSilently() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final freshFeed = await _videoFeedService.loadFeed(userId: user.uid);
      if (!mounted || freshFeed.isEmpty) return;
      setState(() {
        _feed = freshFeed;
        if (_currentIndex >= _feed.length) {
          _currentIndex = _feed.length - 1;
        }
      });
      await _ensureController(_currentIndex);
      await _ensureController(_currentIndex + 1);
      await _ensureController(_currentIndex + 2);
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _playlistRefreshTimer?.cancel();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.close();
    }
    super.dispose();
  }

  Future<void> _ensureController(int index) async {
    if (index < 0 || index >= _feed.length || _controllers.containsKey(index)) {
      return;
    }

    final controller = YoutubePlayerController.fromVideoId(
      videoId: _feed[index].videoId,
      autoPlay: false,
      params: _playerParams,
    );
    _controllers[index] = controller;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _activateCurrentController() async {
    if (_feed.isEmpty) return;

    await _ensureController(_currentIndex);
    await _ensureController(_currentIndex + 1);
    await _ensureController(_currentIndex + 2);

    _lastTrackedPositionMs = 0;
    for (final entry in _controllers.entries) {
      if (entry.key == _currentIndex) {
        await entry.value.playVideo();
      } else {
        await entry.value.pauseVideo();
      }
    }

    final removable = _controllers.keys
        .where((index) => (index - _currentIndex).abs() > 2)
        .toList(growable: false);
    for (final index in removable) {
      await _controllers[index]?.close();
      _controllers.remove(index);
    }
  }

  Future<void> _trackWatchTime() async {
    if (!mounted || _feed.isEmpty || _isRewardHandling) return;
    final user = FirebaseAuth.instance.currentUser;
    final controller = _controllers[_currentIndex];
    if (user == null || controller == null) return;

    final state = controller.value.playerState;
    if (state != PlayerState.playing && state != PlayerState.buffering) return;

    final currentTimeSeconds = await controller.currentTime;
    final durationSeconds = await controller.duration;
    if (durationSeconds <= 0) return;

    final positionMs = (currentTimeSeconds * 1000).round();
    final durationMs = (durationSeconds * 1000).round();
    final deltaMs = positionMs - _lastTrackedPositionMs;
    _lastTrackedPositionMs = positionMs;

    if (deltaMs > 0 && deltaMs <= 2000) {
      final result = await ShortsProgressService.instance.addWatchTime(
        uid: user.uid,
        deltaMs: deltaMs,
      );
      if (!mounted) return;
      setState(() => _cycleWatchMs = result.snapshot.watchMsInCycle);
      if (result.rewardCycleCompleted) {
        await _grantCycleReward();
      }
    }

    final item = _feed[_currentIndex];
    final watchedRatio = positionMs / durationMs.clamp(1, 1 << 30);
    if (watchedRatio >= 0.92 && !_countedShortIds.contains(item.id)) {
      _countedShortIds.add(item.id);
      unawaited(_handleCompletedShort());
    }

    if (state == PlayerState.ended && _currentIndex < _feed.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleCompletedShort() async {
    if (_isProcessingCompletedShort) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isProcessingCompletedShort = true;
    try {
      await _firestoreService.applyUserProgress(
        uid: user.uid,
        videosWatchedDelta: 1,
      );

      final result = await ShortsProgressService.instance.markShortCompleted(
        user.uid,
      );
      if (!mounted) return;

      setState(() {
        _cycleCompletedShorts = result.snapshot.completedShortsInCycle;
        _bonusProgressShorts = result.snapshot.bonusProgressShorts;
      });

      if (result.bonusViewsAwarded > 0) {
        await _firestoreService.applyUserProgress(
          uid: user.uid,
          viewsDelta: result.bonusViewsAwarded,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎁 +${result.bonusViewsAwarded} bonus views'),
          ),
        );
      }

      if (result.rewardCycleCompleted) {
        await _grantCycleReward();
      }
    } finally {
      _isProcessingCompletedShort = false;
    }
  }

  Future<void> _grantCycleReward() async {
    if (_isRewardHandling) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    _isRewardHandling = true;
    const rewardViews = 40;

    await _firestoreService.applyUserProgress(
      uid: user.uid,
      viewsDelta: rewardViews,
    );
    final snapshot = await ShortsProgressService.instance.consumeRewardCycle(
      user.uid,
    );

    if (!mounted) return;
    setState(() {
      _cycleCompletedShorts = snapshot.completedShortsInCycle;
      _cycleWatchMs = snapshot.watchMsInCycle;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('+40 views added')),
    );
    _isRewardHandling = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.noUserSessionFound)));
    }

    if (_isLoadingFeed) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_feedError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _feedError!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_feed.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No playlist videos available.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final currentViews = appUser?.views ?? 0;
        final payoutProgress = (currentViews / FirestoreService.minimumPayoutCoins)
            .clamp(0, 1)
            .toDouble();

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _feed.length,
                  onPageChanged: (index) async {
                    setState(() => _currentIndex = index);
                    await _activateCurrentController();
                  },
                  itemBuilder: (context, index) {
                    final item = _feed[index];
                    final controller = _controllers[index];
                    return _ShortVideoPage(
                      item: item,
                      controller: controller,
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 102),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: const Text(
                              'VideoMoney',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StreamBuilder<int>(
                                stream: _onlineUsersCountStream,
                                builder: (context, onlineSnapshot) {
                                  return _OverlayChip(
                                    child: Text(
                                      l10n.usersOnline(
                                        NumberFormat.decimalPattern().format(
                                          onlineSnapshot.data ?? 0,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<int>(
                                stream: _firestoreService.watchUnreadInboxCount(
                                  user.uid,
                                ),
                                builder: (context, unreadSnapshot) {
                                  final unread = unreadSnapshot.data ?? 0;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _CircleIconButton(
                                            icon: Icons.mail_outline_rounded,
                                            onPressed: () {
                                              Navigator.of(
                                                context,
                                              ).pushNamed(AppRoutes.inbox);
                                            },
                                          ),
                                          if (unread > 0)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
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
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      _CircleIconButton(
                                        icon: Icons.settings_outlined,
                                        onPressed: () {
                                          Navigator.of(
                                            context,
                                          ).pushNamed(AppRoutes.settings);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 270),
                          child: _OverlayCard(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.currentViews,
                                            style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedIntText(
                                            value: currentViews,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                AppTheme.primary.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: AppTheme.primary
                                                  .withOpacity(0.28),
                                            ),
                                          ),
                                          child: Text(
                                            _feed[_currentIndex].category,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$_cycleCompletedShorts / ${ShortsProgressService.rewardThresholdShorts} shorts',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _CompactProgressLine(
                                  title: l10n.progressToPayout,
                                  valueLabel:
                                      '${NumberFormat.decimalPattern().format(currentViews)} / ${NumberFormat.decimalPattern().format(FirestoreService.minimumPayoutCoins)}',
                                  value: payoutProgress,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShortVideoPage extends StatelessWidget {
  const _ShortVideoPage({
    required this.item,
    required this.controller,
  });

  final ShortVideoItem item;
  final YoutubePlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF030806)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = constraints.maxWidth / constraints.maxHeight;
                return IgnorePointer(
                  child: YoutubePlayer(
                    controller: controller!,
                    aspectRatio: aspectRatio,
                  ),
                );
              },
            )
          else if (item.thumbnailUrl != null)
            DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(item.thumbnailUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF07120D),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.18),
                  Colors.transparent,
                  Colors.black.withOpacity(0.72),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.creator,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                    height: 1.35,
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

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        child: child,
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _CompactProgressLine extends StatelessWidget {
  const _CompactProgressLine({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  final String title;
  final String valueLabel;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: value,
            backgroundColor: Colors.white.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.30),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
