import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/payout_request.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
    int coinsReward = 200,
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
  }) async {
    final userRef = _users.doc(uid);
    final payoutRef = _payouts.doc();

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
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
