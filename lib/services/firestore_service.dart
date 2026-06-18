import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/payout_request.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int rewardCoinsPerVideo = 1;
  static const int dailyBonusTargetVideos = 20;
  static const int dailyBonusViews = 500;
  static const int minimumPayoutCoins = 10000;
  static const int payoutProcessingDays = 30;
  static const int estimatedViewsPerCent = 50;
  static const String rewardBalanceResetAppliedField =
      'rewardBalanceResetApplied';
  static const Set<String> allowedPayoutStatuses = {
    'pending',
    'approved',
    'paid',
    'rejected',
  };

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _firestore.collection('payouts');

  CollectionReference<Map<String, dynamic>> get _supportTickets =>
      _firestore.collection('supportTickets');

  CollectionReference<Map<String, dynamic>> get _bugReports =>
      _firestore.collection('bugReports');

  static double estimateEarningsEuro(int views) {
    return views / estimatedViewsPerCent / 100;
  }

  static String formatLocalDateKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> createUserProfile(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    final todayKey = formatLocalDateKey(DateTime.now());

    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final rewardBalanceResetApplied =
          data[rewardBalanceResetAppliedField] as bool? ?? false;

      if (!rewardBalanceResetApplied) {
        await docRef.update({
          'coins': 0,
          rewardBalanceResetAppliedField: true,
        });
      }

      final dailyUpdates = <String, dynamic>{};
      if (!data.containsKey('dailyProgressDate')) {
        dailyUpdates['dailyProgressDate'] = todayKey;
      }
      if (!data.containsKey('dailyVideosWatched')) {
        dailyUpdates['dailyVideosWatched'] = 0;
      }
      if (!data.containsKey('dailyBonusAwarded')) {
        dailyUpdates['dailyBonusAwarded'] = false;
      }
      if (dailyUpdates.isNotEmpty) {
        await docRef.update(dailyUpdates);
      }
      return;
    }

    await docRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'coins': 0,
      'videosWatched': 0,
      'dailyProgressDate': todayKey,
      'dailyVideosWatched': 0,
      'dailyBonusAwarded': false,
      'isAdmin': false,
      rewardBalanceResetAppliedField: true,
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

  Future<Map<String, bool>> getUserSettings(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    final settings = data['settings'] as Map<String, dynamic>? ?? {};

    return {
      'notificationsEnabled': settings['notificationsEnabled'] as bool? ?? true,
      'dailyReminderEnabled': settings['dailyReminderEnabled'] as bool? ?? true,
    };
  }

  Future<void> rewardUser({
    required String uid,
    int coinsReward = rewardCoinsPerVideo,
  }) async {
    final todayKey = formatLocalDateKey(DateTime.now());
    final userRef = _users.doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null) {
        throw Exception('User profile not found.');
      }

      final existingKey = data['dailyProgressDate'] as String? ?? '';
      final wasSameDay = existingKey == todayKey;
      final previousDailyCount =
          (data['dailyVideosWatched'] as num?)?.toInt() ?? 0;
      final previousBonusAwarded = data['dailyBonusAwarded'] as bool? ?? false;

      final baseDailyCount = wasSameDay ? previousDailyCount : 0;
      final baseBonusAwarded = wasSameDay ? previousBonusAwarded : false;

      final newDailyCount = baseDailyCount + 1;
      final bonusTriggered = !baseBonusAwarded &&
          newDailyCount >= FirestoreService.dailyBonusTargetVideos;

      transaction.update(userRef, {
        'coins': FieldValue.increment(
          coinsReward +
              (bonusTriggered ? FirestoreService.dailyBonusViews : 0),
        ),
        'videosWatched': FieldValue.increment(1),
        'dailyProgressDate': todayKey,
        'dailyVideosWatched': newDailyCount,
        'dailyBonusAwarded': bonusTriggered ? true : baseBonusAwarded,
        if (bonusTriggered) 'dailyBonusAwardedAt': FieldValue.serverTimestamp(),
      });
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
    required String payoutMethod,
    required String payPalEmail,
    required String revolutUsername,
    required String accountHolderName,
  }) async {
    final userRef = _users.doc(uid);
    final payoutRef = _payouts.doc();
    final trimmedPayPalEmail = payPalEmail.trim();
    final trimmedRevolutUsername = revolutUsername.trim();
    final trimmedAccountHolderName = accountHolderName.trim();
    final trimmedMethod = payoutMethod.trim().toLowerCase();

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data();

      if (userData == null) {
        throw Exception('User profile not found.');
      }

      final currentCoins = (userData['coins'] as num?)?.toInt() ?? 0;
      if (coinsRequested <= 0) {
        throw Exception('Requested views must be greater than zero.');
      }
      if (coinsRequested < minimumPayoutCoins) {
        throw Exception(
          'Minimum payout is $minimumPayoutCoins views.',
        );
      }
      if (trimmedAccountHolderName.isEmpty) {
        throw Exception('Account holder name is required.');
      }
      if (trimmedMethod != 'paypal' && trimmedMethod != 'revolut') {
        throw Exception('Select a payout method.');
      }
      if (trimmedMethod == 'paypal' && trimmedPayPalEmail.isEmpty) {
        throw Exception('Enter a PayPal email.');
      }
      if (trimmedMethod == 'revolut' && trimmedRevolutUsername.isEmpty) {
        throw Exception('Enter your Revolut username.');
      }
      if (currentCoins < coinsRequested) {
        throw Exception('Not enough views available.');
      }

      final userEmail = userData['email'] as String? ?? '';

      transaction.update(userRef, {
        'coins': currentCoins - coinsRequested,
      });

      transaction.set(payoutRef, {
        'userId': uid,
        'userEmail': userEmail,
        'coinsRequested': coinsRequested,
        'payoutMethod': trimmedMethod,
        'status': 'pending',
        'payPalEmail': trimmedPayPalEmail,
        // Legacy field kept for backward compatibility with existing data.
        'ibanOrBankAccount': trimmedRevolutUsername,
        'revolutUsername': trimmedRevolutUsername,
        'accountHolderName': trimmedAccountHolderName,
        'minimumPayoutCoins': minimumPayoutCoins,
        'processingDays': payoutProcessingDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<PayoutRequest>> watchAllPayoutRequests({String? status}) {
    final trimmedStatus = status?.trim().toLowerCase() ?? '';
    return _payouts
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final payouts = snapshot.docs
          .map(PayoutRequest.fromDoc)
          .toList(growable: false);
      if (trimmedStatus.isEmpty || trimmedStatus == 'all') return payouts;
      return payouts
          .where((payout) => payout.status.toLowerCase() == trimmedStatus)
          .toList(growable: false);
    });
  }

  Future<void> updatePayoutStatus({
    required String payoutId,
    required String status,
  }) async {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (!allowedPayoutStatuses.contains(normalized)) {
      throw Exception('Invalid payout status: $status');
    }

    final payoutRef = _payouts.doc(payoutId);
    await _firestore.runTransaction((transaction) async {
      final payoutSnapshot = await transaction.get(payoutRef);
      final payoutData = payoutSnapshot.data();
      if (payoutData == null) {
        throw Exception('Payout request not found.');
      }

      final currentStatus =
          (payoutData['status'] as String? ?? 'pending').trim().toLowerCase();
      if (currentStatus == normalized) {
        return;
      }

      final isValidTransition =
          (currentStatus == 'pending' &&
                  (normalized == 'approved' || normalized == 'rejected')) ||
              (currentStatus == 'approved' &&
                  (normalized == 'paid' || normalized == 'rejected'));

      if (!isValidTransition) {
        throw Exception(
          'Invalid payout transition: ${currentStatus.toUpperCase()} → ${normalized.toUpperCase()}',
        );
      }

      final updates = <String, dynamic>{
        'status': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalized == 'approved') {
        updates['approvedAt'] = FieldValue.serverTimestamp();
      }
      if (normalized == 'paid') {
        updates['paidAt'] = FieldValue.serverTimestamp();
      }
      if (normalized == 'rejected') {
        updates['rejectedAt'] = FieldValue.serverTimestamp();
      }

      final refundAlreadyApplied =
          payoutData['refundApplied'] as bool? ?? false;
      if (normalized == 'rejected' && !refundAlreadyApplied) {
        final userId = payoutData['userId'] as String? ?? '';
        final coinsRequested =
            (payoutData['coinsRequested'] as num?)?.toInt() ?? 0;
        if (userId.isNotEmpty && coinsRequested > 0) {
          final userRef = _users.doc(userId);
          final userSnapshot = await transaction.get(userRef);
          if (!userSnapshot.exists) {
            throw Exception('User profile not found for refund.');
          }

          transaction.update(userRef, {
            'coins': FieldValue.increment(coinsRequested),
          });
          updates['refundApplied'] = true;
          updates['refundedAt'] = FieldValue.serverTimestamp();
        }
      }

      transaction.set(payoutRef, updates, SetOptions(merge: true));
    });
  }

  Future<void> submitSupportTicket({
    required String uid,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    await _supportTickets.add({
      'userId': uid,
      'message': trimmed,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitBugReport({
    required String uid,
    required String title,
    required String description,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDesc = description.trim();
    if (trimmedTitle.isEmpty) {
      throw Exception('Title cannot be empty.');
    }
    if (trimmedDesc.isEmpty) {
      throw Exception('Description cannot be empty.');
    }

    await _bugReports.add({
      'userId': uid,
      'title': trimmedTitle,
      'description': trimmedDesc,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserSettings({
    required String uid,
    required bool notificationsEnabled,
    required bool dailyReminderEnabled,
  }) async {
    await _users.doc(uid).set({
      'settings': {
        'notificationsEnabled': notificationsEnabled,
        'dailyReminderEnabled': dailyReminderEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }
}
