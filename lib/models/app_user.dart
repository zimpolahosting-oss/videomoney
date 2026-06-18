import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.coins,
    required this.videosWatched,
    required this.dailyVideosWatched,
    required this.dailyProgressDate,
    required this.dailyBonusAwarded,
    required this.isAdmin,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final int coins;
  final int videosWatched;
  final int dailyVideosWatched;
  /// Format: `YYYY-MM-DD` in the device local timezone.
  final String dailyProgressDate;
  final bool dailyBonusAwarded;
  final bool isAdmin;
  final DateTime? createdAt;

  int get views => coins;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      videosWatched: (map['videosWatched'] as num?)?.toInt() ?? 0,
      dailyVideosWatched: (map['dailyVideosWatched'] as num?)?.toInt() ?? 0,
      dailyProgressDate: map['dailyProgressDate'] as String? ?? '',
      dailyBonusAwarded: map['dailyBonusAwarded'] as bool? ?? false,
      isAdmin: map['isAdmin'] as bool? ?? (map['admin'] as bool? ?? false),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'coins': coins,
      'videosWatched': videosWatched,
      'dailyVideosWatched': dailyVideosWatched,
      'dailyProgressDate': dailyProgressDate,
      'dailyBonusAwarded': dailyBonusAwarded,
      'isAdmin': isAdmin,
      'createdAt': createdAt,
    };
  }
}
