import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/presence_service.dart';
import '../../theme/app_theme.dart';
import 'games_screen.dart';
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
  static const String _introSeenKey = 'fullscreen_intro_seen_v1';
  static const Duration _secondaryTabWarmupDelay = Duration(seconds: 3);

  final FirestoreService _firestoreService = FirestoreService();
  final PlayersAreGamersService _playersAreGamersService = PlayersAreGamersService();
  late final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _homeReady = false;
  final Set<int> _visitedTabs = <int>{0};
  final Set<int> _readyTabs = <int>{0};
  final Map<int, Timer> _tabWarmupTimers = <int, Timer>{};
  int _homeTabRecoveryToken = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _payoutNotificationSubscription;
  String? _lastSeenPayoutNotificationId;
  bool _isInForeground = true;
  Timer? _homeStartupTimer;
  Timer? _presenceStartupTimer;
  Timer? _notificationsStartupTimer;
  Timer? _pagSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeStartupTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _homeReady = true;
      });
    });
    _presenceStartupTimer = Timer(const Duration(seconds: 12), () {
      _startPresence();
    });
    _notificationsStartupTimer = Timer(const Duration(seconds: 14), () {
      unawaited(_initializePayoutNotifications());
    });
    _pagSyncTimer = Timer(const Duration(seconds: 16), () {
      unawaited(_syncPlayersAreGamersProfile());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowFullscreenIntro());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _payoutNotificationSubscription?.cancel();
    _homeStartupTimer?.cancel();
    _presenceStartupTimer?.cancel();
    _notificationsStartupTimer?.cancel();
    _pagSyncTimer?.cancel();
    _pageController.dispose();
    for (final timer in _tabWarmupTimers.values) {
      timer.cancel();
    }
    _tabWarmupTimers.clear();
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

  Future<void> _syncPlayersAreGamersProfile() async {
    try {
      await _playersAreGamersService.refreshProfile(includeStats: false);
    } catch (_) {}
  }

  Future<void> _maybeShowFullscreenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_introSeenKey) ?? false;
    if (alreadySeen || !mounted) return;

    final copy = _FullscreenIntroCopy.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: const Color(0x331AE47A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2200FF88),
                  blurRadius: 28,
                  spreadRadius: -12,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  copy.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _IntroRow(
                  icon: Icons.swipe_left_alt_rounded,
                  title: copy.pagesTitle,
                  message: copy.pagesBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.swap_vert_rounded,
                  title: copy.videosTitle,
                  message: copy.videosBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.splitscreen_rounded,
                  title: copy.splitTitle,
                  message: copy.splitBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.visibility_outlined,
                  title: copy.rulesTitle,
                  message: copy.rulesBody,
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(copy.closeLabel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await prefs.setBool(_introSeenKey, true);
  }

  void _listenForPayoutNotifications() {
    _payoutNotificationSubscription?.cancel();
    _payoutNotificationSubscription = _firestoreService
        .watchLatestPayoutLiveNotifications()
        .listen((snapshot) {
      if (!mounted || snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      if (_lastSeenPayoutNotificationId == null) {
        unawaited(_storeLastSeenPayoutNotification(doc.id));
        return;
      }
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

  void _openTab(int index, {bool animate = false}) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
      if (index == 0 && previousIndex != 0) {
        _homeTabRecoveryToken++;
      }
    });
    if (index == 0 || _readyTabs.contains(index) || _tabWarmupTimers.containsKey(index)) {
      if (animate && _pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    _tabWarmupTimers[index] = Timer(_secondaryTabWarmupDelay, () {
      _tabWarmupTimers.remove(index);
      if (!mounted) return;
      setState(() {
        _readyTabs.add(index);
      });
    });
    if (animate && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => _openTab(index),
            children: [
              _buildTab(index: 0),
              _buildTab(index: 1),
              _buildTab(index: 2),
              _buildTab(index: 3),
            ],
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xB60A1110),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x331AE47A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (index) {
                        final active = index == _currentIndex;
                        final label = switch (index) {
                          0 => l10n.home,
                          1 => 'Games',
                          2 => l10n.wallet,
                          _ => l10n.profile,
                        };
                        return Padding(
                          padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF19E27A).withOpacity(0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: active ? Colors.white : AppTheme.textMuted,
                                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({required int index}) {
    if (!_visitedTabs.contains(index) && index != 0) {
      return _TabStartupPlaceholder(index: index);
    }

    return switch (index) {
      0 => _homeReady
          ? HomeScreen(
              isActiveTab: _currentIndex == 0,
              recoveryToken: _homeTabRecoveryToken,
            )
          : const _HomeStartupPlaceholder(),
      1 || 2 || 3 => _readyTabs.contains(index)
          ? switch (index) {
              1 => const GamesScreen(),
              2 => const WalletScreen(),
              3 => const ProfileScreen(),
              _ => const SizedBox.shrink(),
            }
          : _TabStartupPlaceholder(index: index),
      _ => const SizedBox.shrink(),
    };
  }
}

class _HomeStartupPlaceholder extends StatelessWidget {
  const _HomeStartupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TabStartupPlaceholder extends StatelessWidget {
  const _TabStartupPlaceholder({
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (index) {
      1 => 'Games',
      2 => l10n.wallet,
      3 => l10n.profile,
      _ => l10n.loading,
    };
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text('$label ${l10n.loading.toLowerCase()}'),
          ],
        ),
      ),
    );
  }
}

class _IntroRow extends StatelessWidget {
  const _IntroRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.primary.withOpacity(0.14),
          ),
          child: Icon(icon, color: AppTheme.primarySoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenIntroCopy {
  const _FullscreenIntroCopy({
    required this.title,
    required this.subtitle,
    required this.pagesTitle,
    required this.pagesBody,
    required this.videosTitle,
    required this.videosBody,
    required this.splitTitle,
    required this.splitBody,
    required this.rulesTitle,
    required this.rulesBody,
    required this.closeLabel,
  });

  final String title;
  final String subtitle;
  final String pagesTitle;
  final String pagesBody;
  final String videosTitle;
  final String videosBody;
  final String splitTitle;
  final String splitBody;
  final String rulesTitle;
  final String rulesBody;
  final String closeLabel;

  static _FullscreenIntroCopy of(BuildContext context) {
    const english = _FullscreenIntroCopy(
      title: 'Welcome to fullscreen mode',
      subtitle:
          'Swipe instead of tapping buttons. Videos, Games, Wallet and Profile are now full-screen pages.',
      pagesTitle: 'Left or right',
      pagesBody: 'Swipe sideways to move between Videos, Games, Wallet and Profile.',
      videosTitle: 'Up or down',
      videosBody:
          'Swipe up or down inside Videos to move through shorts. Switching still does not count as a watched short.',
      splitTitle: 'Games split screen',
      splitBody:
          'On larger screens you can enable split screen inside Games to keep a smaller Videos panel open.',
      rulesTitle: 'Ad rules stay the same',
      rulesBody:
          'Reward rules do not change. Shorts only count after the normal watch conditions are met.',
      closeLabel: 'Got it',
    );

    const localized = <String, _FullscreenIntroCopy>{
      'nl': _FullscreenIntroCopy(
        title: 'Welkom in fullscreen-modus',
        subtitle:
            'Swipe in plaats van op knoppen te tikken. Video’s, Games, Wallet en Profiel zijn nu fullscreen pagina’s.',
        pagesTitle: 'Links of rechts',
        pagesBody:
            'Swipe horizontaal om te wisselen tussen Video’s, Games, Wallet en Profiel.',
        videosTitle: 'Omhoog of omlaag',
        videosBody:
            'Swipe in Video’s omhoog of omlaag om door shorts te gaan. Wisselen telt nog steeds niet als bekeken short.',
        splitTitle: 'Games split screen',
        splitBody:
            'Op grotere schermen kun je in Games split screen aanzetten om ook een kleinere Video-paneel open te houden.',
        rulesTitle: 'Advertentieregels blijven gelijk',
        rulesBody:
            'De beloningsregels veranderen niet. Shorts tellen pas mee als aan de normale kijkvoorwaarden is voldaan.',
        closeLabel: 'Begrepen',
      ),
    };

    return localized[Localizations.localeOf(context).languageCode.toLowerCase()] ??
        english;
  }
}
