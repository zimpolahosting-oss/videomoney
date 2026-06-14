import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  static const String rewardedAdUnitId =
      'ca-app-pub-7683034036748999/1933132998';

  Future<bool> showRewardedAd({
    required FutureOr<void> Function() onUserEarnedReward,
    void Function(String message)? onAdStatus,
  }) async {
    final completer = Completer<bool>();

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdStatus?.call(error.message);
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );

          ad.show(
            onUserEarnedReward: (ad, reward) async {
              await onUserEarnedReward();
              onAdStatus?.call(
                'Reward granted: ${reward.amount.toInt()} ${reward.type}',
              );
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          onAdStatus?.call(error.message);
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    return completer.future;
  }
}
