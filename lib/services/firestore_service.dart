import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_rating.dart';
import '../models/app_user.dart';
import '../models/inbox_message.dart';
import '../models/leaderboard_entry.dart';
import '../models/payout_request.dart';
import '../models/support_ticket.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int rewardCoinsPerVideo = 1;
  static const int dailyBonusTargetVideos = 20;
  static const int dailyBonusViews = 500;
  static const int minimumPayoutCoins = 10000;
  static const int payoutProcessingDays = 30;
  static const int estimatedViewsPerCent = 50;
  static const int presenceHeartbeatSeconds = 30;
  static const int presenceTtlSeconds = 90;
  static const String rewardBalanceResetAppliedField =
      'rewardBalanceResetApplied';
  static const Set<String> allowedPayoutStatuses = {
    'pending',
    'approved',
    'paid',
    'rejected',
  };
  static const Set<String> allowedPayoutMethods = {
    'paypal',
    'revolut',
    'bank',
  };
  static const Set<String> allowedPayoutCurrencies = {
    'EUR',
    'GBP',
    'USD',
  };
  static const Set<String> allowedSupportTypes = {
    'support',
    'payment',
    'bug',
  };
  static const Set<String> allowedSupportStatuses = {
    'pending',
    'processing',
    'fixed',
    'closed',
  };

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _payouts =>
      _firestore.collection('payouts');

  CollectionReference<Map<String, dynamic>> get _supportTickets =>
      _firestore.collection('supportTickets');

  CollectionReference<Map<String, dynamic>> get _inboxMessages =>
      _firestore.collection('inboxMessages');

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection('ratings');

  CollectionReference<Map<String, dynamic>> get _activeUsers =>
      _firestore.collection('activeUsers');

  CollectionReference<Map<String, dynamic>> get _payoutLiveNotifications =>
      _firestore.collection('payoutLiveNotifications');

  CollectionReference<Map<String, dynamic>> get _adminNotifications =>
      _firestore.collection('adminNotifications');

  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _firestore.collection('leaderboard');

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
      final updates = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'appVerified': true,
      };

      if (!rewardBalanceResetApplied) {
        updates.addAll({
          'coins': 0,
          rewardBalanceResetAppliedField: true,
        });
      }

      if (!data.containsKey('dailyProgressDate')) {
        updates['dailyProgressDate'] = todayKey;
      }
      if (!data.containsKey('dailyVideosWatched')) {
        updates['dailyVideosWatched'] = 0;
      }
      if (!data.containsKey('dailyBonusAwarded')) {
        updates['dailyBonusAwarded'] = false;
      }
      if (!data.containsKey('settings')) {
        updates['settings'] = {
          'notificationsEnabled': true,
          'dailyReminderEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }
      if (!data.containsKey('fcmTokens')) {
        updates['fcmTokens'] = <String>[];
      }
      if (!data.containsKey('createdAt')) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }
      if (!data.containsKey('leaderboardDisplayName')) {
        updates['leaderboardDisplayName'] = '';
      }
      await docRef.set(updates, SetOptions(merge: true));
      await _syncLeaderboardDoc(
        uid: user.uid,
        email: user.email ?? '',
        customName: (data['leaderboardDisplayName'] as String? ?? '').trim(),
        views: (data['coins'] as num?)?.toInt() ?? 0,
        videosWatched: (data['videosWatched'] as num?)?.toInt() ?? 0,
      );
      return;
    }

    await docRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'leaderboardDisplayName': '',
      'coins': 0,
      'videosWatched': 0,
      'dailyProgressDate': todayKey,
      'dailyVideosWatched': 0,
      'dailyBonusAwarded': false,
      'isAdmin': false,
      'appVerified': true,
      'fcmTokens': <String>[],
      'settings': {
        'notificationsEnabled': true,
        'dailyReminderEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      rewardBalanceResetAppliedField: true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _syncLeaderboardDoc(
      uid: user.uid,
      email: user.email ?? '',
      customName: '',
      views: 0,
      videosWatched: 0,
    );
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

  Stream<int> watchUnreadInboxCount(String uid) {
    return _inboxMessages
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<LeaderboardEntry>> watchLeaderboard({int limit = 10}) {
    return _leaderboard
        .orderBy('views', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs.map(LeaderboardEntry.fromDoc).toList();
      entries.sort((a, b) {
        final byViews = b.views.compareTo(a.views);
        if (byViews != 0) return byViews;
        final byVideos = b.videosWatched.compareTo(a.videosWatched);
        if (byVideos != 0) return byVideos;
        return a.publicName.compareTo(b.publicName);
      });
      return entries;
    });
  }

  Future<void> updateUserPresence({
    required String uid,
  }) async {
    final now = DateTime.now();
    await _activeUsers.doc(uid).set({
      'uid': uid,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        now.add(const Duration(seconds: presenceTtlSeconds)),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearUserPresence({
    required String uid,
  }) async {
    await _activeUsers.doc(uid).delete();
  }

  Stream<int> watchOnlineUsersCount({
    Duration refreshInterval = const Duration(
      seconds: presenceHeartbeatSeconds,
    ),
  }) async* {
    while (true) {
      yield await _getOnlineUsersCount();
      await Future<void>.delayed(refreshInterval);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      watchLatestPayoutLiveNotifications({
    int limit = 1,
  }) {
    return _payoutLiveNotifications
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<List<InboxMessage>> watchUserInbox(String uid) {
    return _inboxMessages
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map(InboxMessage.fromDoc).toList();
      messages.sort((a, b) {
        final aCreated = a.createdAt;
        final bCreated = b.createdAt;
        if (aCreated == null && bCreated == null) return 0;
        if (aCreated == null) return 1;
        if (bCreated == null) return -1;
        return bCreated.compareTo(aCreated);
      });
      return messages;
    });
  }

  Stream<List<InboxMessage>> watchAllInboxMessages() {
    return _inboxMessages
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map(InboxMessage.fromDoc).toList();
      messages.sort((a, b) {
        final aCreated = a.createdAt;
        final bCreated = b.createdAt;
        if (aCreated == null && bCreated == null) return 0;
        if (aCreated == null) return 1;
        if (bCreated == null) return -1;
        return bCreated.compareTo(aCreated);
      });
      return messages;
    });
  }

  Future<void> markInboxMessageRead(String messageId) async {
    await _inboxMessages.doc(messageId).set({
      'read': true,
    }, SetOptions(merge: true));
  }

  Future<void> markAllInboxMessagesRead(String uid) async {
    final snapshot = await _inboxMessages
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> createInboxMessage({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    await _inboxMessages.add({
      'userId': userId,
      'title': title.trim(),
      'message': message.trim(),
      'type': type.trim().isEmpty ? 'info' : type.trim().toLowerCase(),
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
      final newViews = ((data['coins'] as num?)?.toInt() ?? 0) +
          coinsReward +
          (bonusTriggered ? FirestoreService.dailyBonusViews : 0);
      final newVideosWatched =
          ((data['videosWatched'] as num?)?.toInt() ?? 0) + 1;

      transaction.update(userRef, {
        'coins': FieldValue.increment(
          coinsReward + (bonusTriggered ? FirestoreService.dailyBonusViews : 0),
        ),
        'videosWatched': FieldValue.increment(1),
        'dailyProgressDate': todayKey,
        'dailyVideosWatched': newDailyCount,
        'dailyBonusAwarded': bonusTriggered ? true : baseBonusAwarded,
        if (bonusTriggered) 'dailyBonusAwardedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _leaderboard.doc(uid),
        _leaderboardPayload(
          uid: uid,
          email: data['email'] as String? ?? '',
          customName: data['leaderboardDisplayName'] as String? ?? '',
          views: newViews,
          videosWatched: newVideosWatched,
        ),
        SetOptions(merge: true),
      );
    });
  }

  Stream<List<PayoutRequest>> watchPayouts(String uid) {
    return _payouts
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PayoutRequest.fromDoc).toList(growable: false),
        );
  }

  Future<void> createPayoutRequest({
    required String uid,
    required int coinsRequested,
    required String payoutMethod,
    required String payPalEmail,
    required String revolutUsername,
    required String accountHolderName,
    required String payoutCurrency,
    required String bankName,
    required String iban,
    required String bankAccountNumber,
  }) async {
    final userRef = _users.doc(uid);
    final payoutRef = _payouts.doc();
    final trimmedPayPalEmail = payPalEmail.trim();
    final trimmedRevolutUsername = revolutUsername.trim();
    final trimmedAccountHolderName = accountHolderName.trim();
    final trimmedMethod = payoutMethod.trim().toLowerCase();
    final trimmedCurrency = payoutCurrency.trim().toUpperCase();
    final trimmedBankName = bankName.trim();
    final trimmedIban = iban.trim();
    final trimmedBankAccountNumber = bankAccountNumber.trim();
    final legacyBankValue =
        trimmedIban.isNotEmpty ? trimmedIban : trimmedBankAccountNumber;

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
      if (!allowedPayoutMethods.contains(trimmedMethod)) {
        throw Exception('Select a payout method.');
      }
      if (!allowedPayoutCurrencies.contains(trimmedCurrency)) {
        throw Exception('Select a payout currency.');
      }
      if (trimmedMethod == 'paypal' && trimmedPayPalEmail.isEmpty) {
        throw Exception('Enter a PayPal email.');
      }
      if (trimmedMethod == 'revolut' && trimmedRevolutUsername.isEmpty) {
        throw Exception('Enter your Revolut username.');
      }
      if (trimmedMethod == 'bank') {
        if (trimmedBankName.isEmpty) {
          throw Exception('Enter your bank name.');
        }
        if (trimmedIban.isEmpty && trimmedBankAccountNumber.isEmpty) {
          throw Exception('Enter an IBAN or bank account number.');
        }
      }
      if (currentCoins < coinsRequested) {
        throw Exception('Not enough views available.');
      }

      final userEmail = userData['email'] as String? ?? '';
      final customName =
          (userData['leaderboardDisplayName'] as String? ?? '').trim();
      final currentVideosWatched =
          (userData['videosWatched'] as num?)?.toInt() ?? 0;
      final remainingViews = currentCoins - coinsRequested;

      transaction.update(userRef, {
        'coins': currentCoins - coinsRequested,
      });
      transaction.set(
        _leaderboard.doc(uid),
        _leaderboardPayload(
          uid: uid,
          email: userEmail,
          customName: customName,
          views: remainingViews,
          videosWatched: currentVideosWatched,
        ),
        SetOptions(merge: true),
      );

      transaction.set(payoutRef, {
        'userId': uid,
        'userEmail': userEmail,
        'coinsRequested': coinsRequested,
        'payoutMethod': trimmedMethod,
        'payoutCurrency': trimmedCurrency,
        'status': 'pending',
        'payPalEmail': trimmedPayPalEmail,
        'ibanOrBankAccount': trimmedMethod == 'revolut'
            ? trimmedRevolutUsername
            : legacyBankValue,
        'revolutUsername': trimmedRevolutUsername,
        'accountHolderName': trimmedAccountHolderName,
        'bankName': trimmedBankName,
        'iban': trimmedIban,
        'bankAccountNumber': trimmedBankAccountNumber,
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
      final payouts =
          snapshot.docs.map(PayoutRequest.fromDoc).toList(growable: false);
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

      final isValidTransition = (currentStatus == 'pending' &&
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
        updates['paymentHandledManually'] = true;

        final userId = payoutData['userId'] as String? ?? '';
        final accountHolderName =
            payoutData['accountHolderName'] as String? ?? '';
        final userEmail = payoutData['userEmail'] as String? ?? '';
        final payoutCurrency =
            (payoutData['payoutCurrency'] as String? ?? 'EUR').toUpperCase();
        final coinsRequested =
            (payoutData['coinsRequested'] as num?)?.toInt() ?? 0;

        String userCountry = '';
        if (userId.isNotEmpty) {
          final userSnapshot = await transaction.get(_users.doc(userId));
          final userData = userSnapshot.data() ?? <String, dynamic>{};
          final rawCountry = (userData['country'] ??
                  userData['countryName'] ??
                  userData['locationCountry'] ??
                  '')
              .toString();
          userCountry = rawCountry.trim();
        }

        final privacyName = _buildPrivacyDisplayName(
          accountHolderName: accountHolderName,
          userEmail: userEmail,
        );
        final amountLabel = _formatPayoutAmountLabel(
          coinsRequested: coinsRequested,
          currencyCode: payoutCurrency,
        );
        final payoutMessage = _buildPayoutAnnouncementMessage(
          privacyName: privacyName,
          userCountry: userCountry,
          amountLabel: amountLabel,
        );

        transaction.set(_payoutLiveNotifications.doc(), {
          'payoutId': payoutId,
          'userId': userId,
          'title': 'New payout completed',
          'privacyName': privacyName,
          'country': userCountry,
          'amountLabel': amountLabel,
          'message': payoutMessage,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(_adminNotifications.doc(), {
          'createdByUid': 'system',
          'createdByEmail': 'system@videomoney.app',
          'audience': 'all',
          'targetUserId': null,
          'type': 'payout',
          'title': 'New payout completed',
          'message': payoutMessage,
          'status': 'pending',
          'errorMessage': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'payout_paid',
          'sourcePayoutId': payoutId,
        });
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
          final userData = userSnapshot.data() ?? <String, dynamic>{};
          final email = userData['email'] as String? ?? '';
          final customName =
              (userData['leaderboardDisplayName'] as String? ?? '').trim();
          final currentViews = (userData['coins'] as num?)?.toInt() ?? 0;
          final videosWatched =
              (userData['videosWatched'] as num?)?.toInt() ?? 0;

          transaction.update(userRef, {
            'coins': FieldValue.increment(coinsRequested),
          });
          transaction.set(
            _leaderboard.doc(userId),
            _leaderboardPayload(
              uid: userId,
              email: email,
              customName: customName,
              views: currentViews + coinsRequested,
              videosWatched: videosWatched,
            ),
            SetOptions(merge: true),
          );
          updates['refundApplied'] = true;
          updates['refundedAt'] = FieldValue.serverTimestamp();
        }
      }

      transaction.set(payoutRef, updates, SetOptions(merge: true));
    });
  }

  Future<void> submitSupportTicket({
    required String uid,
    required String email,
    required String type,
    required String subject,
    required String message,
  }) async {
    final normalizedType = type.trim().toLowerCase();
    final normalizedSubject = subject.trim();
    final trimmed = message.trim();
    if (!allowedSupportTypes.contains(normalizedType)) {
      throw Exception('Invalid support type.');
    }
    if (normalizedSubject.isEmpty) {
      throw Exception('Subject cannot be empty.');
    }
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    await _supportTickets.add({
      'userId': uid,
      'email': email.trim(),
      'type': normalizedType,
      'subject': normalizedSubject,
      'message': trimmed,
      'status': 'pending',
      'latestReply': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitBugReport({
    required String uid,
    required String email,
    required String title,
    required String description,
  }) async {
    await submitSupportTicket(
      uid: uid,
      email: email,
      type: 'bug',
      subject: title,
      message: description,
    );
  }

  Stream<List<SupportTicket>> watchSupportTicketsForUser(String uid) {
    return _supportTickets
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SupportTicket.fromDoc).toList(growable: false),
        );
  }

  Stream<List<SupportTicket>> watchAllSupportTickets() {
    return _supportTickets
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SupportTicket.fromDoc).toList(growable: false),
        );
  }

  Future<void> replyToSupportTicket({
    required String ticketId,
    required String status,
    required String replyMessage,
    required String adminUserId,
    required String adminEmail,
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    final trimmedReply = replyMessage.trim();
    if (!allowedSupportStatuses.contains(normalizedStatus)) {
      throw Exception('Invalid ticket status.');
    }
    if (trimmedReply.isEmpty) {
      throw Exception('Reply cannot be empty.');
    }

    final ticketRef = _supportTickets.doc(ticketId);
    final inboxRef = _inboxMessages.doc();
    await _firestore.runTransaction((transaction) async {
      final ticketSnapshot = await transaction.get(ticketRef);
      final ticketData = ticketSnapshot.data();
      if (ticketData == null) {
        throw Exception('Support ticket not found.');
      }

      final userId = ticketData['userId'] as String? ?? '';
      final subject = ticketData['subject'] as String? ?? 'Support update';
      final type = ticketData['type'] as String? ?? 'support';

      transaction.set(
          ticketRef,
          {
            'status': normalizedStatus,
            'latestReply': trimmedReply,
            'latestReplyAt': FieldValue.serverTimestamp(),
            'latestReplyBy': adminUserId,
            'latestReplyEmail': adminEmail.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      transaction.set(inboxRef, {
        'userId': userId,
        'title': 'Reply: $subject',
        'message': trimmedReply,
        'type': type,
        'read': false,
        'ticketId': ticketId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateSupportTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    if (!allowedSupportStatuses.contains(normalizedStatus)) {
      throw Exception('Invalid ticket status.');
    }
    await _supportTickets.doc(ticketId).set({
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> updateLeaderboardDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final trimmedName = displayName.trim();
    final normalizedName =
        trimmedName.length > 18 ? trimmedName.substring(0, 18) : trimmedName;
    final userRef = _users.doc(uid);
    final leaderboardRef = _leaderboard.doc(uid);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data();
      if (userData == null) {
        throw Exception('User profile not found.');
      }

      final email = userData['email'] as String? ?? '';
      final views = (userData['coins'] as num?)?.toInt() ?? 0;
      final videosWatched = (userData['videosWatched'] as num?)?.toInt() ?? 0;

      transaction.set(
          userRef,
          {
            'leaderboardDisplayName': normalizedName,
          },
          SetOptions(merge: true));
      transaction.set(
        leaderboardRef,
        _leaderboardPayload(
          uid: uid,
          email: email,
          customName: normalizedName,
          views: views,
          videosWatched: videosWatched,
        ),
        SetOptions(merge: true),
      );
    });
  }

  Future<void> saveUserFcmToken({
    required String uid,
    required String token,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;
    await _users.doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([trimmedToken]),
      'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeUserFcmToken({
    required String uid,
    required String token,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;
    await _users.doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([trimmedToken]),
      'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitRating({
    required String uid,
    required String email,
    required int stars,
  }) async {
    if (stars < 1 || stars > 5) {
      throw Exception('Rating must be between 1 and 5 stars.');
    }

    final docRef = _ratings.doc(uid);
    final snapshot = await docRef.get();
    final alreadyExists = snapshot.exists;
    await docRef.set({
      'userId': uid,
      'email': email.trim(),
      'stars': stars,
      if (!alreadyExists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<AppRating?> watchUserRating(String uid) {
    return _ratings.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppRating.fromDoc(doc);
    });
  }

  Stream<List<AppRating>> watchAllRatings() {
    return _ratings.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map(AppRating.fromDoc).toList(growable: false),
        );
  }

  Stream<List<AppUser>> watchAllUsers() {
    return _users.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> createAdminNotification({
    required String createdByUid,
    required String createdByEmail,
    required String audience,
    required String type,
    required String title,
    required String message,
    String? targetUserId,
  }) async {
    final normalizedAudience = audience.trim().toLowerCase();
    final normalizedType = type.trim().toLowerCase();
    final trimmedTitle = title.trim();
    final trimmedMessage = message.trim();
    if (normalizedAudience != 'all' && normalizedAudience != 'user') {
      throw Exception('Invalid audience.');
    }
    if (trimmedTitle.isEmpty || trimmedMessage.isEmpty) {
      throw Exception('Title and message are required.');
    }
    if (normalizedAudience == 'user' &&
        (targetUserId == null || targetUserId.trim().isEmpty)) {
      throw Exception('Select a user.');
    }

    final notificationRef = _adminNotifications.doc();
    final notificationId = notificationRef.id;
    final normalizedTypeValue =
        normalizedType.isEmpty ? 'announcement' : normalizedType;
    final targetUid = normalizedAudience == 'user' ? targetUserId!.trim() : null;

    await notificationRef.set({
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail.trim(),
      'audience': normalizedAudience,
      'targetUserId': targetUid,
      'type': normalizedTypeValue,
      'title': trimmedTitle,
      'message': trimmedMessage,
      'status': 'pending',
      'errorMessage': '',
      'deliveredCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      if (normalizedAudience == 'user') {
        await createInboxMessage(
          userId: targetUid!,
          title: trimmedTitle,
          message: trimmedMessage,
          type: normalizedTypeValue,
        );
        await notificationRef.set({
          'status': 'sent',
          'deliveredCount': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final usersSnapshot = await _users.get();
      final userIds = usersSnapshot.docs
          .map((doc) => doc.id.trim())
          .where((uid) => uid.isNotEmpty)
          .toList(growable: false);

      if (userIds.isEmpty) {
        await notificationRef.set({
          'status': 'sent',
          'deliveredCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      var deliveredCount = 0;
      WriteBatch batch = _firestore.batch();
      var operationCount = 0;

      Future<void> commitBatchIfNeeded({bool force = false}) async {
        if (operationCount == 0) return;
        if (!force && operationCount < 400) return;
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }

      for (final userId in userIds) {
        final inboxRef = _inboxMessages.doc();
        batch.set(inboxRef, {
          'userId': userId,
          'title': trimmedTitle,
          'message': trimmedMessage,
          'type': normalizedTypeValue,
          'read': false,
          'notificationId': notificationId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        deliveredCount += 1;
        operationCount += 1;
        await commitBatchIfNeeded();
      }

      await commitBatchIfNeeded(force: true);
      await notificationRef.set({
        'status': 'sent',
        'deliveredCount': deliveredCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      await notificationRef.set({
        'status': 'failed',
        'errorMessage': error.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAdminNotifications() {
    return _adminNotifications
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _syncLeaderboardDoc({
    required String uid,
    required String email,
    required String customName,
    required int views,
    required int videosWatched,
  }) async {
    await _leaderboard.doc(uid).set(
          _leaderboardPayload(
            uid: uid,
            email: email,
            customName: customName,
            views: views,
            videosWatched: videosWatched,
          ),
          SetOptions(merge: true),
        );
  }

  Map<String, dynamic> _leaderboardPayload({
    required String uid,
    required String email,
    required String customName,
    required int views,
    required int videosWatched,
  }) {
    final trimmedCustomName = customName.trim();
    return {
      'uid': uid,
      'customName': trimmedCustomName,
      'publicName': _buildLeaderboardPublicName(
        email: email,
        customName: trimmedCustomName,
      ),
      'views': views,
      'videosWatched': videosWatched,
      'estimatedEarnings': estimateEarningsEuro(views),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<int> _getOnlineUsersCount() async {
    final snapshot = await _activeUsers.get();
    final now = DateTime.now();
    final expiredRefs = <DocumentReference<Map<String, dynamic>>>[];
    var count = 0;

    for (final doc in snapshot.docs) {
      final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isAfter(now)) {
        count += 1;
      } else {
        expiredRefs.add(doc.reference);
      }
    }

    if (expiredRefs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final ref in expiredRefs) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    return count;
  }

  String _buildPrivacyDisplayName({
    required String accountHolderName,
    required String userEmail,
  }) {
    final trimmedName = accountHolderName.trim();
    if (trimmedName.isNotEmpty) {
      final nameParts = trimmedName
          .split(RegExp(r'\s+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (nameParts.isNotEmpty) {
        final firstName = _capitalizeWord(nameParts.first);
        if (nameParts.length > 1) {
          final lastInitial = nameParts[1][0].toUpperCase();
          return '$firstName $lastInitial.';
        }
        return firstName;
      }
    }

    final localPart = userEmail.split('@').first.trim();
    if (localPart.isNotEmpty) {
      final token = localPart
          .split(RegExp(r'[._\-+]'))
          .firstWhere((part) => part.trim().isNotEmpty, orElse: () => '');
      if (token.isNotEmpty) {
        return _capitalizeWord(token);
      }
    }
    return 'Someone';
  }

  String _buildLeaderboardPublicName({
    required String email,
    required String customName,
  }) {
    final trimmedCustomName = customName.trim();
    if (trimmedCustomName.isNotEmpty) {
      return trimmedCustomName;
    }
    return _maskEmailForLeaderboard(email);
  }

  String _maskEmailForLeaderboard(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'Gebruiker';
    final safeLocalPart = localPart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (safeLocalPart.isEmpty) return 'Gebruiker';
    final visible = safeLocalPart.length <= 3
        ? safeLocalPart
        : safeLocalPart.substring(0, 3);
    return '${visible.toUpperCase()}***';
  }

  String _capitalizeWord(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  String _formatPayoutAmountLabel({
    required int coinsRequested,
    required String currencyCode,
  }) {
    final symbol = switch (currencyCode.toUpperCase()) {
      'GBP' => '£',
      'USD' => r'$',
      _ => '€',
    };

    final amount = estimateEarningsEuro(coinsRequested);
    final normalizedAmount = amount.toStringAsFixed(2);
    final compactAmount = normalizedAmount.endsWith('.00')
        ? normalizedAmount.substring(0, normalizedAmount.length - 3)
        : normalizedAmount.endsWith('0')
            ? normalizedAmount.substring(0, normalizedAmount.length - 1)
            : normalizedAmount;
    return '$symbol$compactAmount';
  }

  String _buildPayoutAnnouncementMessage({
    required String privacyName,
    required String userCountry,
    required String amountLabel,
  }) {
    if (userCountry.trim().isNotEmpty) {
      return '🎉 $privacyName from ${userCountry.trim()} just received $amountLabel.';
    }
    return '💸 $privacyName just received a $amountLabel payout.';
  }
}
