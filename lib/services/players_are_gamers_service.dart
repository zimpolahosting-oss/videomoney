import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/players_are_gamers_profile.dart';
import 'firestore_service.dart';

class PlayersAreGamersService {
  PlayersAreGamersService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
    FirestoreService? firestoreService,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _firestoreService = firestoreService ?? FirestoreService();

  static const String registrationUrl = 'https://playersaregamers.nl/register.html';
  static const String loginUrl = 'https://playersaregamers.nl/login.php';
  static const String dashboardUrl = 'https://playersaregamers.nl/dashboard.php';
  static const String autoLoginUrl = 'https://playersaregamers.nl/auto-login.php';
  static const String _tokenStorageKey = 'pag_session_token';
  static const String _userStorageKey = 'pag_session_user';
  static const String _integrationCollection = 'integrations';
  static const String _integrationDoc = 'playersAreGamers';

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;
  final FirestoreService _firestoreService;

  User get _currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'You need to be signed in to use games.',
      );
    }
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _integrationRef =>
      _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .collection(_integrationCollection)
          .doc(_integrationDoc);

  Stream<PlayersAreGamersProfile?> watchProfile() {
    return _integrationRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return PlayersAreGamersProfile.fromFirestore(data);
    });
  }

  Future<PlayersAreGamersProfile?> getCachedProfile() async {
    final snapshot = await _integrationRef.get();
    final data = snapshot.data();
    if (data == null) return null;
    return PlayersAreGamersProfile.fromFirestore(data);
  }

  Future<PlayersAreGamersProfile> refreshProfile({bool includeStats = true}) async {
    Map<String, dynamic> response;
    try {
      response = await _call('pagGetPlayer');
    } on FirebaseFunctionsException catch (error) {
      if (_shouldUseProfileFallback(error)) {
        final cachedProfile = await getCachedProfile();
        if (cachedProfile != null) {
          return cachedProfile;
        }
        final fallbackProfile = PlayersAreGamersProfile.unlinked(
          firebaseUid: _currentUser.uid,
          syncedAt: DateTime.now(),
        );
        await _saveProfile(fallbackProfile);
        return fallbackProfile;
      }
      rethrow;
    }
    final linked = response['linked'] == true;
    if (!linked) {
      await _clearSession();
      final profile = PlayersAreGamersProfile.unlinked(
        firebaseUid: _currentUser.uid,
        syncedAt: DateTime.now(),
      );
      await _saveProfile(profile);
      return profile;
    }

    Map<String, dynamic>? statsPayload;
    if (includeStats) {
      try {
        statsPayload = await _call('pagGetStats');
      } on FirebaseFunctionsException {
        statsPayload = null;
      }
    }

    final profile = PlayersAreGamersProfile.fromApi(
      response,
      statsPayload: statsPayload,
    );
    await _persistSession(response);
    await _saveProfile(profile);
    return profile;
  }

  Future<PlayersAreGamersProfile> ensureLinkedProfile({
    bool includeStats = true,
    bool autoCreateIfMissing = true,
  }) async {
    final profile = await refreshProfile(includeStats: includeStats);
    if (profile.linked || !autoCreateIfMissing) {
      return profile;
    }
    return createAutomaticAccount(includeStats: includeStats);
  }

  Future<PlayersAreGamersProfile> linkExistingAccount({
    required String username,
    required String password,
  }) async {
    final response = await _call('pagLinkAccount', {
      'username': username.trim(),
      'password': password,
    });
    final stats =
        response['stats'] is Map
            ? (response['stats'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
            : null;
    final profile = PlayersAreGamersProfile.fromApi(
      response,
      statsPayload: stats,
    );
    await _persistSession(response);
    await _saveProfile(profile);
    return profile;
  }

  Future<PlayersAreGamersProfile> createAndLinkAccount({
    required String username,
    required String password,
  }) async {
    final response = await _call('pagCreateAndLinkAccount', {
      'username': username.trim(),
      'password': password,
    });
    final stats =
        response['stats'] is Map
            ? (response['stats'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
            : null;
    final profile = PlayersAreGamersProfile.fromApi(
      response,
      statsPayload: stats,
    );
    await _persistSession(response);
    await _saveProfile(profile);
    return profile;
  }

  Future<PlayersAreGamersProfile> createAutomaticAccount({
    bool includeStats = true,
  }) async {
    final response = await _call('pagCreateAutomaticAccount', {
      'includeStats': includeStats,
    });
    final stats =
        response['stats'] is Map
            ? (response['stats'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
            : null;
    final profile = PlayersAreGamersProfile.fromApi(
      response,
      statsPayload: stats,
    );
    await _persistSession(response);
    await _saveProfile(profile);
    return profile;
  }

  Future<Map<String, dynamic>> submitScore({
    required String gameId,
    required int score,
    required int playTime,
  }) {
    return _call('pagSubmitScore', {
      'gameId': gameId,
      'score': score,
      'playTime': playTime,
    });
  }

  Future<Map<String, dynamic>> rewardCoins({
    required String adId,
    int coins = 2,
    String rewardType = 'rewarded_ad',
  }) async {
    final response = await _call('pagRewardCoins', {
      'adId': adId,
      'coins': coins,
      'rewardType': rewardType,
    });
    await refreshProfile(includeStats: true);
    return response;
  }

  Future<Map<String, dynamic>> purchaseCoins({
    required int coins,
    required double amount,
    required String transactionId,
    required String packageId,
    String currency = 'USD',
  }) async {
    final response = await _call('pagPurchaseCoins', {
      'coins': coins,
      'amount': amount,
      'currency': currency,
      'transactionId': transactionId,
      'packageId': packageId,
    });
    await refreshProfile(includeStats: true);
    return response;
  }

  Future<PlayersAreGamersSession?> getStoredSession() async {
    final token = await _secureStorage.read(key: _tokenStorageKey);
    final userJson = await _secureStorage.read(key: _userStorageKey);
    if (token == null || token.isEmpty || userJson == null || userJson.isEmpty) {
      return null;
    }
    return PlayersAreGamersSession(token: token, userJson: userJson);
  }

  Future<PlayersAreGamersLaunchContext?> buildLaunchContext() async {
    var session = await getStoredSession();
    if (session == null) {
      session = await _generateSession();
      if (session == null) return null;
    }

    http.Response response = await http.post(
      Uri.parse(autoLoginUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'token': session.token}),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshedSession = await _generateSession();
      if (refreshedSession != null) {
        session = refreshedSession;
        response = await http.post(
          Uri.parse(autoLoginUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'token': session.token}),
        );
      }
    }

    final payload = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        (payload['message'] ?? payload['error'] ?? 'PlayersAreGamers auto-login failed.')
            .toString(),
      );
    }

    final redirectUrl =
        (payload['redirectUrl'] ?? payload['redirect_url'] ?? dashboardUrl)
            .toString();
    final cookies = _extractCookies(response.headers);

    return PlayersAreGamersLaunchContext(
      redirectUrl: redirectUrl.isEmpty ? dashboardUrl : redirectUrl,
      cookies: cookies,
    );
  }

  Future<void> grantReplayReward({
    int videomoneyViews = 3,
    int gameCoins = 2,
    required String adId,
  }) async {
    await rewardCoins(adId: adId, coins: gameCoins);
    await _firestoreService.applyUserProgress(
      uid: _currentUser.uid,
      viewsDelta: videomoneyViews,
      videosWatchedDelta: 1,
    );
  }

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic>? payload,
  ]) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call<Map<dynamic, dynamic>>(payload);
    final data = result.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  bool _shouldUseProfileFallback(FirebaseFunctionsException error) {
    return error.code == 'internal' ||
        error.code == 'unknown' ||
        error.code == 'unavailable' ||
        error.code == 'deadline-exceeded';
  }

  Future<void> _saveProfile(PlayersAreGamersProfile profile) async {
    await _integrationRef.set(profile.toFirestore(), SetOptions(merge: true));
  }

  Future<void> _persistSession(Map<String, dynamic> response) async {
    final token = response['token']?.toString();
    final player = response['player'];
    if (token == null || token.isEmpty || player is! Map) return;
    await _secureStorage.write(key: _tokenStorageKey, value: token);
    await _secureStorage.write(
      key: _userStorageKey,
      value: jsonEncode(
        player.map((key, dynamic value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: _tokenStorageKey);
    await _secureStorage.delete(key: _userStorageKey);
  }

  Future<PlayersAreGamersSession?> _generateSession() async {
    final response = await _call('pagGenerateToken');
    final token = response['token']?.toString();
    final player = response['player'];
    if (token == null || token.isEmpty || player is! Map) {
      return null;
    }
    await _persistSession(response);
    return getStoredSession();
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  List<PlayersAreGamersCookie> _extractCookies(Map<String, String> headers) {
    final rawCookie = headers['set-cookie'];
    if (rawCookie == null || rawCookie.isEmpty) {
      return const <PlayersAreGamersCookie>[];
    }

    final matches = RegExp(r'([A-Za-z0-9_]+)=([^;,]+)').allMatches(rawCookie);
    final cookies = <PlayersAreGamersCookie>[];
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2);
      if (name == null || value == null) continue;
      if (name.toLowerCase() == 'path' ||
          name.toLowerCase() == 'expires' ||
          name.toLowerCase() == 'domain' ||
          name.toLowerCase() == 'samesite' ||
          name.toLowerCase() == 'max-age') {
        continue;
      }
      cookies.add(
        PlayersAreGamersCookie(
          name: name,
          value: value,
          domain: 'playersaregamers.nl',
          path: '/',
          isSecure: true,
        ),
      );
    }
    return cookies;
  }
}
