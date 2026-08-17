import 'package:cloud_firestore/cloud_firestore.dart';

class AdTransfer {
  const AdTransfer({
    required this.id,
    required this.senderUid,
    required this.senderEmail,
    required this.recipientUid,
    required this.recipientEmail,
    required this.amountAds,
    required this.status,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.rejectedAt,
  });

  final String id;
  final String senderUid;
  final String senderEmail;
  final String recipientUid;
  final String recipientEmail;
  final int amountAds;
  final String status;
  final List<String> participants;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isRejected => status.toLowerCase() == 'rejected';

  bool isRecipient(String uid) => recipientUid == uid;
  bool isSender(String uid) => senderUid == uid;

  factory AdTransfer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdTransfer(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      senderEmail: data['senderEmail'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      recipientEmail: data['recipientEmail'] as String? ?? '',
      amountAds: (data['amountAds'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      participants: ((data['participants'] as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
    );
  }
}
