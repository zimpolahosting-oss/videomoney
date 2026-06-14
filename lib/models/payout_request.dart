import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.userId,
    required this.coinsRequested,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int coinsRequested;
  final String status;
  final DateTime? createdAt;

  factory PayoutRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return PayoutRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      coinsRequested: (data['coinsRequested'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
