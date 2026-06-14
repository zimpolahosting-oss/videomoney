import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.userId,
    required this.coinsRequested,
    required this.status,
    required this.createdAt,
    required this.payPalEmail,
    required this.ibanOrBankAccount,
    required this.accountHolderName,
  });

  final String id;
  final String userId;
  final int coinsRequested;
  final String status;
  final DateTime? createdAt;
  final String payPalEmail;
  final String ibanOrBankAccount;
  final String accountHolderName;

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
      payPalEmail: data['payPalEmail'] as String? ?? '',
      ibanOrBankAccount: data['ibanOrBankAccount'] as String? ?? '',
      accountHolderName: data['accountHolderName'] as String? ?? '',
    );
  }
}
