import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.publicName,
    required this.customName,
    required this.views,
    required this.videosWatched,
    required this.estimatedEarnings,
    required this.updatedAt,
  });

  final String uid;
  final String publicName;
  final String customName;
  final int views;
  final int videosWatched;
  final double estimatedEarnings;
  final DateTime? updatedAt;

  factory LeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LeaderboardEntry(
      uid: data['uid'] as String? ?? doc.id,
      publicName: data['publicName'] as String? ?? 'Gebruiker',
      customName: data['customName'] as String? ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      videosWatched: (data['videosWatched'] as num?)?.toInt() ?? 0,
      estimatedEarnings: (data['estimatedEarnings'] as num?)?.toDouble() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
