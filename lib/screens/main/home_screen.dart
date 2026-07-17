import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/short_video_item.dart';
import '../../services/firestore_service.dart';
import '../../services/presence_service.dart';
import '../../services/shorts_progress_service.dart';
import '../../services/video_feed_service.dart';
import 'monetag_ad_break_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_int_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _appBaseUrl = 'https://com.videomoney.app';
  static const String _monetagDirectLinkUrl = 'https://omg10.com/4/11320247';
  static const String _youtubeDesktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final _firestoreService = FirestoreService();
  final _videoFeedService = VideoFeedService();
  final _countedShortIds = <String>{};
  final _random = Random();
  late final Stream<int> _onlineUsersCountStream =
      PresenceService.instance.watchOnlineUsersCount();
  late final WebViewController _webViewController;

  Timer? _watchTimer;
  Timer? _playlistRefreshTimer;
  List<ShortVideoItem> _feed = const [];
  int _currentIndex = 0;
  int _cycleCompletedShorts = 0;
  int _cycleWatchMs = 0;
  int _bonusProgressShorts = 0;
  int _pendingAdBreakShorts = 0;
  bool _pendingAdBreakAttempted = false;
  int _lastTrackedPositionMs = 0;
  int _playerStateCode = -1;
  int? _playbackErrorCode;
  double _playerCurrentTimeSeconds = 0;
  double _playerDurationSeconds = 0;
  Offset? _swipeStartPosition;
  bool _swipeGestureConsumed = false;
  bool _playerReady = false;
  bool _isLoadingFeed = true;
  bool _isShowingAdBreak = false;
  bool _isRewardHandling = false;
  bool _isProcessingCompletedShort = false;
  String? _feedError;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF030806))
      ..setUserAgent(_youtubeDesktopUserAgent)
      ..addJavaScriptChannel(
        'PlaybackBridge',
        onMessageReceived: (message) => _handlePlayerBridgeMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;
            if (request.url == 'about:blank' ||
                request.url.startsWith('data:') ||
                uri.host.contains('youtube.com') ||
                uri.host.contains('youtube-nocookie.com') ||
                uri.host.contains('googlevideo.com') ||
                uri.host.contains('ytimg.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    final platformController = _webViewController.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }
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
      final feed = _randomizeFeed(
        await _videoFeedService.loadFeed(userId: user.uid),
      );
      final progress = await ShortsProgressService.instance.load(user.uid);

      if (!mounted) return;
      setState(() {
        _feed = feed;
        _currentIndex = 0;
        _syncProgressFromSnapshot(progress);
        _isLoadingFeed = false;
        _feedError = null;
      });

      await _loadCurrentVideoIntoWebView();
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
      final currentVideoId =
          _feed.isNotEmpty ? _feed[_currentIndex].videoId : null;
      final freshFeed = _randomizeFeed(
        await _videoFeedService.loadFeed(userId: user.uid),
        keepVideoId: currentVideoId,
      );
      if (!mounted || freshFeed.isEmpty) return;
      setState(() {
        _feed = freshFeed;
        _currentIndex = currentVideoId == null
            ? 0
            : freshFeed.indexWhere((item) => item.videoId == currentVideoId);
        if (_currentIndex < 0 || _currentIndex >= _feed.length) {
          _currentIndex = 0;
        }
      });
      await _loadCurrentVideoIntoWebView();
    } catch (_) {}
  }

  List<ShortVideoItem> _randomizeFeed(
    List<ShortVideoItem> feed, {
    String? keepVideoId,
  }) {
    if (feed.length <= 1) return List<ShortVideoItem>.from(feed);
    final shuffled = List<ShortVideoItem>.from(feed)..shuffle(_random);
    if (keepVideoId == null) {
      return shuffled;
    }

    final keptIndex = shuffled.indexWhere((item) => item.videoId == keepVideoId);
    if (keptIndex <= 0) {
      return shuffled;
    }

    final keptItem = shuffled.removeAt(keptIndex);
    shuffled.insert(0, keptItem);
    return shuffled;
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _playlistRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _showVideoAtIndex(int index) async {
    if (index < 0 || index >= _feed.length || index == _currentIndex) return;
    setState(() => _currentIndex = index);
    await _loadCurrentVideoIntoWebView();
  }

  Future<void> _goToNextVideo() => _showVideoAtIndex(_currentIndex + 1);

  Future<void> _goToPreviousVideo() => _showVideoAtIndex(_currentIndex - 1);

  void _onSwipePointerDown(PointerDownEvent event) {
    _swipeStartPosition = event.position;
    _swipeGestureConsumed = false;
  }

  void _onSwipePointerMove(PointerMoveEvent event) {
    if (_swipeGestureConsumed || _swipeStartPosition == null) return;
    final delta = event.position - _swipeStartPosition!;
    if (delta.dy.abs() < 110) return;
    if (delta.dy.abs() < delta.dx.abs() * 1.25) return;

    _swipeGestureConsumed = true;
    if (delta.dy < 0) {
      unawaited(_goToNextVideo());
    } else {
      unawaited(_goToPreviousVideo());
    }
  }

  void _resetSwipeGesture() {
    _swipeStartPosition = null;
    _swipeGestureConsumed = false;
  }

  Future<void> _loadCurrentVideoIntoWebView() async {
    if (_feed.isEmpty) return;
    _lastTrackedPositionMs = 0;
    _playerStateCode = -1;
    _playbackErrorCode = null;
    _playerCurrentTimeSeconds = 0;
    _playerDurationSeconds = 0;
    _playerReady = false;

    final videoId = _feed[_currentIndex].videoId;
    final html = _buildYouTubeEmbedHtml(videoId);
    await _webViewController.loadHtmlString(html, baseUrl: _appBaseUrl);
    if (mounted) {
      setState(() {});
    }
  }

  String _buildYouTubeEmbedHtml(String videoId) {
    final safeVideoId = jsonEncode(videoId);
    final safeOrigin = jsonEncode(_appBaseUrl);

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="referrer" content="strict-origin-when-cross-origin">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #030806;
        overflow: hidden;
      }
      #player, iframe {
        position: fixed;
        inset: 0;
        width: 100%;
        height: 100%;
        border: 0;
        background: #030806;
      }
    </style>
  </head>
  <body>
    <div id="player"></div>
    <script>
      let player = null;
      let tickHandle = null;
      const videoId = $safeVideoId;
      const appOrigin = $safeOrigin;

      function postBridge(payload) {
        if (window.PlaybackBridge && window.PlaybackBridge.postMessage) {
          window.PlaybackBridge.postMessage(JSON.stringify(payload));
        }
      }

      function emitTick() {
        if (!player || typeof player.getCurrentTime !== 'function') return;
        try {
          postBridge({
            type: 'tick',
            currentTime: Number(player.getCurrentTime() || 0),
            duration: Number(player.getDuration() || 0),
            playerState: Number(player.getPlayerState ? player.getPlayerState() : -1),
            videoId: videoId
          });
        } catch (_) {}
      }

      function ensureTicker() {
        if (tickHandle) clearInterval(tickHandle);
        tickHandle = setInterval(emitTick, 800);
      }

      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      function onYouTubeIframeAPIReady() {
        player = new YT.Player('player', {
          videoId: videoId,
          playerVars: {
            autoplay: 1,
            playsinline: 1,
            controls: 1,
            rel: 0,
            enablejsapi: 1,
            origin: appOrigin,
            widget_referrer: appOrigin
          },
          events: {
            onReady: function(event) {
              ensureTicker();
              postBridge({ type: 'ready', videoId: videoId });
              event.target.playVideo();
            },
            onStateChange: function(event) {
              postBridge({ type: 'state', state: Number(event.data), videoId: videoId });
              if (event.data === YT.PlayerState.PLAYING || event.data === YT.PlayerState.BUFFERING) {
                ensureTicker();
              }
              if (event.data === YT.PlayerState.ENDED) {
                emitTick();
                postBridge({ type: 'ended', videoId: videoId });
              }
            },
            onError: function(event) {
              postBridge({ type: 'error', error: Number(event.data), videoId: videoId });
            }
          }
        });
      }
    </script>
  </body>
</html>
''';
  }

  void _handlePlayerBridgeMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'] as String? ?? '';
      switch (type) {
        case 'ready':
          _playerReady = true;
          break;
        case 'state':
          _playerStateCode = (decoded['state'] as num?)?.toInt() ?? -1;
          break;
        case 'tick':
          _playerStateCode = (decoded['playerState'] as num?)?.toInt() ?? _playerStateCode;
          _playerCurrentTimeSeconds =
              (decoded['currentTime'] as num?)?.toDouble() ?? _playerCurrentTimeSeconds;
          _playerDurationSeconds =
              (decoded['duration'] as num?)?.toDouble() ?? _playerDurationSeconds;
          break;
        case 'ended':
          _playerStateCode = 0;
          unawaited(_handleEndedShortPlayback());
          break;
        case 'error':
          final code = (decoded['error'] as num?)?.toInt();
          if (!mounted) return;
          setState(() {
            _playbackErrorCode = code;
          });
          break;
      }
    } catch (_) {}
  }

  bool get _hasRecoverablePlaybackError =>
      _playbackErrorCode == 150 ||
      _playbackErrorCode == 152 ||
      _playbackErrorCode == 153;

  void _syncProgressFromSnapshot(ShortsProgressSnapshot snapshot) {
    _cycleCompletedShorts = snapshot.completedShortsInCycle;
    _cycleWatchMs = snapshot.watchMsInCycle;
    _bonusProgressShorts = snapshot.bonusProgressShorts;
    _pendingAdBreakShorts = snapshot.pendingAdBreakShorts;
    _pendingAdBreakAttempted = snapshot.pendingAdBreakAttempted;
  }

  Future<void> _countCurrentShortIfEligible({bool forceComplete = false}) async {
    if (_feed.isEmpty) return;
    final item = _feed[_currentIndex];
    if (_countedShortIds.contains(item.id)) return;
    if (!forceComplete) return;
    _countedShortIds.add(item.id);
    await _handleCompletedShort();
  }

  Future<void> _handleEndedShortPlayback() async {
    final shouldAdvance = _currentIndex < _feed.length - 1;
    await _countCurrentShortIfEligible(forceComplete: true);
    if (!mounted) return;
    if (shouldAdvance) {
      await _goToNextVideo();
    }
  }

  Future<void> _openCurrentVideoExternally() async {
    if (_feed.isEmpty) return;
    final uri = Uri.parse(_feed[_currentIndex].sourceUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _trackWatchTime() async {
    if (!mounted || _feed.isEmpty || _isRewardHandling || !_playerReady) return;
    if (_playerStateCode != 1 && _playerStateCode != 3) return;

    final positionMs = (_playerCurrentTimeSeconds * 1000).round();
    final durationMs = (_playerDurationSeconds * 1000).round();
    if (durationMs <= 0) return;

    _lastTrackedPositionMs = positionMs;

  }

  Future<void> _handleCompletedShort() async {
    if (_isProcessingCompletedShort) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isProcessingCompletedShort = true;
    try {
      await _firestoreService.applyUserProgress(
        uid: user.uid,
        viewsDelta: 5,
        videosWatchedDelta: 1,
      );

      final result = await ShortsProgressService.instance.markShortCompleted(
        user.uid,
      );
      if (!mounted) return;

      setState(() {
        _cycleCompletedShorts = result.snapshot.completedShortsInCycle;
        _bonusProgressShorts = result.snapshot.bonusProgressShorts;
        _pendingAdBreakShorts = result.snapshot.pendingAdBreakShorts;
        _pendingAdBreakAttempted = result.snapshot.pendingAdBreakAttempted;
      });

      if (result.adBreakReached) {
        await _presentAdBreakSheet();
      }

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

      if (result.shortsThresholdReached) {
        await _resetShortCycle();
      }
    } finally {
      _isProcessingCompletedShort = false;
    }
  }

  Future<void> _presentAdBreakSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null || _isShowingAdBreak) return;

    _isShowingAdBreak = true;
    final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => const MonetagAdBreakScreen(
              url: _monetagDirectLinkUrl,
            ),
          ),
        ) ??
        false;
    if (!mounted) return;
    final snapshot = await ShortsProgressService.instance.consumePendingAdBreak(
      user.uid,
    );
    if (!mounted) return;
    setState(() {
      _pendingAdBreakShorts = snapshot.pendingAdBreakShorts;
      _pendingAdBreakAttempted = snapshot.pendingAdBreakAttempted;
    });
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad closed. Continuing to the next short.'),
        ),
      );
    }
    _isShowingAdBreak = false;
  }

  Future<void> _resetShortCycle() async {
    if (_isRewardHandling) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    _isRewardHandling = true;
    final snapshot = await ShortsProgressService.instance.consumeRewardCycle(
      user.uid,
    );

    if (!mounted) return;
    setState(() {
      _syncProgressFromSnapshot(snapshot);
    });
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
                child: _ShortsPlayerBackdrop(
                  controller: _webViewController,
                  thumbnailUrl: _feed[_currentIndex].thumbnailUrl,
                ),
              ),
              Positioned.fill(
                child: _ShortVideoPage(item: _feed[_currentIndex]),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _onSwipePointerDown,
                  onPointerMove: _onSwipePointerMove,
                  onPointerUp: (_) => _resetSwipeGesture(),
                  onPointerCancel: (_) => _resetSwipeGesture(),
                  child: const SizedBox.expand(),
                ),
              ),
              if (_hasRecoverablePlaybackError)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: _OverlayCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Playback needs a fallback',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This device is blocking YouTube embed playback (error $_playbackErrorCode). Open the video in YouTube, or update Android System WebView, Chrome and YouTube.',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _loadCurrentVideoIntoWebView,
                                        child: const Text('Retry'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _openCurrentVideoExternally,
                                        child: const Text('Open in YouTube'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
                                              Navigator.of(context).pushNamed(AppRoutes.inbox);
                                            },
                                          ),
                                          if (unread > 0)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary,
                                                  borderRadius: BorderRadius.circular(999),
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
                                          Navigator.of(context).pushNamed(AppRoutes.settings);
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: AppTheme.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: AppTheme.primary.withOpacity(0.28),
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
  });

  final ShortVideoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        fit: StackFit.expand,
        children: [
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

class _ShortsPlayerBackdrop extends StatelessWidget {
  const _ShortsPlayerBackdrop({
    required this.controller,
    this.thumbnailUrl,
  });

  final WebViewController controller;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl != null)
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        WebViewWidget(controller: controller),
      ],
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
