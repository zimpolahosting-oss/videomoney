import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import 'earn_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const String _lastSeenPayoutNotificationKey =
      'last_seen_payout_notification_id';

  final FirestoreService _firestoreService = FirestoreService();
  int _currentIndex = 0;
  Timer? _presenceHeartbeatTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _payoutNotificationSubscription;
  String? _activeUserId;
  String? _lastSeenPayoutNotificationId;
  bool _isInForeground = true;

  static const List<Widget> _screens = [
    HomeScreen(),
    EarnScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresenceHeartbeat();
    unawaited(_initializePayoutNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceHeartbeatTimer?.cancel();
    _payoutNotificationSubscription?.cancel();
    final uid = _activeUserId;
    if (uid != null) {
      unawaited(_firestoreService.clearUserPresence(uid: uid));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isInForeground = true;
        _startPresenceHeartbeat();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isInForeground = false;
        _stopPresenceHeartbeat(clearPresence: true);
        break;
    }
  }

  Future<void> _initializePayoutNotifications() async {
    await _restoreLastSeenPayoutNotification();
    if (!mounted) return;
    _listenForPayoutNotifications();
  }

  Future<void> _restoreLastSeenPayoutNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenPayoutNotificationId =
        prefs.getString(_lastSeenPayoutNotificationKey);
  }

  Future<void> _storeLastSeenPayoutNotification(String notificationId) async {
    _lastSeenPayoutNotificationId = notificationId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenPayoutNotificationKey, notificationId);
  }

  void _startPresenceHeartbeat() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    _activeUserId = uid;

    _presenceHeartbeatTimer?.cancel();
    if (!_isInForeground || uid == null) {
      return;
    }

    unawaited(_firestoreService.updateUserPresence(uid: uid));
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: FirestoreService.presenceHeartbeatSeconds),
      (_) {
        final activeUid = _activeUserId;
        if (!_isInForeground || activeUid == null) {
          return;
        }
        unawaited(_firestoreService.updateUserPresence(uid: activeUid));
      },
    );
  }

  void _stopPresenceHeartbeat({bool clearPresence = false}) {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    final uid = _activeUserId;
    if (clearPresence && uid != null) {
      unawaited(_firestoreService.clearUserPresence(uid: uid));
    }
  }

  void _listenForPayoutNotifications() {
    _payoutNotificationSubscription?.cancel();
    _payoutNotificationSubscription = _firestoreService
        .watchLatestPayoutLiveNotifications()
        .listen((snapshot) {
      if (!mounted || snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      if (doc.id == _lastSeenPayoutNotificationId) return;

      final data = doc.data();
      final message = (data['message'] as String? ?? '').trim();
      if (message.isEmpty) return;

      unawaited(_storeLastSeenPayoutNotification(doc.id));
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 94),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            height: 74,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.play_circle_outline),
                selectedIcon: const Icon(Icons.play_circle),
                label: l10n.earn,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: l10n.wallet,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
