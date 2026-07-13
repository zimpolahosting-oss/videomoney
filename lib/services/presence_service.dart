import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'firebase_bootstrap.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  static const String statusPath = 'status';

  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  StreamSubscription<User?>? _authSubscription;
  DatabaseReference? _connectionRef;
  String? _activeUid;
  bool _isInitialized = false;
  bool _isInForeground = true;

  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL,
      );

  Stream<int> watchOnlineUsersCount() {
    return _database.ref(statusPath).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return 0;

      var onlineUsers = 0;
      for (final entry in value.entries) {
        final connections = entry.value;
        if (connections is Map && connections.isNotEmpty) {
          onlineUsers += 1;
        }
      }
      return onlineUsers;
    });
  }

  /// Initializes presence tracking.
  ///
  /// This ensures presence starts automatically after login and stops on logout,
  /// without relying on specific screens being mounted.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await FirebaseBootstrap.ensureInitialized();

    WidgetsBinding.instance.addObserver(this);

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      final uid = user?.uid;
      if (uid == null || !_isInForeground) {
        await stop();
        return;
      }
      await start(uid: uid);
    });

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && _isInForeground) {
      await start(uid: currentUid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isInForeground = true;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(start(uid: uid));
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isInForeground = false;
        unawaited(stop());
        break;
    }
  }

  Future<void> start({required String uid}) async {
    if (_activeUid == uid && _connectedSubscription != null) return;
    await stop();
    await FirebaseBootstrap.ensureInitialized();

    _activeUid = uid;
    final connectedRef = _database.ref('.info/connected');
    final userConnectionsRef = _database.ref('$statusPath/$uid');

    _connectedSubscription = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value == true;
      if (!connected) return;

      final newConnectionRef = userConnectionsRef.push();
      await newConnectionRef.onDisconnect().remove();
      await newConnectionRef.set(true);
      _connectionRef = newConnectionRef;
    });
  }

  Future<void> stop() async {
    await _connectedSubscription?.cancel();
    _connectedSubscription = null;

    // Keep auth subscription active; stop() is called on logout/background.
    final ref = _connectionRef;
    _connectionRef = null;
    if (ref != null) {
      try {
        await ref.remove();
      } catch (_) {
        // Ignore cleanup errors (offline, permission, etc.).
      }
    }
    _activeUid = null;
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
    _authSubscription = null;
    await stop();
  }
}
