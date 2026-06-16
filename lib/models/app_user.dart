import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.coins,
    required this.videosWatched,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final int coins;
  final int videosWatched;
  final DateTime? createdAt;

  int get views => coins;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      videosWatched: (map['videosWatched'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'coins': coins,
      'videosWatched': videosWatched,
      'createdAt': createdAt,
    };
  }
}
