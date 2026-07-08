import 'dart:async';

import 'package:flutter/services.dart';

class RewardedAdService {
  factory RewardedAdService() => _instance;

  RewardedAdService._internal() {
    _registerMethodHandler();
  }

  static final RewardedAdService _instance = RewardedAdService._internal();
  static const MethodChannel _channel =
      MethodChannel('com.videomoney.app/rewarded_video');
  static const String adUnavailableMessage =
      'No ad available right now. Please try again in a moment.';
  static const String rewardDeliveryFailedMessage =
      'The ad finished, but we could not update your balance. Please try again.';

  Completer<bool>? _showCompleter;
  FutureOr<void> Function()? _onUserEarnedReward;
  void Function(String message)? _onAdStatus;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _rewardEarned = false;
  bool _hasHandler = false;
  bool _isAdReady = false;

  bool get isAdReady => _isAdReady;

  Future<void> initialize() async {
    _registerMethodHandler();
    if (_isInitialized) {
      return preloadRewardedAd();
    }

    await _channel.invokeMethod<void>('ensureAppodealInitialized');
    _isInitialized = true;
    await preloadRewardedAd();
  }

  Future<void> preloadRewardedAd() async {
    _registerMethodHandler();
    if (_isLoading) return;

    _isLoading = true;
    try {
      await _channel.invokeMethod<void>('preloadRewardedVideo');
    } finally {
      if (!_isAdReady) {
        _isLoading = false;
      }
    }
  }

  Future<bool> showRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    await initialize();

    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    final canShow =
        await _channel.invokeMethod<bool>('isRewardedVideoLoaded') ?? false;
    _isAdReady = canShow;

    if (!canShow) {
      unawaited(preloadRewardedAd());
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    _showCompleter = Completer<bool>();
    _onUserEarnedReward = onUserEarnedReward;
    _onAdStatus = onAdStatus;
    _rewardEarned = false;
    _isShowing = true;
    _isAdReady = false;

    final shown = await _channel.invokeMethod<bool>('showRewardedVideo') ?? false;
    if (!shown) {
      _completeShowFlow(false, reloadNextAd: true);
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    return _showCompleter!.future;
  }

  void _registerMethodHandler() {
    if (_hasHandler) return;
    _channel.setMethodCallHandler(_handlePlatformCall);
    _hasHandler = true;
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onRewardedVideoLoaded':
        _isLoading = false;
        _isAdReady = true;
        break;
      case 'onRewardedVideoFailedToLoad':
      case 'onRewardedVideoExpired':
        _isLoading = false;
        _isAdReady = false;
        break;
      case 'onRewardedVideoShowFailed':
        _onAdStatus?.call(adUnavailableMessage);
        _completeShowFlow(false, reloadNextAd: true);
        break;
      case 'onRewardedVideoFinished':
        await _grantReward();
        break;
      case 'onRewardedVideoClosed':
        final finished = (call.arguments as Map<Object?, Object?>?)?['finished'];
        if (finished == true && !_rewardEarned) {
          await _grantReward();
        }
        _completeShowFlow(
          _rewardEarned,
          reloadNextAd: true,
        );
        break;
      default:
        break;
    }
  }

  Future<void> _grantReward() async {
    final onUserEarnedReward = _onUserEarnedReward;
    if (onUserEarnedReward == null || _rewardEarned) {
      return;
    }

    try {
      await onUserEarnedReward();
      _rewardEarned = true;
    } catch (_) {
      _rewardEarned = false;
      _onAdStatus?.call(rewardDeliveryFailedMessage);
    }
  }

  void _completeShowFlow(
    bool rewardGranted, {
    required bool reloadNextAd,
  }) {
    _isShowing = false;
    _isLoading = false;
    _isAdReady = false;

    final completer = _showCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(rewardGranted);
    }

    _showCompleter = null;
    _onUserEarnedReward = null;
    _onAdStatus = null;
    _rewardEarned = false;

    if (reloadNextAd) {
      unawaited(preloadRewardedAd());
    }
  }
}
