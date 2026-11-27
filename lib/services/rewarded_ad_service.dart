import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedAdProvider {
  auto,
  uswa,
  mobfox,
  startio,
  liftoff,
  gravite,
  admob,
  appodeal,
  unity,
  meta,
}

enum _RewardedNetwork {
  uswa,
  mobfox,
  gravite,
  admob,
  appodeal,
  unity,
  appnext,
  meta,
  startio,
}

class RewardedAdService {
  factory RewardedAdService() => _instance;

  RewardedAdService._internal() {
    unawaited(preloadRewardedAd());
  }

  static final RewardedAdService _instance = RewardedAdService._internal();
  static const String rewardedAdUnitId =
      'ca-app-pub-7683034036748999/1933132998';
  static const bool disableOtherLegacySdkAds = false;
  static const MethodChannel _channel =
      MethodChannel('com.videomoney.app/rewarded_video');
  static const String adUnavailableMessage =
      'No ad available right now. Please try again in a moment.';
  static const String rewardDeliveryFailedMessage =
      'The ad finished, but we could not update your balance. Please try again.';
  static const Duration _networkCooldownDuration = Duration(minutes: 10);
  static const Duration _graviteCloseCompletionGrace = Duration(seconds: 12);
  static const Duration _uswaSlowLoadTimeout = Duration(seconds: 15);
  static const Duration _uswaLoadRetryInterval = Duration(seconds: 3);
  // AdMob is the primary rewarded provider again. It uses the same
  // google_mobile_ads rewarded slot that used to be labelled "USWA", so the
  // slot is now surfaced as AdMob and USWA is temporarily disabled (kept out
  // of every selection order). Gravite stays in the chain as the fallback for
  // when AdMob has no fill.
  static const List<_RewardedNetwork> _priorityOrder = [
    _RewardedNetwork.admob,
    _RewardedNetwork.gravite,
  ];

  RewardedAd? _rewardedAd;
  final Map<_RewardedNetwork, bool> _nativeRewardedReady = {
    _RewardedNetwork.mobfox: false,
    _RewardedNetwork.gravite: false,
    _RewardedNetwork.appodeal: false,
    _RewardedNetwork.unity: false,
    _RewardedNetwork.appnext: false,
    _RewardedNetwork.meta: false,
    _RewardedNetwork.startio: false,
  };
  final Map<_RewardedNetwork, DateTime> _networkCooldownUntil = {};
  Completer<bool>? _nativeShowCompleter;
  FutureOr<void> Function()? _nativeRewardCallback;
  void Function(String message)? _nativeStatusCallback;
  _RewardedNetwork? _activeNativeNetwork;
  // Set while a provider is being shown/loaded so the ad-break UI can abort a
  // provider that is taking too long and move on to the next one.
  void Function()? _abortActiveAttempt;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isNativeRewardEarned = false;
  bool _methodHandlerRegistered = false;
  Timer? _nativeFlowTimeout;
  Timer? _graviteCloseGraceTimer;
  bool _activeNativeNetworkShown = false;
  bool _awaitingGraviteCompletionAfterClose = false;
  DateTime? _lastUswaLoadKick;
  Timer? _uswaRetryTimer;
  int _uswaLoadFailures = 0;

  bool get isAdReady => _rewardedAd != null;

  Future<void> preloadRewardedAd() async {
    _registerMethodHandler();
    await Future.wait([
      _invokeVoidMethod('preloadGraviteRewardedVideo'),
    ]);
    await _loadRewardedAd();
    await _refreshNativeRewardedAvailability();
  }

