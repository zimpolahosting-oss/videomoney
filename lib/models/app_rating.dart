import 'package:cloud_firestore/cloud_firestore.dart';

class AppRating {
  const AppRating({
    required this.id,
    required this.userId,
    required this.email,
    required this.stars,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String email;
  final int stars;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppRating.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppRating(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      stars: (data['stars'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
