import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum _RewardedNetwork { admob, appodeal, appnext, meta, startio }

class RewardedAdService {
  factory RewardedAdService() => _instance;

  RewardedAdService._internal() {
    unawaited(preloadRewardedAd());
  }

  static final RewardedAdService _instance = RewardedAdService._internal();
  static const String rewardedAdUnitId =
      'ca-app-pub-7683034036748999/1933132998';
  static const MethodChannel _channel =
      MethodChannel('com.videomoney.app/rewarded_video');
  static const String adUnavailableMessage =
      'No ad available right now. Please try again in a moment.';
  static const String rewardDeliveryFailedMessage =
      'The ad finished, but we could not update your balance. Please try again.';
  static const List<_RewardedNetwork> _rotationOrder = [
    _RewardedNetwork.admob,
    _RewardedNetwork.appodeal,
    _RewardedNetwork.appnext,
    _RewardedNetwork.meta,
    _RewardedNetwork.startio,
  ];

  RewardedAd? _rewardedAd;
  final Map<_RewardedNetwork, bool> _nativeRewardedReady = {
    _RewardedNetwork.appodeal: false,
    _RewardedNetwork.appnext: false,
    _RewardedNetwork.meta: false,
    _RewardedNetwork.startio: false,
  };
  Completer<bool>? _nativeShowCompleter;
  FutureOr<void> Function()? _nativeRewardCallback;
  void Function(String message)? _nativeStatusCallback;
  _RewardedNetwork? _activeNativeNetwork;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isNativeRewardEarned = false;
  bool _methodHandlerRegistered = false;
  int _lastServedRewardedIndex = -1;

  bool get isAdReady => _rewardedAd != null;

  Future<void> preloadRewardedAd() async {
    _registerMethodHandler();
    await _loadRewardedAd();
    await Future.wait([
      _invokeVoidMethod('preloadRewardedVideo'),
      _invokeVoidMethod('preloadAppnextRewardedVideo'),
      _invokeVoidMethod('preloadMetaRewardedInterstitial'),
      _invokeVoidMethod('preloadStartioRewardedVideo'),
    ]);
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
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _isLoading = false;
          _logUnavailable(_RewardedNetwork.admob);
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
  }) async {
    _registerMethodHandler();
    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    final network = await _selectNextRewardedNetwork();
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
      case _RewardedNetwork.appodeal:
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
    _rewardedAd = null;
    _isShowing = true;
    _logShown(_RewardedNetwork.admob);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        await _resetAndLoadNextAd(ad);
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        _logUnavailable(_RewardedNetwork.admob);
        onAdStatus?.call(adUnavailableMessage);
        await _resetAndLoadNextAd(ad);
        if (!completer.isCompleted) {
          completer.complete(false);
        }
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
    _isShowing = true;

    final shown = await _channel.invokeMethod<bool>(showMethod) ?? false;
    if (!shown) {
      _logUnavailable(network);
      _completeNativeRewardedFlow(false, reloadNextAd: true);
      return false;
    }

    _logShown(network);
    return _nativeShowCompleter!.future;
  }

  Future<_RewardedNetwork?> _selectNextRewardedNetwork() async {
    await _refreshNativeRewardedAvailability();
    for (var offset = 1; offset <= _rotationOrder.length; offset++) {
      final index = (_lastServedRewardedIndex + offset) % _rotationOrder.length;
      final network = _rotationOrder[index];
      if (_isRewardedReady(network)) {
        _lastServedRewardedIndex = index;
        debugPrint('[Ads][rewarded] selected ${_labelForNetwork(network)}.');
        return network;
      }
    }
    return null;
  }

  Future<void> _refreshNativeRewardedAvailability() async {
    _updateNativeAvailability(
      _RewardedNetwork.appodeal,
      await _channel.invokeMethod<bool>('isRewardedVideoLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.appnext,
      await _channel.invokeMethod<bool>('isAppnextRewardedVideoLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.meta,
      await _channel.invokeMethod<bool>('isMetaRewardedInterstitialLoaded') ?? false,
    );
    _updateNativeAvailability(
      _RewardedNetwork.startio,
      await _channel.invokeMethod<bool>('isStartioRewardedVideoLoaded') ?? false,
    );
  }

  bool _isRewardedReady(_RewardedNetwork network) {
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
      case 'onRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.appodeal, true);
        break;
      case 'onRewardedVideoFailedToLoad':
      case 'onRewardedVideoExpired':
        _updateNativeAvailability(_RewardedNetwork.appodeal, false);
        break;
      case 'onRewardedVideoShown':
        _updateNativeAvailability(_RewardedNetwork.appodeal, false);
        break;
      case 'onRewardedVideoFinished':
        await _grantNativeReward();
        break;
      case 'onRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onRewardedVideoShowFailed':
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onAppnextRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.appnext, true);
        break;
      case 'onAppnextRewardedVideoOpened':
        _updateNativeAvailability(_RewardedNetwork.appnext, false);
        break;
      case 'onAppnextRewardedVideoEnded':
        await _grantNativeReward();
        break;
      case 'onAppnextRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onAppnextRewardedVideoError':
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onMetaRewardedInterstitialLoaded':
        _updateNativeAvailability(_RewardedNetwork.meta, true);
        break;
      case 'onMetaRewardedInterstitialShown':
        _updateNativeAvailability(_RewardedNetwork.meta, false);
        break;
      case 'onMetaRewardedInterstitialCompleted':
        await _grantNativeReward();
        break;
      case 'onMetaRewardedInterstitialClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onMetaRewardedInterstitialError':
        _nativeStatusCallback?.call(adUnavailableMessage);
        _completeNativeRewardedFlow(false, reloadNextAd: true);
        break;
      case 'onStartioRewardedVideoLoaded':
        _updateNativeAvailability(_RewardedNetwork.startio, true);
        break;
      case 'onStartioRewardedVideoShown':
        _updateNativeAvailability(_RewardedNetwork.startio, false);
        break;
      case 'onStartioRewardedVideoCompleted':
        await _grantNativeReward();
        break;
      case 'onStartioRewardedVideoClosed':
        _completeNativeRewardedFlow(_isNativeRewardEarned, reloadNextAd: true);
        break;
      case 'onStartioRewardedVideoError':
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

    if (reloadNextAd) {
      unawaited(_reloadNativeRewardedNetwork(network));
    }
  }

  Future<void> _reloadNativeRewardedNetwork(_RewardedNetwork? network) async {
    switch (network) {
      case _RewardedNetwork.appodeal:
        await _invokeVoidMethod('preloadRewardedVideo');
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

  String _labelForNetwork(_RewardedNetwork network) {
    return switch (network) {
      _RewardedNetwork.admob => 'AdMob',
      _RewardedNetwork.appodeal => 'Appodeal',
      _RewardedNetwork.appnext => 'Appnext',
      _RewardedNetwork.meta => 'Meta',
      _RewardedNetwork.startio => 'Start.io',
    };
  }

  String? _showMethodForNetwork(_RewardedNetwork network) {
    return switch (network) {
      _RewardedNetwork.appodeal => 'showRewardedVideo',
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

  void _logUnavailable(_RewardedNetwork network) {
    debugPrint('[Ads][rewarded] ${_labelForNetwork(network)} unavailable.');
  }
}
