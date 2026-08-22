import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedAdProvider {
  auto,
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
  static const List<_RewardedNetwork> _priorityOrder = [
    _RewardedNetwork.admob,
    _RewardedNetwork.appodeal,
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
  bool _activeNativeNetworkShown = false;

  bool get isAdReady => _rewardedAd != null;

  Future<void> preloadRewardedAd() async {
    _registerMethodHandler();
    await Future.wait([
      _invokeVoidMethod('preloadMobFoxRewardedVideo'),
      _invokeVoidMethod('preloadGraviteRewardedVideo'),
      _invokeVoidMethod('preloadAppodealRewardedVideo'),
      _invokeVoidMethod('preloadUnityRewardedVideo'),
      _invokeVoidMethod('preloadMetaRewardedInterstitial'),
    ]);
    await _loadRewardedAd();
    if (disableOtherLegacySdkAds) {
      debugPrint('[Ads][rewarded] Other legacy SDK ad networks temporarily disabled.');
      await _refreshNativeRewardedAvailability();
      return;
    }
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
          _logLoaded(_RewardedNetwork.admob);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _logUnavailable(
            _RewardedNetwork.admob,
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
      case _RewardedNetwork.admob:
        return _showAdMobRewardedAd(
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

  Future<bool> _showAdMobRewardedAd({
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

    void completeAdMobFlow(
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

    void armAdMobTimeout({required bool beforeShow}) {
      adMobFlowTimeout?.cancel();
      adMobFlowTimeout = Timer(
        beforeShow ? const Duration(seconds: 12) : const Duration(seconds: 75),
        () {
          if (completer.isCompleted) return;
          final details = beforeShow
              ? 'timeout before show'
              : 'timeout after show';
          _markNetworkCoolingOff(_RewardedNetwork.admob, details);
          _logUnavailable(_RewardedNetwork.admob, details: details);
          onAdStatus?.call(adUnavailableMessage);
          completeAdMobFlow(rewardEarned);
        },
      );
    }

    armAdMobTimeout(beforeShow: true);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShown = true;
        _logShown(_RewardedNetwork.admob);
        armAdMobTimeout(beforeShow: false);
      },
      onAdDismissedFullScreenContent: (ad) async {
        completeAdMobFlow(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        _markNetworkCoolingOff(
          _RewardedNetwork.admob,
          'show failed: ${error.code} ${error.message}',
        );
        _logUnavailable(
          _RewardedNetwork.admob,
          details: 'show failed: ${error.code} ${error.message}',
        );
        onAdStatus?.call(adUnavailableMessage);
        completeAdMobFlow(false);
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
      armAdMobTimeout(beforeShow: true);
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
    if (preferredProvider == RewardedAdProvider.admob) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.admob,
        _RewardedNetwork.appodeal,
        _RewardedNetwork.gravite,
      ]);
    }
    if (preferredProvider == RewardedAdProvider.appodeal) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.appodeal,
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
        _RewardedNetwork.appodeal,
        _RewardedNetwork.admob,
      ]);
    }
    if (preferredProvider == RewardedAdProvider.liftoff) {
      return _selectFirstReadyWithRetry(const [
        _RewardedNetwork.admob,
        _RewardedNetwork.appodeal,
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
      _RewardedNetwork.mobfox,
      await _channel.invokeMethod<bool>('isMobFoxRewardedVideoLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.gravite,
      await _channel.invokeMethod<bool>('isGraviteRewardedVideoLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.appodeal,
      await _channel.invokeMethod<bool>('isAppodealRewardedVideoLoaded') ??
          false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.unity,
      await _channel.invokeMethod<bool>('isUnityRewardedVideoLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.meta,
      await _channel.invokeMethod<bool>('isMetaRewardedInterstitialLoaded') ?? false,
    );
    if (disableOtherLegacySdkAds) {
      return;
    }
    _updateNativeAvailability(
      _RewardedNetwork.appnext,
      await _channel.invokeMethod<bool>('isAppnextRewardedVideoLoaded') ?? false,
    );
  }

  bool _isRewardedReady(_RewardedNetwork network) {
    if (_isNetworkCoolingDown(network)) {
      return false;
    }
    if (network == _RewardedNetwork.admob) {
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
      case 'onMobFoxRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.mobfox, true);
        break;
      case 'onMobFoxRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.mobfox);
        _updateNativeAvailability(_RewardedNetwork.mobfox, false);
        break;
      case 'onMobFoxRewardedVideoCompleted':
        await _grantNativeReward();
        break;
      case 'onMobFoxRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onMobFoxRewardedVideoError':
        _updateNativeAvailability(_RewardedNetwork.mobfox, false);
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onGraviteRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.gravite, true);
        break;
      case 'onGraviteRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.gravite);
        _updateNativeAvailability(_RewardedNetwork.gravite, false);
        break;
      case 'onGraviteRewardedVideoCompleted':
        await _grantNativeReward();
        break;
      case 'onGraviteRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onGraviteRewardedVideoError':
        _markNetworkCoolingOff(_RewardedNetwork.gravite, 'native error');
        _updateNativeAvailability(_RewardedNetwork.gravite, false);
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.appodeal, true);
        break;
      case 'onRewardedVideoFailedToLoad':
      case 'onRewardedVideoExpired':
        _updateNativeAvailability(_RewardedNetwork.appodeal, false);
        break;
      case 'onRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.appodeal);
        _updateNativeAvailability(_RewardedNetwork.appodeal, false);
        break;
      case 'onRewardedVideoFinished':
        await _grantNativeReward();
        break;
      case 'onRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onRewardedVideoShowFailed':
        _markNetworkCoolingOff(_RewardedNetwork.appodeal, 'native show failed');
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onUnityRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.unity, true);
        break;
      case 'onUnityRewardedVideoFailedToLoad':
        _updateNativeAvailability(_RewardedNetwork.unity, false);
        break;
      case 'onUnityRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.unity);
        _updateNativeAvailability(_RewardedNetwork.unity, false);
        break;
      case 'onUnityRewardedVideoFinished':
        await _grantNativeReward();
        break;
      case 'onUnityRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onUnityRewardedVideoShowFailed':
        _markNetworkCoolingOff(_RewardedNetwork.unity, 'native show failed');
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onAppnextRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.appnext, true);
        break;
      case 'onAppnextRewardedVideoOpened':
        _markNativeAdShown(_RewardedNetwork.appnext);
        _updateNativeAvailability(_RewardedNetwork.appnext, false);
        break;
      case 'onAppnextRewardedVideoEnded':
        await _grantNativeReward();
        break;
      case 'onAppnextRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onAppnextRewardedVideoError':
        _markNetworkCoolingOff(_RewardedNetwork.appnext, 'native error');
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onMetaRewardedInterstitialLoaded':
        _updateNativeAvailability(_RewardedNetwork.meta, true);
        break;
      case 'onMetaRewardedInterstitialShown':
        _markNativeAdShown(_RewardedNetwork.meta);
        _updateNativeAvailability(_RewardedNetwork.meta, false);
        break;
      case 'onMetaRewardedInterstitialClicked':
        debugPrint('[Ads][rewarded] Meta clicked.');
        break;
      case 'onMetaRewardedInterstitialCompleted':
        await _grantNativeReward();
        break;
      case 'onMetaRewardedInterstitialClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onMetaRewardedInterstitialError':
        final error = call.arguments is Map
            ? (call.arguments as Map)['error']?.toString()
            : null;
        final code = call.arguments is Map
            ? (call.arguments as Map)['code']?.toString()
            : null;
        final details = [
          if (code != null && code.isNotEmpty) 'code=$code',
          if (error != null && error.isNotEmpty) error,
        ].join(' | ');
        _markNetworkCoolingOff(
          _RewardedNetwork.meta,
          details.isEmpty ? 'native error' : details,
        );
        _nativeStatusCallback?.call(
          details.isEmpty ? adUnavailableMessage : 'Meta failed: $details',
        );
        debugPrint(
          details.isEmpty
              ? '[Ads][rewarded] Meta error.'
              : '[Ads][rewarded] Meta error: $details',
        );
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onStartioRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.startio, true);
        break;
      case 'onStartioRewardedVideoShown':
        _markNativeAdShown(_RewardedNetwork.startio);
        _updateNativeAvailability(_RewardedNetwork.startio, false);
        break;
      case 'onStartioRewardedVideoCompleted':
        await _grantNativeReward();
        break;
      case 'onStartioRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onStartioRewardedVideoError':
        _markNetworkCoolingOff(_RewardedNetwork.startio, 'native error');
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

  void _completeNativeRewardedFlow(
    bool rewardGranted, {
    required bool reloadNextAd,
  }) {
    _nativeFlowTimeout?.cancel();
    _nativeFlowTimeout = null;
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
        ? const Duration(seconds: 75)
        : const Duration(seconds: 60);
    _nativeFlowTimeout = Timer(timeout, () {
      if (_activeNativeNetwork != network) return;
      _nativeStatusCallback?.call(adUnavailableMessage);
      _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
    });
  }

  Future<void> _reloadNativeRewardedNetwork(_RewardedNetwork? network) async {
    switch (network) {
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
