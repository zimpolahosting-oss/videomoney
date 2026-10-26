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
      '/22893901953/ca-mb-app-pub-2509511211458165-tag/Uswa_com.videomoney.app_Rewarded';
  static const bool disableOtherLegacySdkAds = false;
  static const MethodChannel _channel =
      MethodChannel('com.videomoney.app/rewarded_video');
  static const String adUnavailableMessage =
      'No ad available right now. Please try again in a moment.';
  static const String rewardDeliveryFailedMessage =
      'The ad finished, but we could not update your balance. Please try again.';
  static const Duration _networkCooldownDuration = Duration(minutes: 10);
  static const Duration _graviteCloseCompletionGrace = Duration(seconds: 5);
  static const List<_RewardedNetwork> _priorityOrder = [
    _RewardedNetwork.uswa,
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
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isNativeRewardEarned = false;
  bool _methodHandlerRegistered = false;
  Timer? _nativeFlowTimeout;
  Timer? _graviteCloseGraceTimer;
  bool _activeNativeNetworkShown = false;
  bool _awaitingGraviteCompletionAfterClose = false;

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
      request: const AdManagerAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _logLoaded(_RewardedNetwork.uswa);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _logUnavailable(
            _RewardedNetwork.uswa,
            details: 'load failed: ${error.code} ${error.message}',
          );
        },
      ),
    );
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
  }) async {
    _registerMethodHandler();
    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    final network = await _selectNextRewardedNetwork(preferredProvider: provider);
    if (network == null) {
      unawaited(preloadRewardedAd());
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    switch (network) {
      case _RewardedNetwork.uswa:
      case _RewardedNetwork.admob:
        return _showUswaRewardedAd(
          onUserEarnedReward: onUserEarnedReward,
          onAdStatus: onAdStatus,
        );
      case _RewardedNetwork.mobfox:
      case _RewardedNetwork.gravite:
      case _RewardedNetwork.appodeal:
      case _RewardedNetwork.unity:
      case _RewardedNetwork.appnext:
      case _RewardedNetwork.meta:
      case _RewardedNetwork.startio:
        return _showNativeRewardedAd(
          network,
          onUserEarnedReward: onUserEarnedReward,
          onAdStatus: onAdStatus,
        );
    }
  }

  Future<bool> _showUswaRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      unawaited(preloadRewardedAd());
      onAdStatus?.call(adUnavailableMessage);
      return false;
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

    void armUswaTimeout({required bool beforeShow}) {
      adMobFlowTimeout?.cancel();
      adMobFlowTimeout = Timer(
        beforeShow ? const Duration(seconds: 12) : const Duration(seconds: 45),
        () {
          if (completer.isCompleted) return;
          final details = beforeShow
              ? 'timeout before show'
              : 'timeout after show';
          _markNetworkCoolingOff(_RewardedNetwork.uswa, details);
          _logUnavailable(_RewardedNetwork.uswa, details: details);
          onAdStatus?.call(adUnavailableMessage);
          ad.dispose();
          completeUswaFlow(rewardEarned);
        },
      );
    }

    armUswaTimeout(beforeShow: true);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShown = true;
        _logShown(_RewardedNetwork.uswa);
        armUswaTimeout(beforeShow: false);
      },
      onAdDismissedFullScreenContent: (ad) async {
        completeUswaFlow(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        _markNetworkCoolingOff(
          _RewardedNetwork.uswa,
          'show failed: ${error.code} ${error.message}',
        );
        _logUnavailable(
          _RewardedNetwork.uswa,
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

    return completer.future;
  }

  Future<bool> _showNativeRewardedAd(
    _RewardedNetwork network, {
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    final showMethod = _showMethodForNetwork(network);
    if (showMethod == null) {
      return false;
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

    final shown = await _channel.invokeMethod<bool>(showMethod) ?? false;
    if (!shown) {
      _logUnavailable(network);
      _completeNativeRewardedFlow(false, reloadNextAd: true);
      return false;
    }

    _logShown(network);
    return _nativeShowCompleter!.future;
  }

  Future<_RewardedNetwork?> _selectNextRewardedNetwork({
    required RewardedAdProvider preferredProvider,
  }) async {
    await _refreshNativeRewardedAvailability();
    if (preferredProvider == RewardedAdProvider.uswa ||
        preferredProvider == RewardedAdProvider.admob) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.uswa,
        _RewardedNetwork.admob,
        _RewardedNetwork.gravite,
      ]);
    }
    if (preferredProvider == RewardedAdProvider.appodeal) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.uswa,
        _RewardedNetwork.gravite,
        _RewardedNetwork.admob,
      ]);
    }
    if (preferredProvider == RewardedAdProvider.unity) {
      await _givePreferredNetworkOneMoreChance(_RewardedNetwork.unity);
      return _isRewardedReady(_RewardedNetwork.unity)
          ? _RewardedNetwork.unity
          : null;
    }
    if (preferredProvider == RewardedAdProvider.gravite) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.gravite,
        _RewardedNetwork.uswa,
        _RewardedNetwork.admob,
      ]);
    }
    if (preferredProvider == RewardedAdProvider.liftoff) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.uswa,
        _RewardedNetwork.admob,
        _RewardedNetwork.gravite,
      ]);
    }
    return _selectFirstReadyWithRetry(_priorityOrder);
  }

  Future<_RewardedNetwork?> _selectFirstReadyWithRetry(
    List<_RewardedNetwork> order,
  ) async {
    for (final network in order) {
      if (_isRewardedReady(network)) {
        debugPrint('[Ads][rewarded] selected ${_labelForNetwork(network)}.');
        return network;
      }
    }
    for (final network in order) {
      await _givePreferredNetworkOneMoreChance(network);
      if (_isRewardedReady(network)) {
        debugPrint('[Ads][rewarded] selected ${_labelForNetwork(network)} after retry.');
        return network;
      }
    }
    return null;
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
      return _rewardedAd != null;
    }
    return _nativeRewardedReady[network] ?? false;
  }

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
