import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  static const String statusPath = 'status';

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  DatabaseReference? _connectionRef;
  String? _activeUid;

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

  Future<void> start({required String uid}) async {
    if (_activeUid == uid && _connectedSubscription != null) return;
    await stop();

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
}
