import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../services/presence_service.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _payoutNotificationSubscription;
  String? _lastSeenPayoutNotificationId;
  bool _isInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresence();
    unawaited(_initializePayoutNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _payoutNotificationSubscription?.cancel();
    unawaited(PresenceService.instance.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isInForeground = true;
        _startPresence();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isInForeground = false;
        unawaited(PresenceService.instance.stop());
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

  void _startPresence() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (!_isInForeground || uid == null) {
      return;
    }
    unawaited(PresenceService.instance.start(uid: uid));
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(isActiveTab: _currentIndex == 0),
          const WalletScreen(),
          const ProfileScreen(),
        ],
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
