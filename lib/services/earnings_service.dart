import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'rewarded_ad_service.dart';

class EarningsService {
  EarningsService({
    FirestoreService? firestoreService,
    RewardedAdService? rewardedAdService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _rewardedAdService = rewardedAdService ?? RewardedAdService();

  final FirestoreService _firestoreService;
  final RewardedAdService _rewardedAdService;

  Future<void> preloadRewardedVideo() {
    return _rewardedAdService.preloadRewardedAd();
  }

  /// Skips the rewarded provider that is currently taking too long and lets the
  /// running ad flow move on to the next one in the chain.
  void skipCurrentRewardedAd() {
    _rewardedAdService.skipCurrentRewardedAttempt();
  }

  Future<bool> showRewardedBonusAd({
    required ValueChanged<String> onAdStatus,
    RewardedAdProvider provider = RewardedAdProvider.auto,
    bool closeCountsAsCompleted = false,
  }) {
    return _rewardedAdService.showRewardedAd(
      onUserEarnedReward: () async {},
      onAdStatus: onAdStatus,
      provider: provider,
      closeCountsAsCompleted: closeCountsAsCompleted,
    );
  }

  Future<bool> watchRewardedVideo({
    required String uid,
    required ValueChanged<String> onAdStatus,
    RewardedAdProvider provider = RewardedAdProvider.auto,
  }) {
    return _rewardedAdService.showRewardedAd(
      onUserEarnedReward: () async {
        await _firestoreService.rewardUser(
          uid: uid,
          coinsReward: FirestoreService.rewardCoinsPerVideo,
        );
      },
      onAdStatus: onAdStatus,
      provider: provider,
    );
  }

  Future<bool> watchAdRouletteAd({
    required String uid,
    required ValueChanged<String> onAdStatus,
    RewardedAdProvider provider = RewardedAdProvider.auto,
  }) {
    return _rewardedAdService.showRewardedAd(
      onUserEarnedReward: () async {
        await _firestoreService.rewardAdRouletteAd(uid: uid);
      },
      onAdStatus: onAdStatus,
      provider: provider,
    );
  }
}
