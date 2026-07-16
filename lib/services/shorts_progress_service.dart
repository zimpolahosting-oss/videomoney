import 'package:shared_preferences/shared_preferences.dart';

class ShortsProgressSnapshot {
  const ShortsProgressSnapshot({
    required this.completedShortsInCycle,
    required this.watchMsInCycle,
    required this.bonusProgressShorts,
  });

  final int completedShortsInCycle;
  final int watchMsInCycle;
  final int bonusProgressShorts;

  static const empty = ShortsProgressSnapshot(
    completedShortsInCycle: 0,
    watchMsInCycle: 0,
    bonusProgressShorts: 0,
  );

  ShortsProgressSnapshot copyWith({
    int? completedShortsInCycle,
    int? watchMsInCycle,
    int? bonusProgressShorts,
  }) {
    return ShortsProgressSnapshot(
      completedShortsInCycle:
          completedShortsInCycle ?? this.completedShortsInCycle,
      watchMsInCycle: watchMsInCycle ?? this.watchMsInCycle,
      bonusProgressShorts: bonusProgressShorts ?? this.bonusProgressShorts,
    );
  }
}

class ShortsProgressResult {
  const ShortsProgressResult({
    required this.snapshot,
    this.rewardCycleCompleted = false,
    this.bonusViewsAwarded = 0,
  });

  final ShortsProgressSnapshot snapshot;
  final bool rewardCycleCompleted;
  final int bonusViewsAwarded;
}

class ShortsProgressService {
  ShortsProgressService._();

  static final ShortsProgressService instance = ShortsProgressService._();

  static const int rewardThresholdShorts = 10;
  static const int rewardThresholdWatchMs = 150000;
  static const int bonusThresholdShorts = 50;
  static const int bonusViewsReward = 100;

  String _completedKey(String uid) => 'shorts_cycle_completed_$uid';
  String _watchMsKey(String uid) => 'shorts_cycle_watch_ms_$uid';
  String _bonusKey(String uid) => 'shorts_bonus_progress_$uid';

  Future<ShortsProgressSnapshot> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return ShortsProgressSnapshot(
      completedShortsInCycle: prefs.getInt(_completedKey(uid)) ?? 0,
      watchMsInCycle: prefs.getInt(_watchMsKey(uid)) ?? 0,
      bonusProgressShorts: prefs.getInt(_bonusKey(uid)) ?? 0,
    );
  }

  Future<ShortsProgressResult> addWatchTime({
    required String uid,
    required int deltaMs,
  }) async {
    final snapshot = await load(uid);
    final next = snapshot.copyWith(
      watchMsInCycle: snapshot.watchMsInCycle + deltaMs,
    );
    await _save(uid, next);
    return ShortsProgressResult(
      snapshot: next,
      rewardCycleCompleted:
          next.watchMsInCycle >= rewardThresholdWatchMs ||
          next.completedShortsInCycle >= rewardThresholdShorts,
    );
  }

  Future<ShortsProgressResult> markShortCompleted(String uid) async {
    final snapshot = await load(uid);
    final rawBonusProgress = snapshot.bonusProgressShorts + 1;
    final bonusAwards = rawBonusProgress ~/ bonusThresholdShorts;
    final next = snapshot.copyWith(
      completedShortsInCycle: snapshot.completedShortsInCycle + 1,
      bonusProgressShorts: rawBonusProgress % bonusThresholdShorts,
    );
    await _save(uid, next);

    return ShortsProgressResult(
      snapshot: next,
      rewardCycleCompleted:
          next.completedShortsInCycle >= rewardThresholdShorts ||
          next.watchMsInCycle >= rewardThresholdWatchMs,
      bonusViewsAwarded: bonusAwards * bonusViewsReward,
    );
  }

  Future<ShortsProgressSnapshot> consumeRewardCycle(String uid) async {
    final snapshot = await load(uid);
    final next = snapshot.copyWith(
      completedShortsInCycle: 0,
      watchMsInCycle: 0,
    );
    await _save(uid, next);
    return next;
  }

  Future<void> _save(String uid, ShortsProgressSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_completedKey(uid), snapshot.completedShortsInCycle);
    await prefs.setInt(_watchMsKey(uid), snapshot.watchMsInCycle);
    await prefs.setInt(_bonusKey(uid), snapshot.bonusProgressShorts);
  }
}
