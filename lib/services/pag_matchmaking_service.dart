import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'players_are_gamers_service.dart';

class PagMatchmakingService {
  PagMatchmakingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    PlayersAreGamersService? playersAreGamersService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _playersAreGamersService =
           playersAreGamersService ?? PlayersAreGamersService();

  static const String _collection = 'pagMatchmakingSignals';
  static const Duration signalLifetime = Duration(minutes: 3);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PlayersAreGamersService _playersAreGamersService;

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('No signed-in user available for matchmaking.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _signalRef =>
      _firestore.collection(_collection).doc(_currentUid);

  Future<void> publishWaitingSignal({
    required String gameId,
    required String gameName,
    required String gameUrl,
  }) async {
    final profile = await _playersAreGamersService.getCachedProfile();
    final email = _auth.currentUser?.email ?? profile?.email ?? '';
    final username = _preferredName(
      profile?.username ?? '',
      email,
      _currentUid,
    );
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(signalLifetime);

    await _signalRef.set({
      'uid': _currentUid,
      'gameId': gameId,
      'gameName': gameName,
      'gameUrl': gameUrl,
      'username': username,
      'createdAt': now.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'active': true,
    }, SetOptions(merge: true));
  }

  Future<void> clearOwnSignal() async {
    try {
      await _signalRef.delete();
    } catch (_) {}
  }

  Stream<PagMatchmakingSignal?> watchFeaturedSignal({
    String? excludeUid,
  }) {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final now = DateTime.now().toUtc();
      final signals =
          snapshot.docs
              .map((doc) => PagMatchmakingSignal.fromMap(doc.id, doc.data()))
              .where((signal) => signal.active)
              .where((signal) => signal.uid != excludeUid)
              .where((signal) => signal.expiresAt.isAfter(now))
              .toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return signals.isEmpty ? null : signals.first;
    });
  }

  String _preferredName(String username, String email, String uid) {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isNotEmpty) {
      return trimmedUsername;
    }
    final trimmedEmail = email.trim();
    if (trimmedEmail.isNotEmpty) {
      final atIndex = trimmedEmail.indexOf('@');
      if (atIndex > 0) {
        return trimmedEmail.substring(0, atIndex);
      }
      return trimmedEmail;
    }
    if (uid.length >= 6) {
      return 'player-${uid.substring(0, 6)}';
    }
    return 'player';
  }
}

class PagMatchmakingSignal {
  const PagMatchmakingSignal({
    required this.uid,
    required this.gameId,
    required this.gameName,
    required this.gameUrl,
    required this.username,
    required this.createdAt,
    required this.expiresAt,
    required this.active,
  });

  final String uid;
  final String gameId;
  final String gameName;
  final String gameUrl;
  final String username;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;

  factory PagMatchmakingSignal.fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    return PagMatchmakingSignal(
      uid: (data['uid'] ?? docId).toString(),
      gameId: (data['gameId'] ?? '').toString(),
      gameName: (data['gameName'] ?? '').toString(),
      gameUrl: (data['gameUrl'] ?? '').toString(),
      username: (data['username'] ?? '').toString(),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now().toUtc(),
      expiresAt:
          _parseDateTime(data['expiresAt']) ??
          DateTime.now().toUtc().add(PagMatchmakingService.signalLifetime),
      active: data['active'] != false,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
