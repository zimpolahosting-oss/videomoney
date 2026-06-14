import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  factory RewardedAdService() => _instance;

  RewardedAdService._internal() {
    _loadRewardedAd();
  }

  static final RewardedAdService _instance = RewardedAdService._internal();
  static const String rewardedAdUnitId =
      'ca-app-pub-7683034036748999/1933132998';
  static const String adUnavailableMessage =
      'No ad available right now. Please try again in a moment.';

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isShowing = false;

  bool get isAdReady => _rewardedAd != null;

  Future<void> preloadRewardedAd() => _loadRewardedAd();

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
    final completer = Completer<bool>();
    var rewardEarned = false;
    final ad = _rewardedAd;

    if (_isShowing) {
      onAdStatus?.call(adUnavailableMessage);
      return false;
    }

    if (ad == null) {
      unawaited(_loadRewardedAd());
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
        rewardEarned = true;
        await onUserEarnedReward();
      },
    );

    return completer.future;
  }
}
