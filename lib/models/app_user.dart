import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.leaderboardDisplayName,
    required this.coins,
    required this.videosWatched,
    required this.dailyVideosWatched,
    required this.dailyProgressDate,
    required this.dailyBonusAwarded,
    required this.isAdmin,
    required this.appVerified,
    required this.fcmTokens,
    required this.notificationsEnabled,
    required this.dailyReminderEnabled,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final String leaderboardDisplayName;
  final int coins;
  final int videosWatched;
  final int dailyVideosWatched;

  /// Format: `YYYY-MM-DD` in the device local timezone.
  final String dailyProgressDate;
  final bool dailyBonusAwarded;
  final bool isAdmin;
  final bool appVerified;
  final List<String> fcmTokens;
  final bool notificationsEnabled;
  final bool dailyReminderEnabled;
  final DateTime? createdAt;

  int get views => coins;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final settings = map['settings'] as Map<String, dynamic>? ?? const {};
    return AppUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      leaderboardDisplayName: map['leaderboardDisplayName'] as String? ?? '',
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      videosWatched: (map['videosWatched'] as num?)?.toInt() ?? 0,
      dailyVideosWatched: (map['dailyVideosWatched'] as num?)?.toInt() ?? 0,
      dailyProgressDate: map['dailyProgressDate'] as String? ?? '',
      dailyBonusAwarded: map['dailyBonusAwarded'] as bool? ?? false,
      isAdmin: map['isAdmin'] as bool? ?? (map['admin'] as bool? ?? false),
      appVerified: map['appVerified'] as bool? ?? false,
      fcmTokens: ((map['fcmTokens'] as List<dynamic>?) ?? const [])
          .map((token) => token.toString())
          .where((token) => token.trim().isNotEmpty)
          .toList(growable: false),
      notificationsEnabled: settings['notificationsEnabled'] as bool? ?? true,
      dailyReminderEnabled: settings['dailyReminderEnabled'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'leaderboardDisplayName': leaderboardDisplayName,
      'coins': coins,
      'videosWatched': videosWatched,
      'dailyVideosWatched': dailyVideosWatched,
      'dailyProgressDate': dailyProgressDate,
      'dailyBonusAwarded': dailyBonusAwarded,
      'isAdmin': isAdmin,
      'appVerified': appVerified,
      'fcmTokens': fcmTokens,
      'settings': {
        'notificationsEnabled': notificationsEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
      },
      'createdAt': createdAt,
    };
  }
}
