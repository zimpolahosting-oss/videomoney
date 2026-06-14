import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/payout_request.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int rewardCoinsPerVideo = 200;
  static const int minimumPayoutCoins = 10000;
  static const int payoutProcessingDays = 30;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _firestore.collection('payouts');

  Future<void> createUserProfile(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) return;

    await docRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'coins': 0,
      'videosWatched': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data()!);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!);
  }

  Future<void> rewardUser({
    required String uid,
    int coinsReward = rewardCoinsPerVideo,
  }) async {
    await _users.doc(uid).update({
      'coins': FieldValue.increment(coinsReward),
      'videosWatched': FieldValue.increment(1),
    });
  }

  Stream<List<PayoutRequest>> watchPayouts(String uid) {
    return _payouts
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PayoutRequest.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> createPayoutRequest({
    required String uid,
    required int coinsRequested,
    required String payPalEmail,
    required String ibanOrBankAccount,
    required String accountHolderName,
  }) async {
    final userRef = _users.doc(uid);
    final payoutRef = _payouts.doc();
    final trimmedPayPalEmail = payPalEmail.trim();
    final trimmedIbanOrBankAccount = ibanOrBankAccount.trim();
    final trimmedAccountHolderName = accountHolderName.trim();

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data();

      if (userData == null) {
        throw Exception('User profile not found.');
      }

      final currentCoins = (userData['coins'] as num?)?.toInt() ?? 0;
      if (coinsRequested <= 0) {
        throw Exception('Requested coins must be greater than zero.');
      }
      if (coinsRequested < minimumPayoutCoins) {
        throw Exception(
          'Minimum payout is $minimumPayoutCoins coins.',
        );
      }
      if (trimmedAccountHolderName.isEmpty) {
        throw Exception('Account holder name is required.');
      }
      if (trimmedPayPalEmail.isEmpty && trimmedIbanOrBankAccount.isEmpty) {
        throw Exception('Enter a PayPal email or an IBAN / bank account.');
      }
      if (currentCoins < coinsRequested) {
        throw Exception('Not enough coins available.');
      }

      transaction.update(userRef, {
        'coins': currentCoins - coinsRequested,
      });

      transaction.set(payoutRef, {
        'userId': uid,
        'coinsRequested': coinsRequested,
        'status': 'pending',
        'payPalEmail': trimmedPayPalEmail,
        'ibanOrBankAccount': trimmedIbanOrBankAccount,
        'accountHolderName': trimmedAccountHolderName,
        'minimumPayoutCoins': minimumPayoutCoins,
        'processingDays': payoutProcessingDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
