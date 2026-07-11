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

  Future<bool> watchRewardedVideo({
    required String uid,
    required ValueChanged<String> onAdStatus,
  }) {
    return _rewardedAdService.showRewardedAd(
      onUserEarnedReward: () async {
        await _firestoreService.rewardUser(
          uid: uid,
          coinsReward: FirestoreService.rewardCoinsPerVideo,
        );
      },
      onAdStatus: onAdStatus,
    );
  }
}
