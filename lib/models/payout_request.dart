import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.coinsRequested,
    required this.payoutMethod,
    required this.status,
    required this.createdAt,
    required this.payPalEmail,
    required this.revolutUsername,
    required this.ibanOrBankAccount,
    required this.accountHolderName,
  });

  final String id;
  final String userId;
  final String userEmail;
  final int coinsRequested;
  /// `paypal` or `revolut` (lowercase). Might be empty for legacy documents.
  final String payoutMethod;
  final String status;
  final DateTime? createdAt;
  final String payPalEmail;
  final String revolutUsername;
  /// Legacy field used by older documents. Kept to avoid breaking reads.
  final String ibanOrBankAccount;
  final String accountHolderName;

  int get viewsRequested => coinsRequested;

  factory PayoutRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final legacyRevolut = data['ibanOrBankAccount'] as String? ?? '';
    final revolutUsername = data['revolutUsername'] as String? ?? legacyRevolut;
    final payoutMethod = (data['payoutMethod'] as String? ?? '').toLowerCase();

    return PayoutRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      coinsRequested: (data['coinsRequested'] as num?)?.toInt() ?? 0,
      payoutMethod: payoutMethod,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      payPalEmail: data['payPalEmail'] as String? ?? '',
      revolutUsername: revolutUsername,
      ibanOrBankAccount: legacyRevolut,
      accountHolderName: data['accountHolderName'] as String? ?? '',
    );
  }
}
