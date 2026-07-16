import 'package:video_money/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreService.buildExistingUserProfileUpdates', () {
    test('preserves existing coins when legacy reset marker is missing', () {
      final updates = FirestoreService.buildExistingUserProfileUpdates(
        data: {
          'uid': 'user-1',
          'email': 'old@example.com',
          'coins': 1234,
          'videosWatched': 77,
        },
        uid: 'user-1',
        email: 'new@example.com',
        todayKey: '2026-07-16',
      );

      expect(updates['uid'], 'user-1');
      expect(updates['email'], 'new@example.com');
      expect(updates['appVerified'], true);
      expect(updates.containsKey('coins'), isFalse);
      expect(
        updates[FirestoreService.rewardBalanceResetAppliedField],
        true,
      );
      expect(updates['dailyProgressDate'], '2026-07-16');
      expect(updates['dailyVideosWatched'], 0);
      expect(updates['dailyBonusAwarded'], false);
    });

    test('only backfills missing fields for existing complete profile', () {
      final updates = FirestoreService.buildExistingUserProfileUpdates(
        data: {
          'uid': 'user-2',
          'email': 'kept@example.com',
          'coins': 9876,
          'videosWatched': 22,
          'dailyProgressDate': '2026-07-15',
          'dailyVideosWatched': 3,
          'dailyBonusAwarded': true,
          'settings': {
            'notificationsEnabled': false,
            'dailyReminderEnabled': false,
          },
          'fcmTokens': ['abc'],
          'createdAt': 'already-set',
          'leaderboardDisplayName': 'Tester',
          FirestoreService.rewardBalanceResetAppliedField: true,
        },
        uid: 'user-2',
        email: 'kept@example.com',
        todayKey: '2026-07-16',
      );

      expect(
        updates,
        equals({
          'uid': 'user-2',
          'email': 'kept@example.com',
          'appVerified': true,
        }),
      );
    });
  });
}
