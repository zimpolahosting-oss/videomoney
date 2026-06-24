import 'package:cloud_firestore/cloud_firestore.dart';

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
    required this.ticketId,
    required this.notificationId,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime? createdAt;
  final String ticketId;
  final String notificationId;

  factory InboxMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return InboxMessage(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'info',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      ticketId: data['ticketId'] as String? ?? '',
      notificationId: data['notificationId'] as String? ?? '',
    );
  }
}
