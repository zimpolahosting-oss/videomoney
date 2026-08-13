import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.email,
    required this.type,
    required this.subject,
    required this.message,
    required this.status,
    required this.latestReply,
    required this.appVersion,
    required this.versionName,
    required this.buildNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String email;
  final String type;
  final String subject;
  final String message;
  final String status;
  final String latestReply;
  final String appVersion;
  final String versionName;
  final int buildNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasReply => latestReply.trim().isNotEmpty;

  factory SupportTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SupportTicket(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      type: data['type'] as String? ?? 'support',
      subject: data['subject'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      latestReply: data['latestReply'] as String? ?? '',
      appVersion: data['appVersion'] as String? ?? '',
      versionName: data['versionName'] as String? ?? '',
      buildNumber: (data['buildNumber'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
