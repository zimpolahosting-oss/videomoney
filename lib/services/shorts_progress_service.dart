import 'package:shared_preferences/shared_preferences.dart';

class ShortsProgressSnapshot {
  const ShortsProgressSnapshot({
    required this.completedShortsInCycle,
    required this.watchMsInCycle,
    required this.bonusProgressShorts,
    required this.adBreakProgressShorts,
    required this.pendingAdBreakShorts,
    required this.pendingAdBreakProvider,
    required this.nextAdBreakProvider,
    required this.pendingAdBreakAttempted,
  });

  final int completedShortsInCycle;
  final int watchMsInCycle;
  final int bonusProgressShorts;
  final int adBreakProgressShorts;
  final int pendingAdBreakShorts;
  final String pendingAdBreakProvider;
  final String nextAdBreakProvider;
  final bool pendingAdBreakAttempted;

  static const empty = ShortsProgressSnapshot(
    completedShortsInCycle: 0,
    watchMsInCycle: 0,
    bonusProgressShorts: 0,
    adBreakProgressShorts: 0,
    pendingAdBreakShorts: 0,
    pendingAdBreakProvider: '',
    nextAdBreakProvider: ShortsProgressService.providerPangle,
    pendingAdBreakAttempted: false,
  );

  ShortsProgressSnapshot copyWith({
    int? completedShortsInCycle,
    int? watchMsInCycle,
    int? bonusProgressShorts,
    int? adBreakProgressShorts,
    int? pendingAdBreakShorts,
    String? pendingAdBreakProvider,
    String? nextAdBreakProvider,
    bool? pendingAdBreakAttempted,
  }) {
    return ShortsProgressSnapshot(
      completedShortsInCycle:
          completedShortsInCycle ?? this.completedShortsInCycle,
      watchMsInCycle: watchMsInCycle ?? this.watchMsInCycle,
      bonusProgressShorts: bonusProgressShorts ?? this.bonusProgressShorts,
      adBreakProgressShorts: adBreakProgressShorts ?? this.adBreakProgressShorts,
      pendingAdBreakShorts: pendingAdBreakShorts ?? this.pendingAdBreakShorts,
      pendingAdBreakProvider:
          pendingAdBreakProvider ?? this.pendingAdBreakProvider,
      nextAdBreakProvider: nextAdBreakProvider ?? this.nextAdBreakProvider,
      pendingAdBreakAttempted:
          pendingAdBreakAttempted ?? this.pendingAdBreakAttempted,
    );
  }
}

class ShortsProgressResult {
  const ShortsProgressResult({
    required this.snapshot,
    this.shortsThresholdReached = false,
    this.adBreakReached = false,
    this.bonusViewsAwarded = 0,
  });

  final ShortsProgressSnapshot snapshot;
  final bool shortsThresholdReached;
  final bool adBreakReached;
  final int bonusViewsAwarded;
}

class ShortsProgressService {
  ShortsProgressService._();

  static final ShortsProgressService instance = ShortsProgressService._();

  static const int rewardThresholdShorts = 10;
  static const int bonusThresholdShorts = 50;
  static const int bonusViewsReward = 25;
  static const int adBreakThresholdShorts = 3;
  static const String providerPangle = 'pangle';
  static const String providerMonetag = 'monetag';
  static const String providerMeta = 'meta';

  String _completedKey(String uid) => 'shorts_cycle_completed_$uid';
  String _watchMsKey(String uid) => 'shorts_cycle_watch_ms_$uid';
  String _bonusKey(String uid) => 'shorts_bonus_progress_$uid';
  String _adBreakProgressKey(String uid) => 'shorts_ad_break_progress_$uid';
  String _pendingAdBreakKey(String uid) => 'shorts_pending_ad_break_$uid';
  String _pendingAdBreakProviderKey(String uid) =>
      'shorts_pending_ad_break_provider_$uid';
  String _nextAdBreakProviderKey(String uid) =>
      'shorts_next_ad_break_provider_$uid';
  String _pendingAdBreakAttemptedKey(String uid) =>
      'shorts_pending_ad_break_attempted_$uid';

