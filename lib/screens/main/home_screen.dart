import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../models/players_are_gamers_profile.dart';
import '../../models/short_video_item.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pag_matchmaking_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/presence_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/shorts_progress_service.dart';
import '../../services/videomoney_ad_sdk.dart';
import '../../services/video_feed_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_int_text.dart';
import 'players_are_gamers_webview_screen.dart';
import 'shorts_ad_break_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.isActiveTab = true,
    this.recoveryToken = 0,
    this.compactMode = false,
  });

  final bool isActiveTab;
  final int recoveryToken;
  final bool compactMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const bool _disableAdsForTesting = false;
  static const String _appBaseUrl = 'https://com.videomoney.app';
  static const String _youtubeDesktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final _firestoreService = FirestoreService();
  final _earningsService = EarningsService();
  final _playersAreGamersService = PlayersAreGamersService();
  final _pagMatchmakingService = PagMatchmakingService();
  final _videomoneyAdSdk = VideomoneyAdSdk.instance;
  final _videoFeedService = VideoFeedService();
  final _countedShortIds = <String>{};
  late final Stream<int> _onlineUsersCountStream =
      PresenceService.instance.watchOnlineUsersCount();
  late final WebViewController _webViewController;

  Timer? _watchTimer;
  Timer? _playlistRefreshTimer;
  Timer? _adBreakPauseEnforcer;
  List<ShortVideoItem> _feed = const [];
  int _currentIndex = 0;
  int _cycleCompletedShorts = 0;
  int _cycleWatchMs = 0;
  int _bonusProgressShorts = 0;
  bool _giftReady = false;
  int _pendingAdBreakShorts = 0;
  String _pendingAdBreakProvider = ShortsProgressService.providerAdmob;
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
  bool _resumeAfterOverlay = false;
  bool _playerSuspended = false;
  DateTime _playbackResumeBlockedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  String? _feedError;
  int? _sessionStartIndex;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    unawaited(_earningsService.preloadRewardedVideo());
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

    final cachedFeed = await _videoFeedService.loadCachedFeed();
    if (mounted && cachedFeed.isNotEmpty) {
      setState(() {
        _feed = cachedFeed;
        _currentIndex = _pickInitialFeedIndex(cachedFeed.length);
        _isLoadingFeed = false;
      });
      unawaited(_loadCurrentVideoIntoWebView());
    }

    try {
      final currentVideoId =
          _feed.isNotEmpty ? _feed[_currentIndex.clamp(0, _feed.length - 1)].videoId : null;
      final feed = await _videoFeedService.loadFeed(userId: user.uid);
      final progress = await ShortsProgressService.instance.load(user.uid);

      if (!mounted) return;
      final nextIndex = currentVideoId == null
          ? _pickInitialFeedIndex(feed.length)
          : feed.indexWhere((item) => item.videoId == currentVideoId);
      setState(() {
        _feed = feed;
        _currentIndex = (nextIndex < 0 || nextIndex >= feed.length)
            ? _pickInitialFeedIndex(feed.length)
            : nextIndex;
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
        _feedError = _formatFeedError(error);
      });
    }
  }

  String _formatFeedError(Object error) {
    final text = error.toString();
    if (text.contains('Unable to load playlist feed (403)') ||
        text.contains('Unable to validate embeddable playlist items (403)')) {
      return 'YouTube blokkeerde de playlist-API. De app schakelt over naar de publieke playlist zodra je opnieuw ververst.';
    }
    return text;
  }

  int _pickInitialFeedIndex(int feedLength) {
    if (feedLength <= 1) return 0;
    _sessionStartIndex ??= _random.nextInt(feedLength);
    if (_sessionStartIndex! >= feedLength) {
      _sessionStartIndex = _sessionStartIndex! % feedLength;
    }
    return _sessionStartIndex!;
  }

  Future<void> _refreshFeedSilently() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final currentVideoId =
          _feed.isNotEmpty ? _feed[_currentIndex].videoId : null;
      final freshFeed = await _videoFeedService.loadFeed(userId: user.uid);
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
      if (widget.isActiveTab) {
        await _loadCurrentVideoIntoWebView(force: true);
      } else {
        _playerSuspended = true;
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive = !oldWidget.isActiveTab && widget.isActiveTab;
    final recoveryRequested =
        widget.isActiveTab && oldWidget.recoveryToken != widget.recoveryToken;
    if (!becameActive && !recoveryRequested) return;
    if (widget.isActiveTab) {
      unawaited(_earningsService.preloadRewardedVideo());
      if (_playerSuspended) {
        unawaited(_loadCurrentVideoIntoWebView(force: true));
      } else {
        unawaited(_restorePlaybackAfterAdBreak());
      }
    } else {
      unawaited(_suspendPlayback(unloadPlayer: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchTimer?.cancel();
    _playlistRefreshTimer?.cancel();
    _adBreakPauseEnforcer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.isActiveTab) {
          unawaited(_earningsService.preloadRewardedVideo());
        }
        if (_isShowingAdBreak) {
          unawaited(_pausePlayback());
        } else {
          unawaited(_resumePlaybackIfNeeded());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_pausePlayback());
        break;
    }
  }

  Future<void> _showVideoAtIndex(int index) async {
    if (index < 0 || index >= _feed.length || index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (widget.isActiveTab) {
      await _loadCurrentVideoIntoWebView(force: true);
    } else {
      _playerSuspended = true;
    }
  }

  Future<void> _goToNextVideo() async {
    if (_feed.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _feed.length;
    await _showVideoAtIndex(nextIndex);
  }

  Future<void> _goToPreviousVideo() async {
    if (_feed.isEmpty) return;
    final previousIndex = (_currentIndex - 1 + _feed.length) % _feed.length;
    await _showVideoAtIndex(previousIndex);
  }

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

  Future<void> _loadCurrentVideoIntoWebView({bool force = false}) async {
    if (_feed.isEmpty) return;
    if (!widget.isActiveTab && !force) {
      _playerSuspended = true;
      return;
    }
    _playerSuspended = false;
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

  Future<void> _pausePlayback() async {
    try {
      await _webViewController.runJavaScript('''
        try {
          window.__vmForcePaused = true;
          if (window.player && typeof window.player.mute === 'function') {
            window.player.mute();
          }
          if (window.player && typeof window.player.pauseVideo === 'function') {
            window.player.pauseVideo();
          }
          if (window.player && typeof window.player.stopVideo === 'function') {
            window.player.stopVideo();
          }
        } catch (_) {}
      ''');
    } catch (_) {}
  }

  Future<void> _suspendPlayback({bool unloadPlayer = false}) async {
    _playerSuspended = unloadPlayer;
    _blockPlaybackResume(const Duration(minutes: 10));
    await _pausePlayback();
    if (!unloadPlayer) return;
    try {
      _playerReady = false;
      _playerStateCode = -1;
      _playerCurrentTimeSeconds = 0;
      _playerDurationSeconds = 0;
      await _webViewController.loadHtmlString(
        _buildBlankPlayerHtml(),
        baseUrl: _appBaseUrl,
      );
    } catch (_) {}
  }

  Future<void> _resumePlaybackIfNeeded() async {
    if (!widget.isActiveTab || _isShowingAdBreak || !_playerReady || _playerSuspended) {
      return;
    }
    if (DateTime.now().isBefore(_playbackResumeBlockedUntil)) return;
    try {
      await _webViewController.runJavaScript('''
        try {
          window.__vmForcePaused = false;
          if (window.player && typeof window.player.unMute === 'function') {
            window.player.unMute();
          }
          if (window.player && typeof window.player.playVideo === 'function') {
            window.player.playVideo();
          }
        } catch (_) {}
      ''');
    } catch (_) {}
  }

  Future<void> _restorePlaybackAfterAdBreak() async {
    if (!mounted || !widget.isActiveTab || _isShowingAdBreak || _playerSuspended) {
      return;
    }

    _playbackResumeBlockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

    if (!_playerReady) {
      await _loadCurrentVideoIntoWebView(force: true);
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        unawaited(_resumePlaybackIfNeeded());
      });
      return;
    }

    await _resumePlaybackIfNeeded();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || _isShowingAdBreak || _playerSuspended) return;
      if (_playerStateCode != 1) {
        unawaited(_loadCurrentVideoIntoWebView(force: true));
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          unawaited(_resumePlaybackIfNeeded());
        });
      }
    });
  }

  void _blockPlaybackResume([Duration duration = const Duration(seconds: 3)]) {
    final blockedUntil = DateTime.now().add(duration);
    if (blockedUntil.isAfter(_playbackResumeBlockedUntil)) {
      _playbackResumeBlockedUntil = blockedUntil;
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
      window.player = null;
      window.__vmForcePaused = false;
      let tickHandle = null;
      const videoId = $safeVideoId;
      const appOrigin = $safeOrigin;

      function postBridge(payload) {
        if (window.PlaybackBridge && window.PlaybackBridge.postMessage) {
          window.PlaybackBridge.postMessage(JSON.stringify(payload));
        }
      }

      function emitTick() {
        const player = window.player;
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
        window.player = new YT.Player('player', {
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
              if (!window.__vmForcePaused) {
                event.target.playVideo();
              }
            },
            onStateChange: function(event) {
              if (window.__vmForcePaused &&
                  (event.data === YT.PlayerState.PLAYING ||
                   event.data === YT.PlayerState.BUFFERING)) {
                try {
                  event.target.pauseVideo();
                  if (typeof event.target.stopVideo === 'function') {
                    event.target.stopVideo();
                  }
                } catch (_) {}
              }
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

  String _buildBlankPlayerHtml() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #030806;
      }
    </style>
  </head>
  <body></body>
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
    _giftReady = snapshot.giftReady;
    _pendingAdBreakShorts = snapshot.pendingAdBreakShorts;
    _pendingAdBreakProvider = snapshot.pendingAdBreakProvider;
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
        videosWatchedDelta: 1,
      );

      final result = await ShortsProgressService.instance.markShortCompleted(
        user.uid,
      );
      if (!mounted) return;

      setState(() {
        _cycleCompletedShorts = result.snapshot.completedShortsInCycle;
        _bonusProgressShorts = result.snapshot.bonusProgressShorts;
        _giftReady = result.snapshot.giftReady;
        _pendingAdBreakShorts = result.snapshot.pendingAdBreakShorts;
        _pendingAdBreakProvider = result.snapshot.pendingAdBreakProvider;
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
    _blockPlaybackResume(const Duration(minutes: 2));
    _adBreakPauseEnforcer?.cancel();
    _adBreakPauseEnforcer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_isShowingAdBreak) return;
      unawaited(_pausePlayback());
    });
    _resumeAfterOverlay = widget.isActiveTab && (_playerStateCode == 1 || _playerStateCode == 3);
    try {
      final pendingProvider = _pendingAdBreakProvider;
      final isAdmobBreak = pendingProvider == ShortsProgressService.providerAdmob;
      final isAppodealBreak =
          pendingProvider == ShortsProgressService.providerAppodeal;
      final isGraviteBreak =
          pendingProvider == ShortsProgressService.providerGravite;
      final isUnityBreak =
          pendingProvider == ShortsProgressService.providerUnity;
      final isRewardedTurn =
          isAdmobBreak ||
          isAppodealBreak ||
          isUnityBreak ||
          isGraviteBreak;
      final shouldFallbackToMonetag =
          isAdmobBreak || isAppodealBreak || isGraviteBreak || isUnityBreak;
      final completed =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              fullscreenDialog: false,
              builder: (pageContext) => ShortsAdBreakScreen(
                providerName: _providerLabelForAdBreak(pendingProvider),
                onPrepare: _pausePlayback,
                onStartAd: (_) async {
                  if (isRewardedTurn) {
                    var rewardedCompleted =
                        await _earningsService.showRewardedBonusAd(
                          provider: isAdmobBreak
                                  ? RewardedAdProvider.admob
                                  : isAppodealBreak
                                  ? RewardedAdProvider.appodeal
                                  : isGraviteBreak
                                  ? RewardedAdProvider.gravite
                                  : RewardedAdProvider.unity,
                          onAdStatus: (message) {
                            debugPrint('[VideomoneyAds][Home][$pendingProvider] $message');
                          },
                        );
                    if (!rewardedCompleted && shouldFallbackToMonetag) {
                      rewardedCompleted = await _videomoneyAdSdk.showInterstitial(
                        context: pageContext,
                        callbacks: VideomoneyAdCallbacks(
                          onFailed: (provider, reason) {
                            debugPrint(
                              '[VideomoneyAds][Home] ${provider.name} failed during Monetag backup fallback: '
                              '$reason',
                            );
                          },
                        ),
                      );
                    }
                    return rewardedCompleted;
                  }
                  return _videomoneyAdSdk.showInterstitial(
                    context: pageContext,
                    callbacks: VideomoneyAdCallbacks(
                      onFailed: (provider, reason) {
                        debugPrint(
                          '[VideomoneyAds][Home] ${provider.name} failed during ad break: '
                          '$reason',
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ) ??
          false;
      PlayersAreGamersAdRewardResult? rewardResult;
      if (completed) {
        final currentShortId =
            _feed.isNotEmpty && _currentIndex >= 0 && _currentIndex < _feed.length
                ? _feed[_currentIndex].id
                : 'short';
        rewardResult = await _playersAreGamersService.grantAdReward(
          adId:
              'vm-video-ad-${currentShortId}-${DateTime.now().millisecondsSinceEpoch}',
          pagCoins: 2,
          videomoneyViews: ShortsProgressService.adBreakViewsReward,
          autoCreateIfMissing: true,
        );
      }
      if (!mounted) return;
      final snapshot = await ShortsProgressService.instance.consumePendingAdBreak(
        user.uid,
      );
      if (!mounted) return;
      setState(() {
        _pendingAdBreakShorts = snapshot.pendingAdBreakShorts;
        _pendingAdBreakProvider = snapshot.pendingAdBreakProvider;
        _pendingAdBreakAttempted = snapshot.pendingAdBreakAttempted;
      });
      if (!completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmobBreak
                  ? _localizedHomeText('no_provider', provider: 'AdMob')
                  : isAppodealBreak
                  ? _localizedHomeText('no_provider', provider: 'Appodeal')
                  : isGraviteBreak
                  ? _localizedHomeText('no_provider', provider: 'Gravite')
                  : isUnityBreak
                  ? _localizedHomeText('no_provider', provider: 'Unity')
                  : _localizedHomeText('no_generic'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localizedHomeText('ad_counted'),
            ),
          ),
        );
      }
    } finally {
      _adBreakPauseEnforcer?.cancel();
      _adBreakPauseEnforcer = null;
      _isShowingAdBreak = false;
      if (_resumeAfterOverlay) {
        _resumeAfterOverlay = false;
        if (!_disableAdsForTesting) {
          unawaited(_restorePlaybackAfterAdBreak());
        }
      }
    }
  }

  String _providerLabelForAdBreak(String provider) {
    if (provider == ShortsProgressService.providerAdmob) return 'AdMob';
    if (provider == ShortsProgressService.providerAppodeal) return 'Appodeal';
    if (provider == ShortsProgressService.providerGravite) return 'Gravite';
    if (provider == ShortsProgressService.providerUnity) return 'Unity';
    if (provider == ShortsProgressService.providerMonetag) return 'Monetag';
    return 'Ad';
  }

  String _localizedHomeText(String key, {String provider = 'Ad'}) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    final values = {
      'en': {
        'ad_counted': '+1 ad counted.',
        'tap_after_three': 'After 3 shorts, tap the ad button',
        'no_provider': 'No $provider or Monetag ad available for this turn.',
        'no_generic':
            'No ad available right now. Continuing to the next short.',
      },
      'nl': {
        'ad_counted': '+1 ad geteld.',
        'tap_after_three': 'Na 3 shorts druk je op de ad-knop',
        'no_provider':
            'Geen $provider- of Monetag-ad beschikbaar voor deze beurt.',
        'no_generic':
            'Geen advertentie beschikbaar. De volgende short gaat verder.',
      },
      'hi': {
        'ad_counted': '+1 ad गिना गया।',
        'tap_after_three': '3 shorts के na ad button दबाएँ',
        'no_provider': 'इस beurt के लिए $provider या Monetag ad उपलब्ध नहीं है।',
        'no_generic': 'अभी कोई ad उपलब्ध नहीं है। अगला short जारी रहेगा।',
      },
      'de': {
        'ad_counted': '+1 Ad gezählt.',
        'tap_after_three': 'Nach 3 Shorts auf die Ad-Schaltfläche tippen',
        'no_provider': 'Kein $provider- oder Monetag-Ad für diese Runde verfügbar.',
        'no_generic': 'Zurzeit kein Ad verfügbar. Nächstes Short läuft weiter.',
      },
      'es': {
        'ad_counted': '+1 ad contado.',
        'tap_after_three': 'Después de 3 shorts, pulsa el botón del ad',
        'no_provider': 'No hay ad de $provider o Monetag disponible en este turno.',
        'no_generic': 'No hay ad disponible ahora. Continuando con el siguiente short.',
      },
      'fr': {
        'ad_counted': '+1 ad compté.',
        'tap_after_three': 'Après 3 shorts, appuyez sur le bouton ad',
        'no_provider': 'Aucun ad $provider ou Monetag disponible pour ce tour.',
        'no_generic': 'Aucun ad disponible pour le moment. Passage au short suivant.',
      },
      'ru': {
        'ad_counted': '+1 ad засчитан.',
        'tap_after_three': 'После 3 shorts нажмите кнопку ad',
        'no_provider': 'Нет доступного ad $provider или Monetag для этого раунда.',
        'no_generic': 'Сейчас нет доступного ad. Переход к следующему short.',
      },
      'el': {
        'ad_counted': '+1 ad μετρήθηκε.',
        'tap_after_three': 'Μετά από 3 shorts πάτησε το κουμπί ad',
        'no_provider': 'Δεν υπάρχει διαθέσιμο ad $provider ή Monetag για αυτή τη σειρά.',
        'no_generic': 'Δεν υπάρχει διαθέσιμο ad τώρα. Συνεχίζει το επόμενο short.',
      },
      'pt': {
        'ad_counted': '+1 ad contado.',
        'tap_after_three': 'Após 3 shorts, toque no botão do ad',
        'no_provider': 'Nenhum ad $provider ou Monetag disponível para esta ronda.',
        'no_generic': 'Nenhum ad disponível agora. A continuar para o próximo short.',
      },
      'it': {
        'ad_counted': '+1 ad conteggiato.',
        'tap_after_three': 'Dopo 3 shorts, tocca il pulsante ad',
        'no_provider': 'Nessun ad $provider o Monetag disponibile per questo turno.',
        'no_generic': 'Nessun ad disponibile ora. Si continua con il prossimo short.',
      },
      'tr': {
        'ad_counted': '+1 ad sayıldı.',
        'tap_after_three': '3 shortstan sonra ad düğmesine bas',
        'no_provider': 'Bu tur için $provider veya Monetag ad mevcut değil.',
        'no_generic': 'Şu anda ad yok. Sonraki short ile devam ediliyor.',
      },
      'ar': {
        'ad_counted': 'تم احتساب +1 ad.',
        'tap_after_three': 'بعد 3 shorts اضغط زر ad',
        'no_provider': 'لا يوجد ad من $provider أو Monetag لهذه الجولة.',
        'no_generic': 'لا يوجد ad متاح الآن. سيتم المتابعة إلى short التالي.',
      },
      'bn': {
        'ad_counted': '+1 ad গণনা হয়েছে।',
        'tap_after_three': '3 shorts-এর পরে ad বাটন চাপুন',
        'no_provider': 'এই রাউন্ডে $provider বা Monetag ad নেই।',
        'no_generic': 'এখন কোনো ad নেই। পরের short চলবে।',
      },
      'ta': {
        'ad_counted': '+1 ad எண்ணப்பட்டது.',
        'tap_after_three': '3 shorts பிறகு ad பட்டனை அழுத்தவும்',
        'no_provider': 'இந்த முறைக்கு $provider அல்லது Monetag ad இல்லை.',
        'no_generic': 'இப்போது ad இல்லை. அடுத்த short தொடரும்.',
      },
      'te': {
        'ad_counted': '+1 ad లెక్కించబడింది.',
        'tap_after_three': '3 shorts తర్వాత ad బటన్ నొక్కండి',
        'no_provider': 'ఈ టర్న్‌కు $provider లేదా Monetag ad అందుబాటులో లేదు.',
        'no_generic': 'ఇప్పుడు ad లేదు. తదుపరి short కొనసాగుతుంది.',
      },
    };
    return values[code]?[key] ?? values['en']![key]!;
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

  Future<void> _openFeaturedMatch(PagMatchmakingSignal signal) async {
    if (signal.gameUrl.trim().isEmpty) return;
    await _suspendPlayback(unloadPlayer: true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayersAreGamersWebViewScreen(
          service: _playersAreGamersService,
          initialUrl: signal.gameUrl,
        ),
      ),
    );
    if (!mounted || !widget.isActiveTab) return;
    await _loadCurrentVideoIntoWebView(force: true);
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
        final isDutch = Localizations.localeOf(context).languageCode.toLowerCase() == 'nl';
        final currentAds = appUser?.views ?? 0;
        final payoutProgress = (currentAds / FirestoreService.minimumPayoutCoins)
            .clamp(0, 1)
            .toDouble();

        final content = Stack(
            children: [
              Positioned.fill(
                child: _ShortsPlayerBackdrop(
                  controller: _webViewController,
                  thumbnailUrl: _feed[_currentIndex].thumbnailUrl,
                ),
              ),
              Positioned.fill(
                child: _ShortVideoPage(
                  item: _feed[_currentIndex],
                  bottomInset: 18,
                ),
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
                  padding: EdgeInsets.fromLTRB(
                    widget.compactMode ? 8 : 12,
                    widget.compactMode ? 8 : 10,
                    widget.compactMode ? 8 : 12,
                    widget.compactMode ? 8 : 18,
                  ),
                  child: Column(
                    children: [
                      if (!widget.compactMode)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text(
                                'VideoMoney',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
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
                          ],
                        ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: widget.compactMode ? 10 : 62),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: widget.compactMode ? 220 : 270,
                            ),
                            child: _OverlayCard(
                              padding: EdgeInsets.all(widget.compactMode ? 8 : 10),
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
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: widget.compactMode ? 18 : 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!widget.compactMode)
                                        StreamBuilder<PagMatchmakingSignal?>(
                                          stream: _pagMatchmakingService.watchFeaturedSignal(
                                            excludeUid: user.uid,
                                          ),
                                          builder: (context, matchmakingSnapshot) {
                                            final signal = matchmakingSnapshot.data;
                                            if (signal == null) {
                                              return const SizedBox.shrink();
                                            }
                                            return Flexible(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                  left: 8,
                                                  right: 8,
                                                ),
                                                child: _MatchmakingPromptCard(
                                                  gameName: signal.gameName,
                                                  onTap: () => _openFeaturedMatch(signal),
                                                ),
                                              ),
                                            );
                                          },
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
                                              widget.compactMode
                                                  ? 'Video'
                                                  : _feed[_currentIndex].category,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _localizedHomeText('tap_after_three'),
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
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _CompactProgressLine(
                                    title: l10n.progressToPayout,
                                    valueLabel:
                                        '${NumberFormat.decimalPattern().format(currentAds)} / ${NumberFormat.decimalPattern().format(FirestoreService.minimumPayoutCoins)} ads',
                                    value: payoutProgress,
                                    color: AppTheme.primary,
                                  ),
                                  if (!widget.compactMode) ...[
                                    const SizedBox(height: 8),
                                    _PlayersAreGamersProgressLine(
                                      stream: _playersAreGamersService.watchProfile(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        return widget.compactMode
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.outline.withOpacity(0.45)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: content,
                ),
              )
            : Scaffold(
                extendBody: true,
                body: content,
              );
      },
    );
  }
}

class _PlayersAreGamersProgressLine extends StatelessWidget {
  const _PlayersAreGamersProgressLine({
    required this.stream,
  });

  final Stream<PlayersAreGamersProfile?> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayersAreGamersProfile?>(
      stream: stream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final progress = (profile?.starterProgress ?? 0).clamp(0, 1).toDouble();
        return _CompactProgressLine(
          title: 'PlayersAreGamers coins',
          valueLabel: '${profile?.coins ?? 0} coins',
          value: progress,
          color: const Color(0xFF6B8BFF),
        );
      },
    );
  }
}

class _MatchmakingPromptCard extends StatelessWidget {
  const _MatchmakingPromptCard({
    required this.gameName,
    required this.onTap,
  });

  final String gameName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2015).withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF1AE47A).withOpacity(0.34),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2200FF88),
                blurRadius: 18,
                spreadRadius: -10,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gameName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Player waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1AE47A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Join now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF96FFBF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortVideoPage extends StatelessWidget {
  const _ShortVideoPage({
    required this.item,
    this.bottomInset = 18,
  });

  final ShortVideoItem item;
  final double bottomInset;

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
            bottom: bottomInset,
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
    this.showBar = true,
  });

  final String title;
  final String valueLabel;
  final double value;
  final Color color;
  final bool showBar;

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
        if (showBar) ...[
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