  Future<void> _loadRewardedAd() async {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _uswaLoadFailures = 0;
          _uswaRetryTimer?.cancel();
          _uswaRetryTimer = null;
          _logLoaded(_RewardedNetwork.admob);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _logUnavailable(
            _RewardedNetwork.admob,
            details: 'load failed: ${error.code} ${error.message}',
          );
          _scheduleUswaReload();
        },
      ),
    );
  }

  void _scheduleUswaReload() {
    // On a fresh install the first USWA load often fails while the ad SDK is
    // still warming up. Retry in the background (bounded) so the ad is ready
    // before the user reaches an ad break.
    if (_uswaLoadFailures >= 8) return;
    _uswaLoadFailures += 1;
    _uswaRetryTimer?.cancel();
    final capped = _uswaLoadFailures < 4 ? _uswaLoadFailures : 4;
    _uswaRetryTimer = Timer(Duration(seconds: 4 * capped), () {
      if (_rewardedAd != null || _isLoading) return;
      unawaited(_loadRewardedAd());
    });
  }

  void _disposeCurrentAd([RewardedAd? ad]) {
    ad?.dispose();
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  Future<void> _resetAndLoadNextAd([RewardedAd? ad]) async {
    _disposeCurrentAd(ad);
    _isShowing = false;
    unawaited(preloadRewardedAd());
  }

  Future<bool> showRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
    RewardedAdProvider provider = RewardedAdProvider.auto,
    bool closeCountsAsCompleted = false,
  }) async {
    _registerMethodHandler();
    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    // When the first network that gets picked fails to actually display a
    // creative (for example an expired USWA ad, or a native network that
    // reports "loaded" but serves nothing), fall back to the next network that
    // does have an ad instead of giving up with "no ad available". The
    // unavailable status is only surfaced once every candidate failed, so a
    // successful fallback never flashes a stale error.
    final tried = <_RewardedNetwork>{};
    void captureStatus(String message) {
      if (message == adUnavailableMessage) return;
      onAdStatus?.call(message);
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final network = await _selectNextRewardedNetwork(
        preferredProvider: provider,
        exclude: tried,
      );
      if (network == null || !tried.add(network)) break;
      if (network == _RewardedNetwork.uswa) {
        tried.add(_RewardedNetwork.admob);
      } else if (network == _RewardedNetwork.admob) {
        tried.add(_RewardedNetwork.uswa);
      }

      final outcome = network == _RewardedNetwork.uswa ||
              network == _RewardedNetwork.admob
          ? await _showGoogleRewardedAd(
              network,
              onUserEarnedReward: onUserEarnedReward,
              onAdStatus: captureStatus,
              closeCountsAsCompleted: closeCountsAsCompleted,
            )
          : await _showNativeRewardedAd(
              network,
              onUserEarnedReward: onUserEarnedReward,
              onAdStatus: captureStatus,
            );

      if (outcome.shown) {
        return outcome.rewarded;
      }
      debugPrint(
        '[Ads][rewarded] ${_labelForNetwork(network)} did not show; '
        'trying the next network.',
      );
    }

    unawaited(preloadRewardedAd());
    onAdStatus?.call(adUnavailableMessage);
    return false;
  }

  /// Called from the ad-break UI when the user taps "No ad? Click next".
  ///
  /// Aborts the provider that is currently taking too long so the ongoing
  /// [showRewardedAd] loop immediately moves on to the next network in the
  /// chain instead of waiting for the before-show timeout to expire.
  void skipCurrentRewardedAttempt() {
    final abort = _abortActiveAttempt;
    _abortActiveAttempt = null;
    abort?.call();
  }

  Future<({bool rewarded, bool shown})> _showGoogleRewardedAd(
    _RewardedNetwork network, {
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
    bool closeCountsAsCompleted = false,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      unawaited(preloadRewardedAd());
      onAdStatus?.call(adUnavailableMessage);
      return (rewarded: false, shown: false);
    }

    final completer = Completer<bool>();
    var rewardEarned = false;
    var adShown = false;
    Timer? adMobFlowTimeout;
    _rewardedAd = null;
    _isShowing = true;

    void completeUswaFlow(
      bool result, {
      bool reloadNextAd = true,
    }) {
      adMobFlowTimeout?.cancel();
      adMobFlowTimeout = null;
      if (reloadNextAd) {
        unawaited(_resetAndLoadNextAd(ad));
      } else {
        _isShowing = false;
      }
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    // Lets the ad-break UI abort this provider when the user taps
    // "No ad? Click next", so the caller's loop moves on to the next network
    // instead of waiting out the full before-show timeout.
    void abortActiveAttempt() {
      if (completer.isCompleted || adShown) return;
      debugPrint(
        '[Ads][rewarded] ${_labelForNetwork(network)} skipped by user.',
      );
      completeUswaFlow(false);
    }

    _abortActiveAttempt = abortActiveAttempt;

    void armUswaTimeout({required bool beforeShow}) {
      adMobFlowTimeout?.cancel();
      adMobFlowTimeout = Timer(
        beforeShow ? const Duration(seconds: 12) : const Duration(seconds: 120),
        () {
          if (completer.isCompleted) return;
          if (beforeShow) {
            _markNetworkCoolingOff(network, 'timeout before show');
            _logUnavailable(network, details: 'timeout before show');
            onAdStatus?.call(adUnavailableMessage);
            ad.dispose();
            completeUswaFlow(false);
            return;
          }
          // The ad was shown but never reported a dismissal in time. Long
          // creatives (for example a sequence that needs several "close"
          // taps) can run past the old 45s window, so do not cool the network
          // down for that, and still count the view when closing counts as
          // completion so the user keeps the reward.
          final counted = closeCountsAsCompleted ? adShown : rewardEarned;
          debugPrint(
            '[Ads][rewarded] ${_labelForNetwork(network)} timeout after show '
            '(counted=$counted).',
          );
          if (!counted) {
            onAdStatus?.call(adUnavailableMessage);
          }
          ad.dispose();
          completeUswaFlow(counted);
        },
      );
    }

    armUswaTimeout(beforeShow: true);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShown = true;
        _logShown(network);
        armUswaTimeout(beforeShow: false);
      },
      onAdDismissedFullScreenContent: (ad) async {
        completeUswaFlow(closeCountsAsCompleted ? adShown : rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        _markNetworkCoolingOff(
          network,
          'show failed: ${error.code} ${error.message}',
        );
        _logUnavailable(
          network,
          details: 'show failed: ${error.code} ${error.message}',
        );
        onAdStatus?.call(adUnavailableMessage);
        completeUswaFlow(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) async {
        try {
          await onUserEarnedReward();
          rewardEarned = true;
        } catch (_) {
          rewardEarned = false;
          onAdStatus?.call(rewardDeliveryFailedMessage);
        }
      },
    );

    if (!adShown) {
      armUswaTimeout(beforeShow: true);
    }

    final rewarded = await completer.future;
    _abortActiveAttempt = null;
    return (rewarded: rewarded, shown: adShown);
  }

  Future<({bool rewarded, bool shown})> _showNativeRewardedAd(
    _RewardedNetwork network, {
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    final showMethod = _showMethodForNetwork(network);
    if (showMethod == null) {
      return (rewarded: false, shown: false);
    }

    _nativeShowCompleter = Completer<bool>();
    _nativeRewardCallback = onUserEarnedReward;
    _nativeStatusCallback = onAdStatus;
    _activeNativeNetwork = network;
    _isNativeRewardEarned = false;
    _activeNativeNetworkShown = false;
    _awaitingGraviteCompletionAfterClose = false;
    _graviteCloseGraceTimer?.cancel();
    _graviteCloseGraceTimer = null;
    _isShowing = true;
    _armNativeFlowTimeout(network, beforeShow: true);
    _abortActiveAttempt = () {
      if (_activeNativeNetwork != network || _activeNativeNetworkShown) return;
      debugPrint(
        '[Ads][rewarded] ${_labelForNetwork(network)} skipped by user.',
      );
      _completeNativeRewardedFlow(false, reloadNextAd: true);
    };

    final shown = await _channel.invokeMethod<bool>(showMethod) ?? false;
    if (!shown) {
      _logUnavailable(network);
      _completeNativeRewardedFlow(false, reloadNextAd: true);
      return (rewarded: false, shown: false);
    }

    _logShown(network);
    final completer = _nativeShowCompleter!;
    final rewarded = await completer.future;
    _abortActiveAttempt = null;
    return (rewarded: rewarded, shown: true);
  }

  Future<_RewardedNetwork?> _selectNextRewardedNetwork({
    required RewardedAdProvider preferredProvider,
    Set<_RewardedNetwork> exclude = const {},
  }) async {
    await _refreshNativeRewardedAvailability();

    // Drop the networks that already failed to show an ad in this call so the
    // caller can fall back to a different network that does have creative.
    List<_RewardedNetwork> candidates(List<_RewardedNetwork> order) =>
        order.where((network) => !exclude.contains(network)).toList(
              growable: false,
            );

    if (preferredProvider == RewardedAdProvider.uswa ||
        preferredProvider == RewardedAdProvider.admob) {
      // USWA is temporarily disabled; the shared google_mobile_ads slot is
      // surfaced as AdMob, with Gravite kept as the fallback.
      return _selectFirstReadyWithRetry(candidates(const [
        _RewardedNetwork.admob,
        _RewardedNetwork.gravite,
      ]));
    }
    if (preferredProvider == RewardedAdProvider.appodeal) {
      return _selectFirstReadyWithRetry(candidates(const [
        _RewardedNetwork.admob,
        _RewardedNetwork.gravite,
      ]));
    }
    if (preferredProvider == RewardedAdProvider.unity &&
        !exclude.contains(_RewardedNetwork.unity)) {
      await _givePreferredNetworkOneMoreChance(_RewardedNetwork.unity);
      if (_isRewardedReady(_RewardedNetwork.unity)) {
        return _RewardedNetwork.unity;
      }
      // Unity had no ad; fall through to the generic order so another network
      // can still serve the ad.
    }
    if (preferredProvider == RewardedAdProvider.gravite) {
      return _selectFirstReadyWithRetry(candidates(const [
        _RewardedNetwork.gravite,
        _RewardedNetwork.admob,
      ]));
    }
    if (preferredProvider == RewardedAdProvider.liftoff) {
      return _selectFirstReadyWithRetry(candidates(const [
        _RewardedNetwork.admob,
        _RewardedNetwork.gravite,
      ]));
    }
    return _selectFirstReadyWithRetry(candidates(_autoRotationOrder()));
  }

  /// AdMob is the primary rewarded provider and Gravite only steps in when
  /// AdMob has no fill, so the automatic order stays fixed (AdMob first).
  List<_RewardedNetwork> _autoRotationOrder() => _priorityOrder;

  Future<_RewardedNetwork?> _selectFirstReadyWithRetry(
    List<_RewardedNetwork> order,
  ) async {
    for (final network in order) {
      if (_isRewardedReady(network)) {
        debugPrint('[Ads][rewarded] selected ${_labelForNetwork(network)}.');
        return network;
      }
    }
    var googleSlotWaited = false;
    for (final network in order) {
      // USWA and AdMob share the same google_mobile_ads RewardedAd slot, so
      // wait for the slow first load only once instead of burning the timeout
      // twice.
      if (network == _RewardedNetwork.uswa ||
          network == _RewardedNetwork.admob) {
        if (googleSlotWaited) continue;
        googleSlotWaited = true;
        // On a fresh install the very first load can take a while (cold SDK +
        // first server round trip), so wait for it instead of failing fast and
        // leaving the ad break hanging while the short keeps playing. When the
        // slot still has no ad it is cooled off, so the loop moves on to Gravite
        // instead of retrying the slot on every ad break.
        if (await _awaitUswaAdReady()) {
          debugPrint(
            '[Ads][rewarded] selected ${_labelForNetwork(network)} after slow load.',
          );
          return network;
        }
        continue;
      }
      await _givePreferredNetworkOneMoreChance(network);
      if (_isRewardedReady(network)) {
        debugPrint(
          '[Ads][rewarded] selected ${_labelForNetwork(network)} after retry.',
        );
        return network;
      }
    }
    return null;
  }

  Future<bool> _awaitUswaAdReady() async {
    if (_isUswaSlotCoolingDown()) return false;
    final deadline = DateTime.now().add(_uswaSlowLoadTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_rewardedAd != null) return true;
      if (!_isLoading) {
        final lastKick = _lastUswaLoadKick;
        if (lastKick == null ||
            DateTime.now().difference(lastKick) > _uswaLoadRetryInterval) {
          _lastUswaLoadKick = DateTime.now();
          unawaited(_loadRewardedAd());
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (_rewardedAd != null) return true;
    // The shared Google slot still has no ad (for example no fill in this
    // region). Cool the whole AdMob/USWA slot off so the next ad break goes
    // straight to Gravite instead of waiting on it all over again.
    _markNetworkCoolingOff(_RewardedNetwork.admob, 'no ad available');
    return false;
  }

  Future<void> _givePreferredNetworkOneMoreChance(
    _RewardedNetwork preferredNetwork,
  ) async {
    if (_isRewardedReady(preferredNetwork)) return;
    await _reloadNativeRewardedNetwork(preferredNetwork);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _refreshNativeRewardedAvailability();
  }

  Future<void> _refreshNativeRewardedAvailability() async {
    _updateNativeAvailability(
      _RewardedNetwork.gravite,
      await _channel.invokeMethod<bool>('isGraviteRewardedVideoLoaded') ?? false,
    );
  }

  bool _isRewardedReady(_RewardedNetwork network) {
    if (_isNetworkCoolingDown(network)) {
      return false;
    }
    if (network == _RewardedNetwork.uswa ||
        network == _RewardedNetwork.admob) {
      // USWA and AdMob share a single RewardedAd slot, so a cooldown on either
      // must block both. Otherwise the selector would silently fall back to
      // AdMob and end up showing the very same (empty) USWA creative again
      // instead of moving on to Gravite.
      if (_isUswaSlotCoolingDown()) return false;
      return _rewardedAd != null;
    }
    return _nativeRewardedReady[network] ?? false;
  }

  bool _isUswaSlotCoolingDown() =>
      _isNetworkCoolingDown(_RewardedNetwork.uswa) ||
      _isNetworkCoolingDown(_RewardedNetwork.admob);

  void _registerMethodHandler() {
    if (_methodHandlerRegistered) return;
    _channel.setMethodCallHandler(_handleNativeMethodCall);
    _methodHandlerRegistered = true;
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGraviteRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.gravite, true);
        break;
      case 'onGraviteRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.gravite);
        _updateNativeAvailability(_RewardedNetwork.gravite, false);
        break;
      case 'onGraviteRewardedVideoCompleted':
        await _grantNativeReward();
        if (_activeNativeNetwork == _RewardedNetwork.gravite &&
            _awaitingGraviteCompletionAfterClose) {
          _completeNativeRewardedFlow(true, reloadNextAd: true);
        }
        break;
      case 'onGraviteRewardedVideoClosed':
        _handleGraviteRewardedClose();
        break;
      case 'onGraviteRewardedVideoError':
        _markNetworkCoolingOff(_RewardedNetwork.gravite, 'native error');
        _updateNativeAvailability(_RewardedNetwork.gravite, false);
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      default:
        break;
    }
  }

  Future<void> _grantNativeReward() async {
    final callback = _nativeRewardCallback;
    if (callback == null || _isNativeRewardEarned) return;
    try {
      await callback();
      _isNativeRewardEarned = true;
    } catch (_) {
      _isNativeRewardEarned = false;
      _nativeStatusCallback?.call(rewardDeliveryFailedMessage);
    }
  }

  void _handleGraviteRewardedClose() {
    if (_activeNativeNetwork != _RewardedNetwork.gravite) {
      _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
      return;
    }
    if (_isNativeRewardEarned || !_activeNativeNetworkShown) {
      _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
      return;
    }
    if (_awaitingGraviteCompletionAfterClose) {
      return;
    }

    _awaitingGraviteCompletionAfterClose = true;
    _nativeFlowTimeout?.cancel();
    _nativeFlowTimeout = null;
    _graviteCloseGraceTimer?.cancel();
    _graviteCloseGraceTimer = Timer(_graviteCloseCompletionGrace, () {
      if (_activeNativeNetwork != _RewardedNetwork.gravite) return;
      if (!_isNativeRewardEarned) {
        _markNetworkCoolingOff(
          _RewardedNetwork.gravite,
          'closed without reward callback',
        );
      }
      _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
    });
  }

  void _completeNativeRewardedFlow(
    bool rewardGranted, {
    required bool reloadNextAd,
  }) {
    _nativeFlowTimeout?.cancel();
    _nativeFlowTimeout = null;
    _graviteCloseGraceTimer?.cancel();
    _graviteCloseGraceTimer = null;
    _isShowing = false;

    final completer = _nativeShowCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(rewardGranted);
    }

    final network = _activeNativeNetwork;
    _nativeShowCompleter = null;
    _nativeRewardCallback = null;
    _nativeStatusCallback = null;
    _activeNativeNetwork = null;
    _isNativeRewardEarned = false;
    _activeNativeNetworkShown = false;
    _awaitingGraviteCompletionAfterClose = false;

    if (reloadNextAd) {
      unawaited(_reloadNativeRewardedNetwork(network));
    }
  }

  void _markNativeAdShown(_RewardedNetwork network) {
    if (_activeNativeNetwork != network) return;
    _activeNativeNetworkShown = true;
    _armNativeFlowTimeout(network, beforeShow: false);
  }

  void _armNativeFlowTimeout(
    _RewardedNetwork network, {
    required bool beforeShow,
  }) {
    _nativeFlowTimeout?.cancel();
    final timeout = beforeShow
        ? const Duration(seconds: 12)
        : network == _RewardedNetwork.appodeal
        ? const Duration(seconds: 45)
        : const Duration(seconds: 40);
    _nativeFlowTimeout = Timer(timeout, () {
      if (_activeNativeNetwork != network) return;
      final details = beforeShow
          ? 'timeout before show'
          : 'timeout after show';
      _markNetworkCoolingOff(network, details);
      _nativeStatusCallback?.call(adUnavailableMessage);
      _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
    });
  }

  Future<void> _reloadNativeRewardedNetwork(_RewardedNetwork? network) async {
    switch (network) {
      case _RewardedNetwork.uswa:
        await _loadRewardedAd();
        return;
      case _RewardedNetwork.mobfox:
        await _invokeVoidMethod('preloadMobFoxRewardedVideo');
        return;
      case _RewardedNetwork.gravite:
        await _invokeVoidMethod('preloadGraviteRewardedVideo');
        return;
      case _RewardedNetwork.appodeal:
        await _invokeVoidMethod('preloadAppodealRewardedVideo');
        return;
      case _RewardedNetwork.unity:
        await _invokeVoidMethod('preloadUnityRewardedVideo');
        return;
      case _RewardedNetwork.appnext:
        await _invokeVoidMethod('preloadAppnextRewardedVideo');
        return;
      case _RewardedNetwork.meta:
        await _invokeVoidMethod('preloadMetaRewardedInterstitial');
        return;
      case _RewardedNetwork.startio:
        await _invokeVoidMethod('preloadStartioRewardedVideo');
        return;
      case _RewardedNetwork.admob:
      case null:
        await _loadRewardedAd();
        return;
    }
  }

  Future<void> _invokeVoidMethod(String method) async {
    await _channel.invokeMethod<void>(method);
  }

  void _updateNativeAvailability(_RewardedNetwork network, bool isReady) {
    final previous = _nativeRewardedReady[network];
    _nativeRewardedReady[network] = isReady;
    if (previous == isReady) return;
    if (isReady) {
      _logLoaded(network);
    } else {
      _logUnavailable(network);
    }
  }

  bool _isNetworkCoolingDown(_RewardedNetwork network) {
    final until = _networkCooldownUntil[network];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _networkCooldownUntil.remove(network);
      return false;
    }
    return true;
  }

  void _markNetworkCoolingOff(_RewardedNetwork network, String reason) {
    _networkCooldownUntil[network] = DateTime.now().add(_networkCooldownDuration);
    debugPrint(
      '[Ads][rewarded] ${_labelForNetwork(network)} cooldown for '
      '${_networkCooldownDuration.inMinutes}m: $reason',
    );
  }

  String _labelForNetwork(_RewardedNetwork network) {
    return switch (network) {
      _RewardedNetwork.uswa => 'USWA',
      _RewardedNetwork.mobfox => 'MobFox',
      _RewardedNetwork.gravite => 'Gravite',
      _RewardedNetwork.admob => 'AdMob',
      _RewardedNetwork.appodeal => 'Appodeal',
      _RewardedNetwork.unity => 'Unity',
      _RewardedNetwork.appnext => 'Appnext',
      _RewardedNetwork.meta => 'Meta',
      _RewardedNetwork.startio => 'Start.io',
    };
  }

  String? _showMethodForNetwork(_RewardedNetwork network) {
    return switch (network) {
      _RewardedNetwork.uswa => null,
      _RewardedNetwork.mobfox => 'showMobFoxRewardedVideo',
      _RewardedNetwork.gravite => 'showGraviteRewardedVideo',
      _RewardedNetwork.appodeal => 'showAppodealRewardedVideo',
      _RewardedNetwork.unity => 'showUnityRewardedVideo',
      _RewardedNetwork.appnext => 'showAppnextRewardedVideo',
      _RewardedNetwork.meta => 'showMetaRewardedInterstitial',
      _RewardedNetwork.startio => 'showStartioRewardedVideo',
      _RewardedNetwork.admob => null,
    };
  }

  void _logLoaded(_RewardedNetwork network) {
    debugPrint('[Ads][rewarded] ${_labelForNetwork(network)} loaded.');
  }

  void _logShown(_RewardedNetwork network) {
    debugPrint('[Ads][rewarded] ${_labelForNetwork(network)} shown.');
  }

  void _logUnavailable(_RewardedNetwork network, {String? details}) {
    final suffix = details == null || details.isEmpty ? '' : ' ($details)';
    debugPrint(
      '[Ads][rewarded] ${_labelForNetwork(network)} unavailable$suffix.',
    );
  }
}