  Future<ShortsProgressSnapshot> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return ShortsProgressSnapshot(
      completedShortsInCycle: prefs.getInt(_completedKey(uid)) ?? 0,
      watchMsInCycle: prefs.getInt(_watchMsKey(uid)) ?? 0,
      bonusProgressShorts: prefs.getInt(_bonusKey(uid)) ?? 0,
      adBreakProgressShorts: prefs.getInt(_adBreakProgressKey(uid)) ?? 0,
      pendingAdBreakShorts: prefs.getInt(_pendingAdBreakKey(uid)) ?? 0,
      pendingAdBreakProvider:
          prefs.getString(_pendingAdBreakProviderKey(uid)) ?? '',
      nextAdBreakProvider:
          prefs.getString(_nextAdBreakProviderKey(uid)) ?? providerPangle,
      pendingAdBreakAttempted:
          prefs.getBool(_pendingAdBreakAttemptedKey(uid)) ?? false,
    );
  }

  Future<ShortsProgressResult> markShortCompleted(String uid) async {
    final snapshot = await load(uid);
    final rawBonusProgress = snapshot.bonusProgressShorts + 1;
    final bonusAwards = rawBonusProgress ~/ bonusThresholdShorts;
    final rawAdBreakProgress = snapshot.adBreakProgressShorts + 1;
    final shouldStartNewAdBreak = snapshot.pendingAdBreakShorts == 0 &&
        rawAdBreakProgress >= adBreakThresholdShorts;
    final providerForBreak = shouldStartNewAdBreak
        ? snapshot.nextAdBreakProvider
        : snapshot.pendingAdBreakProvider;
    final next = snapshot.copyWith(
      completedShortsInCycle: snapshot.completedShortsInCycle + 1,
      bonusProgressShorts: rawBonusProgress % bonusThresholdShorts,
      adBreakProgressShorts: shouldStartNewAdBreak ? 0 : rawAdBreakProgress,
    );
    final nextPendingAdBreakShorts = shouldStartNewAdBreak
        ? next.completedShortsInCycle
        : snapshot.pendingAdBreakShorts;
    final nextWithPending = next.copyWith(
      pendingAdBreakShorts: nextPendingAdBreakShorts,
      pendingAdBreakProvider: providerForBreak,
      nextAdBreakProvider: shouldStartNewAdBreak
          ? _alternateProvider(snapshot.nextAdBreakProvider)
          : snapshot.nextAdBreakProvider,
      pendingAdBreakAttempted:
          shouldStartNewAdBreak ? false : snapshot.pendingAdBreakAttempted,
    );
    await _save(uid, nextWithPending);

    return ShortsProgressResult(
      snapshot: nextWithPending,
      shortsThresholdReached:
          next.completedShortsInCycle >= rewardThresholdShorts,
      adBreakReached: shouldStartNewAdBreak,
      bonusViewsAwarded: bonusAwards * bonusViewsReward,
    );
  }

  Future<ShortsProgressSnapshot> consumeRewardCycle(String uid) async {
    final snapshot = await load(uid);
    final next = snapshot.copyWith(
      completedShortsInCycle: 0,
      watchMsInCycle: 0,
      pendingAdBreakShorts: 0,
      pendingAdBreakProvider: '',
      pendingAdBreakAttempted: false,
    );
    await _save(uid, next);
    return next;
  }

  Future<ShortsProgressSnapshot> consumePendingAdBreak(String uid) async {
    final snapshot = await load(uid);
    final next = snapshot.copyWith(
      pendingAdBreakShorts: 0,
      pendingAdBreakProvider: '',
      pendingAdBreakAttempted: false,
    );
    await _save(uid, next);
    return next;
  }

  Future<ShortsProgressSnapshot> markPendingAdBreakAttempted(String uid) async {
    final snapshot = await load(uid);
    if (snapshot.pendingAdBreakShorts == 0) return snapshot;
    if (snapshot.pendingAdBreakAttempted) return snapshot;
    final next = snapshot.copyWith(pendingAdBreakAttempted: true);
    await _save(uid, next);
    return next;
  }

  Future<void> _save(String uid, ShortsProgressSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_completedKey(uid), snapshot.completedShortsInCycle);
    await prefs.setInt(_watchMsKey(uid), snapshot.watchMsInCycle);
    await prefs.setInt(_bonusKey(uid), snapshot.bonusProgressShorts);
    await prefs.setInt(_adBreakProgressKey(uid), snapshot.adBreakProgressShorts);
    await prefs.setInt(_pendingAdBreakKey(uid), snapshot.pendingAdBreakShorts);
    await prefs.setString(
      _pendingAdBreakProviderKey(uid),
      snapshot.pendingAdBreakProvider,
    );
    await prefs.setString(
      _nextAdBreakProviderKey(uid),
      snapshot.nextAdBreakProvider,
    );
    await prefs.setBool(
      _pendingAdBreakAttemptedKey(uid),
      snapshot.pendingAdBreakAttempted,
    );
  }

  String _alternateProvider(String provider) {
    return switch (provider) {
      providerPangle => providerMonetag,
      providerMonetag => providerMeta,
      providerMeta => providerPangle,
      _ => providerPangle,
    };
  }
}
