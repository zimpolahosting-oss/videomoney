import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  factory RewardedAdService() => _instance;

  RewardedAdService._internal() {
    _loadRewardedAd();
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

  RewardedAd? _rewardedAd;
  Completer<bool>? _appnextShowCompleter;
  FutureOr<void> Function()? _appnextRewardCallback;
  void Function(String message)? _appnextStatusCallback;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isAppnextRewardEarned = false;
  bool _isAppnextReady = false;
  bool _methodHandlerRegistered = false;

  bool get isAdReady => _rewardedAd != null;

  Future<void> preloadRewardedAd() async {
    _registerMethodHandler();
    await _loadRewardedAd();
    await _preloadAppnextRewardedAd();
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
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  Future<void> _preloadAppnextRewardedAd() async {
    await _channel.invokeMethod<void>('preloadAppnextRewardedVideo');
  }

  void _disposeCurrentAd([RewardedAd? ad]) {
    ad?.dispose();
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  Future<void> _resetAndLoadNextAd([RewardedAd? ad]) async {
    _disposeCurrentAd(ad);
    _isShowing = false;
    unawaited(_loadRewardedAd());
  }

  Future<bool> showRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    _registerMethodHandler();
    final completer = Completer<bool>();
    var rewardEarned = false;
    final ad = _rewardedAd;

    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    if (ad == null) {
      final appnextAvailable = await _isAppnextRewardedAvailable();
      if (appnextAvailable) {
        return _showAppnextRewardedAd(
          onUserEarnedReward: onUserEarnedReward,
          onAdStatus: onAdStatus,
        );
      }
      unawaited(preloadRewardedAd());
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    _rewardedAd = null;
    _isShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        await _resetAndLoadNextAd(ad);
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
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

  Future<bool> _showAppnextRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    final isLoaded = await _isAppnextRewardedAvailable();
    if (!isLoaded) {
      unawaited(_preloadAppnextRewardedAd());
      return false;
    }

    _appnextShowCompleter = Completer<bool>();
    _appnextRewardCallback = onUserEarnedReward;
    _appnextStatusCallback = onAdStatus;
    _isAppnextRewardEarned = false;
    _isShowing = true;

    final shown = await _channel.invokeMethod<bool>('showAppnextRewardedVideo') ?? false;
    if (!shown) {
      _completeAppnextFlow(false, reloadNextAd: true);
      return false;
    }

    return _appnextShowCompleter!.future;
  }

  Future<bool> _isAppnextRewardedAvailable() async {
    return await _channel.invokeMethod<bool>('isAppnextRewardedVideoLoaded') ??
        _isAppnextReady;
  }

  void _registerMethodHandler() {
    if (_methodHandlerRegistered) return;
    _channel.setMethodCallHandler(_handleNativeMethodCall);
    _methodHandlerRegistered = true;
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppnextRewardedVideoLoaded':
        _isAppnextReady = true;
        break;
      case 'onAppnextRewardedVideoOpened':
        _isAppnextReady = false;
        break;
      case 'onAppnextRewardedVideoEnded':
        await _grantAppnextReward();
        break;
      case 'onAppnextRewardedVideoClosed':
        _completeAppnextFlow(_isAppnextRewardEarned, reloadNextAd: true);
        break;
      case 'onAppnextRewardedVideoError':
        _appnextStatusCallback?.call(adUnavailableMessage);
        _completeAppnextFlow(false, reloadNextAd: true);
        break;
      default:
        break;
    }
  }

  Future<void> _grantAppnextReward() async {
    final callback = _appnextRewardCallback;
    if (callback == null || _isAppnextRewardEarned) return;
    try {
      await callback();
      _isAppnextRewardEarned = true;
    } catch (_) {
      _isAppnextRewardEarned = false;
      _appnextStatusCallback?.call(rewardDeliveryFailedMessage);
    }
  }

  void _completeAppnextFlow(
    bool rewardGranted, {
    required bool reloadNextAd,
  }) {
    _isShowing = false;
    _isAppnextReady = false;

    final completer = _appnextShowCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(rewardGranted);
    }

    _appnextShowCompleter = null;
    _appnextRewardCallback = null;
    _appnextStatusCallback = null;
    _isAppnextRewardEarned = false;

    if (reloadNextAd) {
      unawaited(_preloadAppnextRewardedAd());
    }
  }
}
