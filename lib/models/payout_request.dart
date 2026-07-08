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
    required this.payoutCurrency,
    required this.bankName,
    required this.iban,
    required this.bankAccountNumber,
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
  final String payoutCurrency;
  final String bankName;
  final String iban;
  final String bankAccountNumber;

  int get viewsRequested => coinsRequested;
  bool get isBankTransfer => payoutMethod == 'bank';
  String get normalizedCurrency => payoutCurrency.isEmpty ? 'EUR' : payoutCurrency;

  String get payoutMethodLabel {
    switch (payoutMethod) {
      case 'paypal':
        return 'PayPal';
      case 'revolut':
        return 'Revolut';
      case 'bank':
        return 'Bank transfer';
      default:
        return payoutMethod.isEmpty ? 'Unknown' : payoutMethod.toUpperCase();
    }
  }

  String get destinationSummary {
    if (payoutMethod == 'revolut') {
      final username =
          revolutUsername.isNotEmpty ? revolutUsername : ibanOrBankAccount;
      return 'Revolut: ${username.isEmpty ? 'Not provided' : username}';
    }
    if (payoutMethod == 'bank') {
      final details = <String>[];
      if (bankName.isNotEmpty) details.add(bankName);
      if (iban.isNotEmpty) details.add('IBAN $iban');
      if (bankAccountNumber.isNotEmpty) {
        details.add('Account $bankAccountNumber');
      }
      if (details.isEmpty && ibanOrBankAccount.isNotEmpty) {
        details.add(ibanOrBankAccount);
      }
      return 'Bank: ${details.isEmpty ? 'Not provided' : details.join(' • ')}';
    }
    return 'PayPal: ${payPalEmail.isEmpty ? 'Not provided' : payPalEmail}';
  }

  factory PayoutRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final legacyRevolut = data['ibanOrBankAccount'] as String? ?? '';
    final revolutUsername = data['revolutUsername'] as String? ?? legacyRevolut;
    final rawPayoutMethod = (data['payoutMethod'] as String? ?? '').toLowerCase();
    final iban = data['iban'] as String? ?? '';
    final bankAccountNumber = data['bankAccountNumber'] as String? ?? '';
    final payPalEmail = data['payPalEmail'] as String? ?? '';
    final payoutMethod = rawPayoutMethod.isNotEmpty
        ? rawPayoutMethod
        : revolutUsername.isNotEmpty
            ? 'revolut'
            : payPalEmail.isNotEmpty
                ? 'paypal'
                : (iban.isNotEmpty || bankAccountNumber.isNotEmpty)
                    ? 'bank'
                    : '';

    return PayoutRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      coinsRequested: (data['coinsRequested'] as num?)?.toInt() ?? 0,
      payoutMethod: payoutMethod,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      payPalEmail: payPalEmail,
      revolutUsername: revolutUsername,
      ibanOrBankAccount: legacyRevolut,
      accountHolderName: data['accountHolderName'] as String? ?? '',
      payoutCurrency: (data['payoutCurrency'] as String? ?? 'EUR').toUpperCase(),
      bankName: data['bankName'] as String? ?? '',
      iban: iban.isNotEmpty ? iban : legacyRevolut,
      bankAccountNumber:
          bankAccountNumber.isNotEmpty ? bankAccountNumber : legacyRevolut,
    );
  }
}
