import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/players_are_gamers_profile.dart';
import '../../services/pag_matchmaking_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/presence_service.dart';
import 'home_screen.dart';
import 'players_are_gamers_webview_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const String _splitScreenPreferenceKey =
      'games_split_screen_enabled_v1';
  static const String _splitScreenRatioPreferenceKey =
      'games_split_screen_ratio_v1';

  final PlayersAreGamersService _service = PlayersAreGamersService();
  final PagMatchmakingService _matchmakingService = PagMatchmakingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // NOTE: Avoid loading the full online user-id set on startup (can be huge and
  // cause crashes on some devices). We only show the online count here.
  late final Stream<int> _onlineUsersCountStream =
      PresenceService.instance.watchOnlineUsersCount();
  bool _loading = true;
  bool _splitScreenEnabled = false;
  double _splitScreenRatio = 0.52;
  String? _error;

  static const List<_PagGameDefinition> _multiplayerGames = [
    _PagGameDefinition(
      'ludo',
      'Ludo',
      'https://playersaregamers.nl/games/ludo/',
    ),
    _PagGameDefinition(
      'jewel-quest',
      'Jewel Quest',
      'https://playersaregamers.nl/jewel-quest/',
    ),
    _PagGameDefinition(
      'fruit-matching',
      'Fruit Matching',
      'https://playersaregamers.nl/fruit-matching/',
    ),
    _PagGameDefinition(
      'memory-match',
      'Memory Match',
      'https://playersaregamers.nl/memory-match/',
    ),
    _PagGameDefinition(
      'tap-the-rat',
      'Tap The Rat',
      'https://playersaregamers.nl/tap-rat/',
    ),
  ];

  static const List<_PagGameDefinition> _singlePlayerGames = [
    _PagGameDefinition(
      'crazy-nurse',
      'Crazy Nurse',
      'https://playersaregamers.nl/crazy-nurse/',
    ),
    _PagGameDefinition(
      'stick-boy',
      'Stick Boy',
      'https://playersaregamers.nl/stick-boy/',
    ),
    _PagGameDefinition(
      'stone-pile',
      'Stone Pile',
      'https://playersaregamers.nl/stone-pile/',
    ),
    _PagGameDefinition(
      'space-destroyer',
      'Space Destroyer',
      'https://playersaregamers.nl/Space-Destroyer/',
    ),
    _PagGameDefinition(
      'falling-balled-man',
      'Falling Balled Man',
      'https://playersaregamers.nl/Falling-Baldman/',
    ),
    _PagGameDefinition(
      'lily-in-danger',
      'Lily in Danger',
      'https://playersaregamers.nl/lily-in-danger/',
    ),
    _PagGameDefinition(
      'subway-trainrun',
      'Subway Train Station',
      'https://playersaregamers.nl/Subway-TrainRun/',
    ),
    _PagGameDefinition(
      'bio-race',
      'Bio-Race',
      'https://playersaregamers.nl/bio-race/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSplitScreenPreference());
    // Delay the first network-heavy sync a bit to avoid first-open crashes on
    // fresh installs.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), _refresh),
    );
  }

  Future<void> _restoreSplitScreenPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _splitScreenEnabled = prefs.getBool(_splitScreenPreferenceKey) ?? false;
      _splitScreenRatio =
          (prefs.getDouble(_splitScreenRatioPreferenceKey) ?? 0.52)
              .clamp(0.28, 0.72);
    });
  }

  Future<void> _setSplitScreenEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_splitScreenPreferenceKey, value);
    if (!mounted) return;
    setState(() => _splitScreenEnabled = value);
  }

  Future<void> _setSplitScreenRatio(double value) async {
    final normalized = value.clamp(0.28, 0.72);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_splitScreenRatioPreferenceKey, normalized);
    if (!mounted) return;
    setState(() => _splitScreenRatio = normalized);
  }

  void _toggleSplitScreen() {
    unawaited(_setSplitScreenEnabled(!_splitScreenEnabled));
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await _service.ensureLinkedProfile(
        includeStats: true,
        autoCreateIfMissing: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _formatGamesError(error);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatGamesError(Object error) {
    final copy = _GamesCopy.of(context);
    final text = error.toString();
    if (text.contains('[firebase_functions/internal]') ||
        text.contains('[firebase_functions/unavailable]')) {
      return copy.syncUnavailable;
    }
    if (text.contains('[firebase_functions/not-found]') ||
        text.contains('NOT_FOUND')) {
      return copy.syncNotConfigured;
    }
    if (text.contains('[firebase_functions/already-exists]')) {
      return copy.linkExistingHint;
    }
    return text;
  }

  Future<void> _openGame([_PagGameDefinition? game]) async {
    final initialUrl = game?.targetUrl;
    final shouldPublishWaitingSignal =
        game != null && _multiplayerGames.contains(game);
    if (shouldPublishWaitingSignal) {
      try {
        await _matchmakingService.publishWaitingSignal(
          gameId: game.id,
          gameName: game.name,
          gameUrl: game.targetUrl ?? PlayersAreGamersService.dashboardUrl,
        );
      } catch (_) {}
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayersAreGamersWebViewScreen(
          service: _service,
          initialUrl: initialUrl,
          landscapeOnly: game?.landscapeOnly ?? false,
        ),
      ),
    );
    if (shouldPublishWaitingSignal) {
      await _matchmakingService.clearOwnSignal();
    }
    await _refresh();
  }

  Future<void> _openRegistrationWebsite() async {
    await launchUrl(
      Uri.parse(PlayersAreGamersService.registrationUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _showLinkDialog({required bool createMode}) async {
    final copy = _GamesCopy.of(context);
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool busy = false;
        String? dialogError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() {
                busy = true;
                dialogError = null;
              });
              try {
                if (createMode) {
                  await _service.createAndLinkAccount(
                    username: usernameController.text,
                    password: passwordController.text,
                  );
                } else {
                  await _service.linkExistingAccount(
                    username: usernameController.text,
                    password: passwordController.text,
                  );
                }
                if (!mounted) return;
                Navigator.of(context).pop(true);
              } catch (error) {
                setDialogState(() {
                  busy = false;
                  dialogError = error.toString();
                });
              }
            }

            return AlertDialog(
              title: Text(
                createMode ? copy.createPagAccount : copy.linkPagAccount,
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(labelText: copy.usernameLabel),
                      validator: (value) {
                        if ((value ?? '').trim().length < 3) {
                          return copy.minUsernameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: copy.passwordLabel),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return copy.minPasswordError;
                        }
                        return null;
                      },
                    ),
                    if (createMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        copy.currentEmailHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  child: Text(copy.cancel),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy ? copy.pleaseWait : (createMode ? copy.create : copy.link),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _refresh();
    }
  }

  Future<List<_PagCoinLeaderboardEntry>> _loadPagCoinLeaderboard(
    Set<String> onlineUserIds,
  ) async {
    if (onlineUserIds.isEmpty) return const [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final selectedUserIds = <String>{
      ...onlineUserIds,
      if (currentUid != null && currentUid.isNotEmpty) currentUid,
    };

    final futures = selectedUserIds.take(80).map((uid) async {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('integrations')
          .doc('playersAreGamers')
          .get();
      final data = snapshot.data();
      if (data == null) return null;
      final profile = PlayersAreGamersProfile.fromFirestore(data);
      if (!profile.linked) return null;
      final username = profile.username.trim().isNotEmpty
          ? profile.username.trim()
          : _fallbackLeaderboardName(profile.email, uid);
      return _PagCoinLeaderboardEntry(
        uid: uid,
        username: username,
        coins: profile.coins,
      );
    });


    final entries =
        (await Future.wait(futures)).whereType<_PagCoinLeaderboardEntry>().toList();
    entries.sort((a, b) {
      final byCoins = b.coins.compareTo(a.coins);
      if (byCoins != 0) return byCoins;
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });
    return entries.take(20).toList(growable: false);
  }

  String _fallbackLeaderboardName(String email, String uid) {
    final trimmed = email.trim();
    if (trimmed.isNotEmpty) {
      final atIndex = trimmed.indexOf('@');
      if (atIndex > 0) {
        return trimmed.substring(0, atIndex);
      }
      return trimmed;
    }
    if (uid.length >= 6) return 'player-${uid.substring(0, 6)}';
    return 'player';
  }

  @override
  Widget build(BuildContext context) {
    final copy = _GamesCopy.of(context);
    final layoutCopy = _GamesLayoutCopy.of(context);

    return StreamBuilder<PlayersAreGamersProfile?>(
      stream: _service.watchProfile(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        return StreamBuilder<int>(
          stream: _onlineUsersCountStream,
          builder: (context, onlineSnapshot) {
            final onlineCount = onlineSnapshot.data ?? 0;

            return Scaffold(
              backgroundColor: const Color(0xFF03110D),
              body: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF03110D),
                      Color(0xFF020806),
                      Color(0xFF010403),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSplitScreen =
                          _splitScreenEnabled &&
                          profile != null &&
                          profile.linked;
                      final gamesContent = _buildGamesScrollBody(
                        copy: copy,
                        layoutCopy: layoutCopy,
                        profile: profile,
                        onlineCount: onlineCount,
                      );

                      if (!showSplitScreen) {
                        return gamesContent;
                      }

                      final topFlex = (_splitScreenRatio * 1000).round();
                      final bottomFlex = ((1 - _splitScreenRatio) * 1000).round();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          children: [
                            Expanded(
                              flex: topFlex,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SplitPanelHeader(
                                    title: layoutCopy.gamesPanelTitle,
                                    body: layoutCopy.gamesPanelBody,
                                    onClose: _toggleSplitScreen,
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: PlayersAreGamersWebViewScreen(
                                      service: _service,
                                      initialUrl: PlayersAreGamersService.dashboardUrl,
                                      embeddedMode: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                final nextRatio =
                                    _splitScreenRatio +
                                    (details.delta.dy / constraints.maxHeight);
                                setState(() {
                                  _splitScreenRatio = nextRatio.clamp(0.28, 0.72);
                                });
                              },
                              onVerticalDragEnd: (_) {
                                unawaited(_setSplitScreenRatio(_splitScreenRatio));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: const Color(0x661AE47A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      layoutCopy.dragHint,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withOpacity(0.72),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: bottomFlex,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SplitPanelHeader(
                                    title: layoutCopy.splitPanelTitle,
                                    body: layoutCopy.splitPanelBody,
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: HomeScreen(
                                      isActiveTab: true,
                                      compactMode: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGamesScrollBody({
    required _GamesCopy copy,
    required _GamesLayoutCopy layoutCopy,
    required PlayersAreGamersProfile? profile,
    required int onlineCount,
  }) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _buildHero(copy),
          const SizedBox(height: 18),
          _buildSplitScreenCard(layoutCopy),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _StatusCard(
              title: copy.syncIssue,
              message: _error!,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 16),
          ],
          _buildCoinsCard(profile, copy),
          const SizedBox(height: 14),
          if (_loading && profile == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (profile == null || !profile.linked)
            _buildUnlinkedState(copy)
          else ...[
            _buildStatsGrid(profile, copy),
            const SizedBox(height: 18),
            _buildGamesCard(
              copy: copy,
              onlineCount: onlineCount,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitScreenCard(_GamesLayoutCopy copy) {
    return _NeonPanel(
      child: InkWell(
        onTap: _toggleSplitScreen,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.splitscreen_rounded, color: Color(0xFF29F08F)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _splitScreenEnabled,
                    onChanged: (value) => _setSplitScreenEnabled(value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _splitScreenEnabled ? copy.enabledBody : copy.disabledBody,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(_GamesCopy copy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF081714),
            Color(0xFF04110D),
            Color(0xFF020706),
          ],
        ),
        border: Border.all(color: const Color(0xFF12D36B).withOpacity(0.16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300FF85),
            blurRadius: 32,
            spreadRadius: -10,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.gamesTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14E278),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  copy.gamesSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF11F487).withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: const Color(0xFF081412),
                  border: Border.all(
                    color: const Color(0xFF19E27A).withOpacity(0.35),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300FF99),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  size: 52,
                  color: Color(0xFF88FFB6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsCard(
    PlayersAreGamersProfile? profile,
    _GamesCopy copy,
  ) {
    final coins = profile?.coins ?? 0;
    final progress = ((profile?.starterProgress ?? 0).clamp(0, 1)).toDouble();

    return _NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFF29F08F),
              ),
              const SizedBox(width: 10),
              Text(
                copy.pagCoinsTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' ${copy.coinsUnitLabel}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1CE47A)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile?.linked == true
                ? copy.pagCoinsDescriptionLinked
                : copy.pagCoinsDescriptionUnlinked,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlinkedState(_GamesCopy copy) {
    return _NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.prepareAccountTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.prepareAccountBody,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF14D86E),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.retryAutoStart),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _showLinkDialog(createMode: false),
            icon: const Icon(Icons.link_rounded),
            label: Text(copy.linkExistingButton),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openRegistrationWebsite,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(copy.createWebsiteButton),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    PlayersAreGamersProfile profile,
    _GamesCopy copy,
  ) {
    final stats = [
      _StatItem(
        label: copy.usernameLabel,
        value: profile.username,
        subtitle: copy.accountStatus,
        icon: Icons.person_rounded,
        iconColor: const Color(0xFF25E37E),
      ),
      _StatItem(
        label: copy.gamesPlayedLabel,
        value: '${profile.totalGamesPlayed}',
        subtitle: copy.keepPlaying,
        icon: Icons.sports_esports_rounded,
        iconColor: const Color(0xFFB56BFF),
      ),
      _StatItem(
        label: copy.coinsEarnedLabel,
        value: '${profile.totalCoinsEarned}',
        subtitle: copy.totalCoinsSubtitle,
        icon: Icons.monetization_on_rounded,
        iconColor: const Color(0xFFF5C64A),
      ),
      _StatItem(
        label: copy.winRateLabel,
        value: profile.winRate ?? '${profile.totalGamesWon}',
        subtitle: copy.winRateSubtitle,
        icon: Icons.emoji_events_rounded,
        iconColor: const Color(0xFF33A7FF),
      ),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, index) => _GamesStatCard(item: stats[index]),
    );
  }

  Widget _buildGamesCard({
    required _GamesCopy copy,
    required int onlineCount,
  }) {
    return _NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.supportedGamesTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _OnlineBadge(
                label: copy.usersOnline(onlineCount),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            copy.supportedGamesSubtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildGameSection(
            title: copy.realtimeMultiplayerTitle,
            games: _multiplayerGames,
            copy: copy,
          ),
          const SizedBox(height: 16),
          _buildGameSection(
            title: copy.singlePlayerTitle,
            games: _singlePlayerGames,
            copy: copy,
          ),
        ],
      ),
    );
  }

  Widget _buildGameSection({
    required String title,
    required List<_PagGameDefinition> games,
    required _GamesCopy copy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF1CE57A),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        for (final game in games) ...[
          _GameTile(
            game: game,
            subtitle: copy.gameDescription(game.id),
            onTap: () => _openGame(game),
            playLabel: copy.play,
          ),
          if (game != games.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // Online leaderboard temporarily disabled for stability.
}

class _GamesStatCard extends StatelessWidget {
  const _GamesStatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xCC061511),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.iconColor.withOpacity(0.16),
            ),
            child: Icon(item.icon, color: item.iconColor),
          ),
          const Spacer(),
          Text(
            item.label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: TextStyle(
              color: item.iconColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.subtitle,
    required this.onTap,
    required this.playLabel,
  });

  final _PagGameDefinition game;
  final String subtitle;
  final VoidCallback onTap;
  final String playLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xCC061511),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: _iconGradientForGame(game.id),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                _iconForGame(game.id),
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.64),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  playLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF18E477),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF18E477),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.youLabel,
    required this.coinsLabel,
    required this.onlineLabel,
  });

  final int rank;
  final _PagCoinLeaderboardEntry entry;
  final bool isCurrentUser;
  final String youLabel;
  final String coinsLabel;
  final String onlineLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isCurrentUser
            ? const Color(0x1F15E17A)
            : const Color(0xCC061511),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF19E27A).withOpacity(0.32)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B2118),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${entry.username} $youLabel' : entry.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF18E477),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      onlineLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.coins} $coinsLabel',
            style: const TextStyle(
              color: Color(0xFF1CE47A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF0A1A14),
        border: Border.all(color: const Color(0xFF18E477).withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF18E477),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonPanel extends StatelessWidget {
  const _NeonPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: const Color(0xCC05130F),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200FF88),
            blurRadius: 28,
            spreadRadius: -14,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _NeonPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFF7979)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(color: Colors.white.withOpacity(0.76)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForGame(String id) {
  return switch (id) {
    'jewel-quest' => Icons.diamond_rounded,
    'fruit-matching' => Icons.apple_rounded,
    'memory-match' => Icons.style_rounded,
    'tap-the-rat' => Icons.pest_control_rodent_rounded,
    'crazy-nurse' => Icons.local_hospital_rounded,
    'stick-boy' => Icons.directions_run_rounded,
    'stone-pile' => Icons.landscape_rounded,
    'space-destroyer' => Icons.rocket_launch_rounded,
    'falling-balled-man' => Icons.sports_basketball_rounded,
    'lily-in-danger' => Icons.local_florist_rounded,
    _ => Icons.sports_esports_rounded,
  };
}

List<Color> _iconGradientForGame(String id) {
  return switch (id) {
    'jewel-quest' => const [Color(0xFF1C7EFF), Color(0xFF60D0FF)],
    'fruit-matching' => const [Color(0xFFFF8A00), Color(0xFFFFD84E)],
    'memory-match' => const [Color(0xFF6078FF), Color(0xFFA26DFF)],
    'tap-the-rat' => const [Color(0xFF6C6C6C), Color(0xFFB0B0B0)],
    'crazy-nurse' => const [Color(0xFF00B067), Color(0xFF39F598)],
    'stick-boy' => const [Color(0xFFFF4E88), Color(0xFFFFA166)],
    'stone-pile' => const [Color(0xFF7E6B5A), Color(0xFFD5B489)],
    'space-destroyer' => const [Color(0xFF0D5EFF), Color(0xFF4CE9FF)],
    'falling-balled-man' => const [Color(0xFFFF9A00), Color(0xFFFFCF55)],
    'lily-in-danger' => const [Color(0xFF00A467), Color(0xFF54F29E)],
    _ => const [Color(0xFF087B4F), Color(0xFF23F190)],
  };
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
}

class _PagCoinLeaderboardEntry {
  const _PagCoinLeaderboardEntry({
    required this.uid,
    required this.username,
    required this.coins,
  });

  final String uid;
  final String username;
  final int coins;
}

class _SplitPanelHeader extends StatelessWidget {
  const _SplitPanelHeader({
    required this.title,
    required this.body,
    this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0x331AE47A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onClose,
              tooltip: 'Close split screen',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _GamesLayoutCopy {
  const _GamesLayoutCopy({
    required this.title,
    required this.enabledBody,
    required this.disabledBody,
    required this.dragHint,
    required this.gamesPanelTitle,
    required this.gamesPanelBody,
    required this.splitPanelTitle,
    required this.splitPanelBody,
  });

  final String title;
  final String enabledBody;
  final String disabledBody;
  final String dragHint;
  final String gamesPanelTitle;
  final String gamesPanelBody;
  final String splitPanelTitle;
  final String splitPanelBody;

  static _GamesLayoutCopy of(BuildContext context) {
    const english = _GamesLayoutCopy(
      title: 'Split screen',
      enabledBody:
          'Split screen is on. You can see Games and Videos at the same time.',
      disabledBody:
          'Turn this on if you want two live panels at once: Games and Videos in the same screen.',
      dragHint: 'Drag the middle bar',
      gamesPanelTitle: 'Games stay open',
      gamesPanelBody:
          'This panel keeps the game website open while the video panel stays visible below.',
      splitPanelTitle: 'Videos stay live',
      splitPanelBody:
          'Watch shorts in the second panel while you play. Reward and ad rules stay the same.',
    );

    const localized = <String, _GamesLayoutCopy>{
      'nl': _GamesLayoutCopy(
        title: 'Split screen',
        enabledBody:
            'Split screen staat aan. Je ziet Games en Video’s nu tegelijk.',
        disabledBody:
            'Zet dit aan als je twee live panelen tegelijk wilt: Games en Video’s op hetzelfde scherm.',
        dragHint: 'Sleep de balk in het midden',
        gamesPanelTitle: 'Games blijft open',
        gamesPanelBody:
            'Dit paneel houdt de gamesite open terwijl het videopaneel onderaan zichtbaar blijft.',
        splitPanelTitle: 'Video’s blijven live',
        splitPanelBody:
            'Bekijk shorts in het tweede paneel terwijl je speelt. Belonings- en advertentieregels blijven hetzelfde.',
      ),
      'hi': _GamesLayoutCopy(
        title: 'स्प्लिट स्क्रीन',
        enabledBody:
            'स्प्लिट स्क्रीन चालू है। अब आप Games और Videos को एक साथ देख सकते हैं।',
        disabledBody:
            'अगर आप एक साथ दो live panel चाहते हैं, तो इसे चालू करें: Games और Videos एक ही स्क्रीन पर।',
        dragHint: 'बीच की पट्टी खींचें',
        gamesPanelTitle: 'Games खुला रहेगा',
        gamesPanelBody:
            'यह panel game website को खुला रखता है, जबकि नीचे video panel दिखाई देता रहता है।',
        splitPanelTitle: 'वीडियो चलते रहेंगे',
        splitPanelBody:
            'खेलते समय दूसरे panel में shorts देखें। रिवॉर्ड और ad नियम वही रहेंगे।',
      ),
      'de': _GamesLayoutCopy(
        title: 'Geteilter Bildschirm',
        enabledBody:
            'Der geteilte Bildschirm ist aktiv. Du kannst Games und Videos gleichzeitig sehen.',
        disabledBody:
            'Aktiviere das, wenn du zwei Live-Bereiche gleichzeitig willst: Games und Videos auf einem Bildschirm.',
        dragHint: 'Ziehe die mittlere Leiste',
        gamesPanelTitle: 'Games bleibt geöffnet',
        gamesPanelBody:
            'Dieses Panel hält die Spiele-Website offen, während das Video-Panel darunter sichtbar bleibt.',
        splitPanelTitle: 'Videos laufen weiter',
        splitPanelBody:
            'Sieh Shorts im zweiten Bereich, während du spielst. Belohnungs- und Werberegeln bleiben gleich.',
      ),
      'es': _GamesLayoutCopy(
        title: 'Pantalla dividida',
        enabledBody:
            'La pantalla dividida está activa. Ahora puedes ver Games y Videos al mismo tiempo.',
        disabledBody:
            'Activa esto si quieres dos paneles en vivo al mismo tiempo: Games y Videos en la misma pantalla.',
        dragHint: 'Arrastra la barra central',
        gamesPanelTitle: 'Games sigue abierto',
        gamesPanelBody:
            'Este panel mantiene abierto el sitio del juego mientras el panel de videos sigue visible abajo.',
        splitPanelTitle: 'Los videos siguen activos',
        splitPanelBody:
            'Mira shorts en el segundo panel mientras juegas. Las reglas de anuncios y recompensas siguen igual.',
      ),
      'fr': _GamesLayoutCopy(
        title: 'Écran partagé',
        enabledBody:
            'L’écran partagé est activé. Tu peux maintenant voir Games et Videos en même temps.',
        disabledBody:
            'Active cette option si tu veux deux panneaux en direct en même temps : Games et Videos sur le même écran.',
        dragHint: 'Fais glisser la barre centrale',
        gamesPanelTitle: 'Games reste ouvert',
        gamesPanelBody:
            'Ce panneau garde le site de jeu ouvert pendant que le panneau vidéo reste visible en dessous.',
        splitPanelTitle: 'Les vidéos restent actives',
        splitPanelBody:
            'Regarde des shorts dans le second panneau pendant que tu joues. Les règles de récompense et de pub restent les mêmes.',
      ),
      'ru': _GamesLayoutCopy(
        title: 'Разделённый экран',
        enabledBody:
            'Разделённый экран включён. Теперь вы можете видеть Games и Videos одновременно.',
        disabledBody:
            'Включите это, если хотите видеть две живые панели одновременно: Games и Videos на одном экране.',
        dragHint: 'Перетащите центральную полоску',
        gamesPanelTitle: 'Games остаётся открытым',
        gamesPanelBody:
            'Эта панель держит сайт игры открытым, пока видеопанель остаётся видимой внизу.',
        splitPanelTitle: 'Видео продолжают идти',
        splitPanelBody:
            'Смотрите shorts во второй панели во время игры. Правила рекламы и наград остаются теми же.',
      ),
      'el': _GamesLayoutCopy(
        title: 'Διαχωρισμένη οθόνη',
        enabledBody:
            'Η διαχωρισμένη οθόνη είναι ενεργή. Τώρα μπορείς να βλέπεις Games και Videos ταυτόχρονα.',
        disabledBody:
            'Ενεργοποίησέ το αν θέλεις δύο ζωντανά πάνελ ταυτόχρονα: Games και Videos στην ίδια οθόνη.',
        dragHint: 'Σύρε τη μεσαία μπάρα',
        gamesPanelTitle: 'Το Games μένει ανοιχτό',
        gamesPanelBody:
            'Αυτό το πάνελ κρατά ανοιχτό το site του παιχνιδιού ενώ το panel βίντεο μένει ορατό πιο κάτω.',
        splitPanelTitle: 'Τα βίντεο μένουν ενεργά',
        splitPanelBody:
            'Δες shorts στο δεύτερο πάνελ ενώ παίζεις. Οι κανόνες ανταμοιβής και διαφημίσεων μένουν ίδιοι.',
      ),
      'pt': _GamesLayoutCopy(
        title: 'Tela dividida',
        enabledBody:
            'A tela dividida está ativa. Agora você pode ver Games e Videos ao mesmo tempo.',
        disabledBody:
            'Ative isto se quiser dois painéis ao vivo ao mesmo tempo: Games e Videos na mesma tela.',
        dragHint: 'Arraste a barra do meio',
        gamesPanelTitle: 'Games fica aberto',
        gamesPanelBody:
            'Este painel mantém o site do jogo aberto enquanto o painel de vídeos continua visível embaixo.',
        splitPanelTitle: 'Os vídeos continuam ativos',
        splitPanelBody:
            'Assista aos shorts no segundo painel enquanto joga. As regras de anúncios e recompensas continuam iguais.',
      ),
      'it': _GamesLayoutCopy(
        title: 'Schermo diviso',
        enabledBody:
            'Lo schermo diviso è attivo. Ora puoi vedere Games e Videos nello stesso momento.',
        disabledBody:
            'Attiva questa opzione se vuoi due pannelli live insieme: Games e Videos nella stessa schermata.',
        dragHint: 'Trascina la barra centrale',
        gamesPanelTitle: 'Games resta aperto',
        gamesPanelBody:
            'Questo pannello mantiene aperto il sito del gioco mentre il pannello video resta visibile sotto.',
        splitPanelTitle: 'I video restano attivi',
        splitPanelBody:
            'Guarda gli shorts nel secondo pannello mentre giochi. Le regole di annunci e ricompense restano uguali.',
      ),
      'tr': _GamesLayoutCopy(
        title: 'Bölünmüş ekran',
        enabledBody:
            'Bölünmüş ekran açık. Artık Games ve Videos’u aynı anda görebilirsin.',
        disabledBody:
            'Aynı anda iki canlı panel istiyorsan bunu aç: Games ve Videos aynı ekranda.',
        dragHint: 'Ortadaki çubuğu sürükle',
        gamesPanelTitle: 'Games açık kalır',
        gamesPanelBody:
            'Bu panel oyun sitesini açık tutar, alttaki video paneli de görünür kalır.',
        splitPanelTitle: 'Videolar canlı kalır',
        splitPanelBody:
            'Oyun oynarken ikinci panelde shorts izle. Ödül ve reklam kuralları aynı kalır.',
      ),
      'ar': _GamesLayoutCopy(
        title: 'شاشة مقسمة',
        enabledBody:
            'الشاشة المقسمة مفعلة. يمكنك الآن رؤية Games وVideos في الوقت نفسه.',
        disabledBody:
            'فعّل هذا إذا أردت لوحتين مباشرتين معًا: Games وVideos في الشاشة نفسها.',
        dragHint: 'اسحب الشريط الأوسط',
        gamesPanelTitle: 'يبقى Games مفتوحًا',
        gamesPanelBody:
            'هذه اللوحة تُبقي موقع اللعبة مفتوحًا بينما تبقى لوحة الفيديو ظاهرة في الأسفل.',
        splitPanelTitle: 'الفيديوهات تبقى مستمرة',
        splitPanelBody:
            'شاهد المقاطع القصيرة في اللوحة الثانية أثناء اللعب. تبقى قواعد الإعلانات والمكافآت كما هي.',
      ),
      'bn': _GamesLayoutCopy(
        title: 'স্প্লিট স্ক্রিন',
        enabledBody:
            'স্প্লিট স্ক্রিন চালু আছে। এখন তুমি Games আর Videos একসাথে দেখতে পারবে।',
        disabledBody:
            'একসাথে দুইটা live panel চাইলে এটা চালু করুন: Games আর Videos একই স্ক্রিনে।',
        dragHint: 'মাঝের বার টানুন',
        gamesPanelTitle: 'Games খোলা থাকে',
        gamesPanelBody:
            'এই panel game website খোলা রাখে, আর নিচের video panel-ও দেখা যায়।',
        splitPanelTitle: 'ভিডিও চলতেই থাকবে',
        splitPanelBody:
            'গেম খেলতে খেলতে দ্বিতীয় panel-এ shorts দেখুন। রিওয়ার্ড আর বিজ্ঞাপনের নিয়ম একই থাকবে।',
      ),
      'ta': _GamesLayoutCopy(
        title: 'பிரிக்கப்பட்ட திரை',
        enabledBody:
            'பிரிக்கப்பட்ட திரை இயக்கப்பட்டுள்ளது. இப்போது Games மற்றும் Videos இரண்டையும் ஒரே நேரத்தில் பார்க்கலாம்.',
        disabledBody:
            'ஒரே நேரத்தில் இரண்டு live panel வேண்டும் என்றால் இதை இயக்குங்கள்: Games மற்றும் Videos ஒரே திரையில்.',
        dragHint: 'நடுத்தர பட்டையை இழுக்கவும்',
        gamesPanelTitle: 'Games திறந்தே இருக்கும்',
        gamesPanelBody:
            'இந்த panel game website-ஐ திறந்தே வைத்திருக்கும்; கீழே video panel-மும் தெரியும்.',
        splitPanelTitle: 'வீடியோக்கள் தொடர்ந்து இயங்கும்',
        splitPanelBody:
            'நீங்கள் விளையாடும் போது இரண்டாவது panel-ல் shorts பாருங்கள். பரிசு மற்றும் விளம்பர விதிகள் அதேபடி இருக்கும்.',
      ),
      'te': _GamesLayoutCopy(
        title: 'స్ప్లిట్ స్క్రీన్',
        enabledBody:
            'స్ప్లిట్ స్క్రీన్ ఆన్‌లో ఉంది. ఇప్పుడు మీరు Games మరియు Videos రెండింటినీ ఒకేసారి చూడవచ్చు.',
        disabledBody:
            'ఒకేసారి రెండు live panel‌లు కావాలంటే దీన్ని ఆన్ చేయండి: Games మరియు Videos ఒకే స్క్రీన్‌లో.',
        dragHint: 'మధ్య బార్‌ను లాగండి',
        gamesPanelTitle: 'Games తెరిచి ఉంటుంది',
        gamesPanelBody:
            'ఈ panel game website ను తెరిచి ఉంచుతుంది, కింద video panel కూడా కనిపిస్తూనే ఉంటుంది.',
        splitPanelTitle: 'వీడియోలు కొనసాగుతాయి',
        splitPanelBody:
            'ఆడుతూ రెండో panel‌లో shorts చూడండి. రివార్డ్ మరియు ప్రకటన నియమాలు అలాగే ఉంటాయి.',
      ),
    };

    return localized[Localizations.localeOf(context).languageCode.toLowerCase()] ??
        english;
  }
}

class _GamesCopy {
  const _GamesCopy._({
    required this.gamesTitle,
    required this.gamesSubtitle,
    required this.syncIssue,
    required this.syncUnavailable,
    required this.syncNotConfigured,
    required this.linkExistingHint,
    required this.pagCoinsTitle,
    required this.coinsUnitLabel,
    required this.pagCoinsDescriptionLinked,
    required this.pagCoinsDescriptionUnlinked,
    required this.prepareAccountTitle,
    required this.prepareAccountBody,
    required this.retryAutoStart,
    required this.linkExistingButton,
    required this.createWebsiteButton,
    required this.usernameLabel,
    required this.gamesPlayedLabel,
    required this.coinsEarnedLabel,
    required this.winRateLabel,
    required this.accountStatus,
    required this.keepPlaying,
    required this.totalCoinsSubtitle,
    required this.winRateSubtitle,
    required this.supportedGamesTitle,
    required this.supportedGamesSubtitle,
    required this.realtimeMultiplayerTitle,
    required this.singlePlayerTitle,
    required this.play,
    required this.pagLeaderboardTitle,
    required this.pagLeaderboardSubtitle,
    required this.pagLeaderboardEmpty,
    required this.youLabel,
    required this.onlineLabel,
    required this.createPagAccount,
    required this.linkPagAccount,
    required this.passwordLabel,
    required this.minUsernameError,
    required this.minPasswordError,
    required this.currentEmailHint,
    required this.cancel,
    required this.pleaseWait,
    required this.create,
    required this.link,
    required this.gameDescriptions,
  });

  final String gamesTitle;
  final String gamesSubtitle;
  final String syncIssue;
  final String syncUnavailable;
  final String syncNotConfigured;
  final String linkExistingHint;
  final String pagCoinsTitle;
  final String coinsUnitLabel;
  final String pagCoinsDescriptionLinked;
  final String pagCoinsDescriptionUnlinked;
  final String prepareAccountTitle;
  final String prepareAccountBody;
  final String retryAutoStart;
  final String linkExistingButton;
  final String createWebsiteButton;
  final String usernameLabel;
  final String gamesPlayedLabel;
  final String coinsEarnedLabel;
  final String winRateLabel;
  final String accountStatus;
  final String keepPlaying;
  final String totalCoinsSubtitle;
  final String winRateSubtitle;
  final String supportedGamesTitle;
  final String supportedGamesSubtitle;
  final String realtimeMultiplayerTitle;
  final String singlePlayerTitle;
  final String play;
  final String pagLeaderboardTitle;
  final String pagLeaderboardSubtitle;
  final String pagLeaderboardEmpty;
  final String youLabel;
  final String onlineLabel;
  final String createPagAccount;
  final String linkPagAccount;
  final String passwordLabel;
  final String minUsernameError;
  final String minPasswordError;
  final String currentEmailHint;
  final String cancel;
  final String pleaseWait;
  final String create;
  final String link;
  final Map<String, String> gameDescriptions;

  String usersOnline(int count) => '$count $onlineLabel';
  String gameDescription(String id) => gameDescriptions[id] ?? id;

  _GamesCopy copyWith({
    String? gamesTitle,
    String? gamesSubtitle,
    String? supportedGamesTitle,
    String? supportedGamesSubtitle,
    String? realtimeMultiplayerTitle,
    String? singlePlayerTitle,
    String? play,
    String? pagLeaderboardTitle,
    String? pagLeaderboardSubtitle,
    String? pagLeaderboardEmpty,
    String? youLabel,
    String? onlineLabel,
    Map<String, String>? gameDescriptions,
  }) {
    return _GamesCopy._(
      gamesTitle: gamesTitle ?? this.gamesTitle,
      gamesSubtitle: gamesSubtitle ?? this.gamesSubtitle,
      syncIssue: syncIssue,
      syncUnavailable: syncUnavailable,
      syncNotConfigured: syncNotConfigured,
      linkExistingHint: linkExistingHint,
      pagCoinsTitle: pagCoinsTitle,
      coinsUnitLabel: coinsUnitLabel,
      pagCoinsDescriptionLinked: pagCoinsDescriptionLinked,
      pagCoinsDescriptionUnlinked: pagCoinsDescriptionUnlinked,
      prepareAccountTitle: prepareAccountTitle,
      prepareAccountBody: prepareAccountBody,
      retryAutoStart: retryAutoStart,
      linkExistingButton: linkExistingButton,
      createWebsiteButton: createWebsiteButton,
      usernameLabel: usernameLabel,
      gamesPlayedLabel: gamesPlayedLabel,
      coinsEarnedLabel: coinsEarnedLabel,
      winRateLabel: winRateLabel,
      accountStatus: accountStatus,
      keepPlaying: keepPlaying,
      totalCoinsSubtitle: totalCoinsSubtitle,
      winRateSubtitle: winRateSubtitle,
      supportedGamesTitle: supportedGamesTitle ?? this.supportedGamesTitle,
      supportedGamesSubtitle:
          supportedGamesSubtitle ?? this.supportedGamesSubtitle,
      realtimeMultiplayerTitle:
          realtimeMultiplayerTitle ?? this.realtimeMultiplayerTitle,
      singlePlayerTitle: singlePlayerTitle ?? this.singlePlayerTitle,
      play: play ?? this.play,
      pagLeaderboardTitle: pagLeaderboardTitle ?? this.pagLeaderboardTitle,
      pagLeaderboardSubtitle:
          pagLeaderboardSubtitle ?? this.pagLeaderboardSubtitle,
      pagLeaderboardEmpty: pagLeaderboardEmpty ?? this.pagLeaderboardEmpty,
      youLabel: youLabel ?? this.youLabel,
      onlineLabel: onlineLabel ?? this.onlineLabel,
      createPagAccount: createPagAccount,
      linkPagAccount: linkPagAccount,
      passwordLabel: passwordLabel,
      minUsernameError: minUsernameError,
      minPasswordError: minPasswordError,
      currentEmailHint: currentEmailHint,
      cancel: cancel,
      pleaseWait: pleaseWait,
      create: create,
      link: link,
      gameDescriptions: gameDescriptions ?? this.gameDescriptions,
    );
  }

  static const Map<String, Map<String, String>> _localizedSectionValues = {
    'de': {
      'gamesTitle': 'Spiele',
      'gamesSubtitle':
          'Spiele Spiele, verdiene Coins und klettere im Leaderboard höher.',
      'supportedGamesTitle': 'Spiele',
      'supportedGamesSubtitle':
          'Nur die ausgewählten Spiele unten sind live in Videomoney und öffnen direkt in der App.',
      'realtimeMultiplayerTitle': 'Echtzeit-Mehrspieler',
      'singlePlayerTitle': 'Einzelspieler',
      'play': 'Spielen',
      'pagLeaderboardTitle': 'PAG-Coin-Leaderboard',
      'pagLeaderboardSubtitle':
          'Online-Videomoney-Nutzer mit verknüpftem PlayersAreGamers-Konto, sortiert nach Coins.',
      'pagLeaderboardEmpty':
          'Noch keine Online-Nutzer mit einem PAG-Konto gefunden.',
      'youLabel': '(du)',
      'onlineLabel': 'online',
    },
    'es': {
      'gamesTitle': 'Juegos',
      'gamesSubtitle':
          'Juega, gana coins y sube más alto en la clasificación.',
      'supportedGamesTitle': 'Juegos',
      'supportedGamesSubtitle':
          'Solo los juegos seleccionados a continuación están activos en Videomoney y se abren directamente en la app.',
      'realtimeMultiplayerTitle': 'Multijugador en tiempo real',
      'singlePlayerTitle': 'Un jugador',
      'play': 'Jugar',
      'pagLeaderboardTitle': 'Clasificación de coins PAG',
      'pagLeaderboardSubtitle':
          'Usuarios online de Videomoney con una cuenta de PlayersAreGamers vinculada, ordenados por coins.',
      'pagLeaderboardEmpty':
          'Todavía no se encontraron usuarios online con una cuenta PAG.',
      'youLabel': '(tú)',
      'onlineLabel': 'en línea',
    },
    'fr': {
      'gamesTitle': 'Jeux',
      'gamesSubtitle':
          'Jouez, gagnez des coins et grimpez dans le classement.',
      'supportedGamesTitle': 'Jeux',
      'supportedGamesSubtitle':
          'Seuls les jeux sélectionnés ci-dessous sont actifs dans Videomoney et s’ouvrent directement dans l’application.',
      'realtimeMultiplayerTitle': 'Multijoueur en temps réel',
      'singlePlayerTitle': 'Solo',
      'play': 'Jouer',
      'pagLeaderboardTitle': 'Classement des coins PAG',
      'pagLeaderboardSubtitle':
          'Utilisateurs VideoMoney en ligne avec un compte PlayersAreGamers lié, classés par coins.',
      'pagLeaderboardEmpty':
          'Aucun utilisateur en ligne avec un compte PAG pour le moment.',
      'youLabel': '(vous)',
      'onlineLabel': 'en ligne',
    },
    'ru': {
      'gamesTitle': 'Игры',
      'gamesSubtitle':
          'Играйте, зарабатывайте coins и поднимайтесь выше в таблице лидеров.',
      'supportedGamesTitle': 'Игры',
      'supportedGamesSubtitle':
          'Только выбранные ниже игры уже доступны в Videomoney и открываются прямо в приложении.',
      'realtimeMultiplayerTitle': 'Мультиплеер в реальном времени',
      'singlePlayerTitle': 'Одиночная игра',
      'play': 'Играть',
      'pagLeaderboardTitle': 'Таблица coins PAG',
      'pagLeaderboardSubtitle':
          'Пользователи Videomoney онлайн с привязанным аккаунтом PlayersAreGamers, отсортированные по coins.',
      'pagLeaderboardEmpty':
          'Пока не найдено пользователей онлайн с аккаунтом PAG.',
      'youLabel': '(вы)',
      'onlineLabel': 'онлайн',
    },
    'el': {
      'gamesTitle': 'Παιχνίδια',
      'gamesSubtitle':
          'Παίξε παιχνίδια, κέρδισε coins και ανέβα πιο ψηλά στον πίνακα.',
      'supportedGamesTitle': 'Παιχνίδια',
      'supportedGamesSubtitle':
          'Μόνο τα επιλεγμένα παιχνίδια παρακάτω είναι ήδη live στο Videomoney και ανοίγουν απευθείας στην εφαρμογή.',
      'realtimeMultiplayerTitle': 'Multiplayer σε πραγματικό χρόνο',
      'singlePlayerTitle': 'Μονοπαίκτης',
      'play': 'Παίξε',
      'pagLeaderboardTitle': 'Κατάταξη coins PAG',
      'pagLeaderboardSubtitle':
          'Χρήστες του Videomoney online με συνδεδεμένο λογαριασμό PlayersAreGamers, ταξινομημένοι ανά coins.',
      'pagLeaderboardEmpty':
          'Δεν βρέθηκαν ακόμη online χρήστες με λογαριασμό PAG.',
      'youLabel': '(εσύ)',
      'onlineLabel': 'online',
    },
    'hi': {
      'gamesTitle': 'गेम्स',
      'gamesSubtitle':
          'गेम खेलें, coins कमाएँ और लीडरबोर्ड में ऊपर चढ़ें।',
      'supportedGamesTitle': 'गेम्स',
      'supportedGamesSubtitle':
          'नीचे चुने गए गेम ही अभी Videomoney में लाइव हैं और सीधे ऐप में खुलते हैं।',
      'realtimeMultiplayerTitle': 'रियल-टाइम मल्टीप्लेयर',
      'singlePlayerTitle': 'सिंगल प्लेयर',
      'play': 'खेलें',
      'pagLeaderboardTitle': 'PAG coin लीडरबोर्ड',
      'pagLeaderboardSubtitle':
          'लिंक किए गए PlayersAreGamers खाते वाले ऑनलाइन Videomoney उपयोगकर्ता, coins के अनुसार क्रमबद्ध।',
      'pagLeaderboardEmpty':
          'अभी तक PAG खाते वाले कोई ऑनलाइन उपयोगकर्ता नहीं मिले।',
      'youLabel': '(आप)',
      'onlineLabel': 'ऑनलाइन',
    },
    'pt': {
      'gamesTitle': 'Jogos',
      'gamesSubtitle':
          'Jogue, ganhe coins e suba mais alto no ranking.',
      'supportedGamesTitle': 'Jogos',
      'supportedGamesSubtitle':
          'Apenas os jogos selecionados abaixo estão ativos no Videomoney e abrem diretamente na app.',
      'realtimeMultiplayerTitle': 'Multijogador em tempo real',
      'singlePlayerTitle': 'Um jogador',
      'play': 'Jogar',
      'pagLeaderboardTitle': 'Leaderboard de coins PAG',
      'pagLeaderboardSubtitle':
          'Utilizadores online do Videomoney com conta PlayersAreGamers ligada, ordenados por coins.',
      'pagLeaderboardEmpty':
          'Ainda não foram encontrados utilizadores online com conta PAG.',
      'youLabel': '(você)',
      'onlineLabel': 'online',
    },
    'it': {
      'gamesTitle': 'Giochi',
      'gamesSubtitle':
          'Gioca, guadagna coins e sali più in alto nella classifica.',
      'supportedGamesTitle': 'Giochi',
      'supportedGamesSubtitle':
          'Solo i giochi selezionati qui sotto sono live in Videomoney e si aprono direttamente nell’app.',
      'realtimeMultiplayerTitle': 'Multigiocatore in tempo reale',
      'singlePlayerTitle': 'Giocatore singolo',
      'play': 'Gioca',
      'pagLeaderboardTitle': 'Classifica coins PAG',
      'pagLeaderboardSubtitle':
          'Utenti Videomoney online con un account PlayersAreGamers collegato, ordinati per coins.',
      'pagLeaderboardEmpty':
          'Nessun utente online con un account PAG trovato finora.',
      'youLabel': '(tu)',
      'onlineLabel': 'online',
    },
    'tr': {
      'gamesTitle': 'Oyunlar',
      'gamesSubtitle':
          'Oyun oyna, coins kazan ve sıralamada daha yukarı çık.',
      'supportedGamesTitle': 'Oyunlar',
      'supportedGamesSubtitle':
          'Aşağıdaki seçili oyunlar şu anda Videomoney içinde canlıdır ve doğrudan uygulamada açılır.',
      'realtimeMultiplayerTitle': 'Gerçek zamanlı çok oyunculu',
      'singlePlayerTitle': 'Tek oyunculu',
      'play': 'Oyna',
      'pagLeaderboardTitle': 'PAG coin sıralaması',
      'pagLeaderboardSubtitle':
          'Bağlı PlayersAreGamers hesabı olan çevrimiçi Videomoney kullanıcıları, coins sayısına göre sıralanır.',
      'pagLeaderboardEmpty':
          'Henüz PAG hesabı olan çevrimiçi kullanıcı bulunamadı.',
      'youLabel': '(sen)',
      'onlineLabel': 'çevrimiçi',
    },
    'ar': {
      'gamesTitle': 'الألعاب',
      'gamesSubtitle':
          'العب الألعاب، اربح coins واصعد أعلى في لوحة الصدارة.',
      'supportedGamesTitle': 'الألعاب',
      'supportedGamesSubtitle':
          'فقط الألعاب المحددة أدناه تعمل الآن داخل Videomoney وتفتح مباشرة داخل التطبيق.',
      'realtimeMultiplayerTitle': 'متعدد اللاعبين في الوقت الحقيقي',
      'singlePlayerTitle': 'لاعب واحد',
      'play': 'العب',
      'pagLeaderboardTitle': 'لوحة صدارة PAG coins',
      'pagLeaderboardSubtitle':
          'مستخدمو Videomoney المتصلون مع حساب PlayersAreGamers مرتبط، مرتبين حسب coins.',
      'pagLeaderboardEmpty':
          'لم يتم العثور بعد على مستخدمين متصلين لديهم حساب PAG.',
      'youLabel': '(أنت)',
      'onlineLabel': 'متصل',
    },
    'bn': {
      'gamesTitle': 'গেমস',
      'gamesSubtitle':
          'গেম খেলুন, coins আয় করুন এবং লিডারবোর্ডে আরও উপরে উঠুন।',
      'supportedGamesTitle': 'গেমস',
      'supportedGamesSubtitle':
          'নিচের নির্বাচিত গেমগুলোই এখন Videomoney-তে লাইভ এবং সরাসরি অ্যাপে খোলে।',
      'realtimeMultiplayerTitle': 'রিয়েল-টাইম মাল্টিপ্লেয়ার',
      'singlePlayerTitle': 'সিঙ্গেল প্লেয়ার',
      'play': 'খেলুন',
      'pagLeaderboardTitle': 'PAG coin লিডারবোর্ড',
      'pagLeaderboardSubtitle':
          'লিংক করা PlayersAreGamers অ্যাকাউন্টসহ অনলাইন Videomoney ব্যবহারকারীরা, coins অনুযায়ী সাজানো।',
      'pagLeaderboardEmpty':
          'এখনও কোনো অনলাইন PAG অ্যাকাউন্ট ব্যবহারকারী পাওয়া যায়নি।',
      'youLabel': '(আপনি)',
      'onlineLabel': 'অনলাইন',
    },
    'ta': {
      'gamesTitle': 'விளையாட்டுகள்',
      'gamesSubtitle':
          'விளையாடு, coins சம்பாதி, லீடர்போர்டில் மேலே ஏறு.',
      'supportedGamesTitle': 'விளையாட்டுகள்',
      'supportedGamesSubtitle':
          'கீழே உள்ள தேர்ந்தெடுக்கப்பட்ட விளையாட்டுகளே இப்போது Videomoney-ல் live ஆக உள்ளன மற்றும் நேராக app-ல் திறக்கின்றன.',
      'realtimeMultiplayerTitle': 'நேரடி மல்டிப்ளேயர்',
      'singlePlayerTitle': 'ஒற்றை வீரர்',
      'play': 'விளையாடு',
      'pagLeaderboardTitle': 'PAG coin லீடர்போர்டு',
      'pagLeaderboardSubtitle':
          'PlayersAreGamers கணக்குடன் இணைக்கப்பட்ட ஆன்லைன் Videomoney பயனர்கள், coins அடிப்படையில் வரிசைப்படுத்தப்பட்டுள்ளனர்.',
      'pagLeaderboardEmpty':
          'இன்னும் PAG கணக்குடன் ஆன்லைன் பயனர்கள் எவரும் இல்லை.',
      'youLabel': '(நீங்கள்)',
      'onlineLabel': 'ஆன்லைன்',
    },
    'te': {
      'gamesTitle': 'గేమ్స్',
      'gamesSubtitle':
          'గేమ్స్ ఆడి, coins సంపాదించి, లీడర్‌బోర్డ్‌లో పైకి ఎక్కండి.',
      'supportedGamesTitle': 'గేమ్స్',
      'supportedGamesSubtitle':
          'కింద ఉన్న ఎంపిక చేసిన గేమ్స్ మాత్రమే ఇప్పుడు Videomoney లో live గా ఉన్నాయి మరియు నేరుగా app లో తెరుచుకుంటాయి.',
      'realtimeMultiplayerTitle': 'రియల్-టైమ్ మల్టీప్లేయర్',
      'singlePlayerTitle': 'సింగిల్ ప్లేయర్',
      'play': 'ఆడు',
      'pagLeaderboardTitle': 'PAG coin లీడర్‌బోర్డ్',
      'pagLeaderboardSubtitle':
          'లింక్ చేసిన PlayersAreGamers ఖాతాతో ఉన్న ఆన్‌లైన్ Videomoney వినియోగదారులు, coins ఆధారంగా ర్యాంక్ చేయబడ్డారు.',
      'pagLeaderboardEmpty':
          'ఇంకా PAG ఖాతాతో ఆన్‌లైన్ వినియోగదారులు లేరు.',
      'youLabel': '(మీరు)',
      'onlineLabel': 'ఆన్‌లైన్',
    },
  };

  static const Map<String, Map<String, String>> _localizedGameDescriptions = {
    'de': {
      'ludo': '4-Spieler-Multiplayer mit Raum beitreten, Raum erstellen und Schnellspiel.',
      'jewel-quest': 'Kombiniere Edelsteine und baue die höchste Combo auf.',
      'fruit-matching': 'Kombiniere 3 oder mehr Früchte so schnell wie möglich.',
      'memory-match': 'Trainiere dein Gedächtnis und deinen Fokus mit schnellen Paaren.',
      'tap-the-rat': 'Tippe so schnell wie möglich und besiege alle.',
      'crazy-nurse': 'Überlebe das Chaos und halte so lange wie möglich durch.',
      'stick-boy': 'Renne, springe und weiche allem auf deinem Weg aus.',
      'stone-pile': 'Stapele klug und halte den Turm stabil.',
      'space-destroyer': 'Schieße dich durch einen schnellen Weltraumlauf.',
      'falling-balled-man': 'Behalte die Kontrolle, während alles herunterfällt.',
      'lily-in-danger': 'Beschütze Lily und überlebe gefährliche Level.',
      'subway-trainrun': 'Renne durch die Station und weiche allem in vollem Tempo aus.',
      'bio-race': 'Rase durch die Bio-Strecke und teste die eigene Game-over-Seite.',
    },
    'es': {
      'ludo': 'Juego multijugador de 4 jugadores con unirse a sala, crear sala y partida rápida.',
      'jewel-quest': 'Combina gemas y consigue la mejor racha.',
      'fruit-matching': 'Combina 3 o más frutas lo más rápido posible.',
      'memory-match': 'Entrena tu memoria y concentración con parejas rápidas.',
      'tap-the-rat': 'Toca lo más rápido posible y vence a todos.',
      'crazy-nurse': 'Sobrevive al caos y aguanta todo lo que puedas.',
      'stick-boy': 'Corre, salta y esquiva todo en tu camino.',
      'stone-pile': 'Apila con cabeza y mantén estable la torre.',
      'space-destroyer': 'Dispara en una carrera espacial rápida.',
      'falling-balled-man': 'Mantén el control mientras todo cae a tu alrededor.',
      'lily-in-danger': 'Protege a Lily y sobrevive a niveles peligrosos.',
      'subway-trainrun': 'Corre por la estación y esquiva todo a toda velocidad.',
      'bio-race': 'Corre por la pista bio y prueba su propia pantalla de game over.',
    },
    'fr': {
      'ludo': 'Jeu multijoueur à 4 joueurs avec rejoindre une salle, créer une salle et partie rapide.',
      'jewel-quest': 'Associez les gemmes et créez le meilleur combo.',
      'fruit-matching': 'Associez 3 fruits ou plus aussi vite que possible.',
      'memory-match': 'Entraînez votre mémoire et votre concentration avec des paires rapides.',
      'tap-the-rat': 'Touchez aussi vite que possible et battez tout le monde.',
      'crazy-nurse': 'Survivez au chaos et tenez le plus longtemps possible.',
      'stick-boy': 'Courez, sautez et évitez tout sur votre chemin.',
      'stone-pile': 'Empilez intelligemment et gardez la pile stable.',
      'space-destroyer': 'Traversez une course spatiale rapide à coups de tirs.',
      'falling-balled-man': 'Gardez le contrôle pendant que tout tombe autour de vous.',
      'lily-in-danger': 'Protégez Lily et survivez à des niveaux dangereux.',
      'subway-trainrun': 'Courez dans la station et évitez tout à pleine vitesse.',
      'bio-race': 'Foncez sur la piste bio et testez sa propre page de fin de partie.',
    },
    'ru': {
      'ludo': 'Мультиплеер на 4 игроков с входом в комнату, созданием комнаты и быстрым матчем.',
      'jewel-quest': 'Собирайте драгоценности и набирайте лучшую серию.',
      'fruit-matching': 'Собирайте 3 и более фруктов как можно быстрее.',
      'memory-match': 'Тренируйте память и внимание быстрыми парами.',
      'tap-the-rat': 'Нажимайте как можно быстрее и побеждайте всех.',
      'crazy-nurse': 'Переживите хаос и продержитесь как можно дольше.',
      'stick-boy': 'Бегите, прыгайте и уклоняйтесь от всего на пути.',
      'stone-pile': 'Складывайте умно и держите башню устойчивой.',
      'space-destroyer': 'Пробейтесь через быстрый космический забег.',
      'falling-balled-man': 'Сохраняйте контроль, пока вокруг всё падает.',
      'lily-in-danger': 'Защитите Лили и выживите в опасных уровнях.',
      'subway-trainrun': 'Бегите по станции и уворачивайтесь от всего на полной скорости.',
      'bio-race': 'Мчитесь по био-трассе и проверьте собственную страницу game over.',
    },
    'el': {
      'ludo': 'Multiplayer 4 παικτών με join room, create room και quick match.',
      'jewel-quest': 'Ταίριαξε πετράδια και χτίσε το καλύτερο combo.',
      'fruit-matching': 'Ταίριαξε 3 ή περισσότερα φρούτα όσο πιο γρήγορα μπορείς.',
      'memory-match': 'Προπόνησε μνήμη και συγκέντρωση με γρήγορα ζευγάρια.',
      'tap-the-rat': 'Πάτα όσο πιο γρήγορα μπορείς και νίκησε όλους.',
      'crazy-nurse': 'Επιβίωσε στο χάος και κράτα όσο περισσότερο μπορείς.',
      'stick-boy': 'Τρέξε, πήδα και απέφυγε τα πάντα στο δρόμο σου.',
      'stone-pile': 'Στοίβαξε έξυπνα και κράτα τη στοίβα σταθερή.',
      'space-destroyer': 'Πυροβόλα μέσα από μια γρήγορη διαστημική διαδρομή.',
      'falling-balled-man': 'Κράτα τον έλεγχο ενώ όλα πέφτουν γύρω σου.',
      'lily-in-danger': 'Προστάτεψε τη Lily και επιβίωσε σε επικίνδυνα επίπεδα.',
      'subway-trainrun': 'Τρέξε μέσα στον σταθμό και απέφυγε τα πάντα με πλήρη ταχύτητα.',
      'bio-race': 'Τρέξε στην bio πίστα και δοκίμασε τη δική της σελίδα game over.',
    },
    'hi': {
      'ludo': '4 खिलाड़ी मल्टीप्लेयर गेम जिसमें join room, create room और quick match है।',
      'jewel-quest': 'ज्वेल मिलाओ और सबसे बड़ा कॉम्बो बनाओ।',
      'fruit-matching': '3 या उससे ज़्यादा फलों को जितनी जल्दी हो सके मिलाओ।',
      'memory-match': 'तेज़ जोड़ों के साथ अपनी याददाश्त और फोकस को ट्रेन करो।',
      'tap-the-rat': 'जितनी तेज़ हो सके टैप करो और सबको हराओ।',
      'crazy-nurse': 'अराजकता से बचो और जितनी देर हो सके टिके रहो।',
      'stick-boy': 'दौड़ो, कूदो और रास्ते की हर चीज़ से बचो।',
      'stone-pile': 'समझदारी से जमाओ और ढेर को स्थिर रखो।',
      'space-destroyer': 'तेज़ स्पेस रन में सब कुछ उड़ा दो।',
      'falling-balled-man': 'जब सब कुछ गिर रहा हो तब भी नियंत्रण बनाए रखो।',
      'lily-in-danger': 'Lily को बचाओ और खतरनाक लेवल पार करो।',
      'subway-trainrun': 'स्टेशन में दौड़ो और पूरी रफ्तार से सब कुछ बचाते जाओ।',
      'bio-race': 'बायो ट्रैक पर दौड़ो और उसकी अपनी game over page टेस्ट करो।',
    },
    'pt': {
      'ludo': 'Jogo multijogador para 4 jogadores com entrar na sala, criar sala e partida rápida.',
      'jewel-quest': 'Combine joias e construa o melhor combo.',
      'fruit-matching': 'Combine 3 ou mais frutas o mais rápido possível.',
      'memory-match': 'Treine a memória e o foco com pares rápidos.',
      'tap-the-rat': 'Toque o mais rápido possível e vença todos.',
      'crazy-nurse': 'Sobreviva ao caos e aguente o máximo possível.',
      'stick-boy': 'Corra, salte e desvie de tudo no seu caminho.',
      'stone-pile': 'Empilhe com inteligência e mantenha a pilha estável.',
      'space-destroyer': 'Abra caminho num rápido percurso espacial.',
      'falling-balled-man': 'Mantenha o controlo enquanto tudo cai à sua volta.',
      'lily-in-danger': 'Proteja a Lily e sobreviva a níveis perigosos.',
      'subway-trainrun': 'Corra pela estação e desvie de tudo em alta velocidade.',
      'bio-race': 'Corra na pista bio e teste a sua própria página de fim de jogo.',
    },
    'it': {
      'ludo': 'Gioco multiplayer per 4 giocatori con entra nella stanza, crea stanza e partita rapida.',
      'jewel-quest': 'Abbina gioielli e crea la combo migliore.',
      'fruit-matching': 'Abbina 3 o più frutti il più velocemente possibile.',
      'memory-match': 'Allena memoria e concentrazione con coppie rapide.',
      'tap-the-rat': 'Tocca il più velocemente possibile e batti tutti.',
      'crazy-nurse': 'Sopravvivi al caos e resisti il più a lungo possibile.',
      'stick-boy': 'Corri, salta e schiva tutto sul tuo cammino.',
      'stone-pile': 'Impila con intelligenza e mantieni stabile la pila.',
      'space-destroyer': 'Spara attraverso una rapida corsa spaziale.',
      'falling-balled-man': 'Mantieni il controllo mentre tutto cade intorno a te.',
      'lily-in-danger': 'Proteggi Lily e sopravvivi a livelli pericolosi.',
      'subway-trainrun': 'Corri nella stazione e schiva tutto a tutta velocità.',
      'bio-race': 'Corri sulla pista bio e prova la sua pagina di game over.',
    },
    'tr': {
      'ludo': 'Oda katıl, oda oluştur ve hızlı maç içeren 4 oyunculu çok oyunculu oyun.',
      'jewel-quest': 'Mücevherleri eşleştir ve en yüksek komboyu yap.',
      'fruit-matching': '3 veya daha fazla meyveyi olabildiğince hızlı eşleştir.',
      'memory-match': 'Hızlı eşlerle hafızanı ve odağını geliştir.',
      'tap-the-rat': 'Olabildiğince hızlı dokun ve herkesi yen.',
      'crazy-nurse': 'Kaostan sağ çık ve mümkün olduğunca uzun süre dayan.',
      'stick-boy': 'Koş, zıpla ve yolundaki her şeyden kaç.',
      'stone-pile': 'Akıllıca diz ve yığını dengede tut.',
      'space-destroyer': 'Hızlı bir uzay koşusunda her şeyi patlat.',
      'falling-balled-man': 'Her şey düşerken kontrolü elinde tut.',
      'lily-in-danger': 'Lily’yi koru ve tehlikeli bölümlerde hayatta kal.',
      'subway-trainrun': 'İstasyonda koş ve tam hızla her şeyden kaç.',
      'bio-race': 'Bio pistinde yarış ve kendi game over sayfasını test et.',
    },
    'ar': {
      'ludo': 'لعبة متعددة اللاعبين لـ4 لاعبين مع الانضمام إلى غرفة وإنشاء غرفة ومطابقة سريعة.',
      'jewel-quest': 'طابق الجواهر واصنع أعلى كومبو.',
      'fruit-matching': 'طابق 3 فواكه أو أكثر بأسرع ما يمكن.',
      'memory-match': 'درّب ذاكرتك وتركيزك بأزواج سريعة.',
      'tap-the-rat': 'اضغط بأسرع ما يمكن واهزم الجميع.',
      'crazy-nurse': 'انجُ من الفوضى واصمد لأطول وقت ممكن.',
      'stick-boy': 'اركض واقفز وتجنب كل شيء في طريقك.',
      'stone-pile': 'رصّ بذكاء وحافظ على استقرار الكومة.',
      'space-destroyer': 'أطلق النار خلال جولة فضائية سريعة.',
      'falling-balled-man': 'حافظ على السيطرة بينما يسقط كل شيء من حولك.',
      'lily-in-danger': 'احمِ Lily وابقَ على قيد الحياة في المراحل الخطيرة.',
      'subway-trainrun': 'اركض عبر المحطة وتجنب كل شيء بأقصى سرعة.',
      'bio-race': 'تسابق عبر مسار bio واختبر صفحة game over الخاصة به.',
    },
    'bn': {
      'ludo': 'join room, create room আর quick match সহ ৪ খেলোয়াড়ের মাল্টিপ্লেয়ার গেম।',
      'jewel-quest': 'রত্ন মিলিয়ে সবচেয়ে বড় কম্বো বানাও।',
      'fruit-matching': '৩ বা তার বেশি ফল যত দ্রুত সম্ভব মিলাও।',
      'memory-match': 'দ্রুত জোড়ার মাধ্যমে স্মৃতি আর ফোকাস ট্রেন করো।',
      'tap-the-rat': 'যত দ্রুত পারো ট্যাপ করো আর সবাইকে হারাও।',
      'crazy-nurse': 'বিশৃঙ্খলা থেকে বাঁচো আর যতক্ষণ পারো টিকে থাকো।',
      'stick-boy': 'দৌড়াও, লাফাও আর পথে যা আসে তা এড়িয়ে যাও।',
      'stone-pile': 'বুদ্ধি করে সাজাও আর স্তূপটাকে স্থির রাখো।',
      'space-destroyer': 'দ্রুত স্পেস রানে সব উড়িয়ে দাও।',
      'falling-balled-man': 'সব কিছু পড়লেও নিয়ন্ত্রণ ধরে রাখো।',
      'lily-in-danger': 'Lily-কে রক্ষা করো আর বিপজ্জনক লেভেল পার করো।',
      'subway-trainrun': 'স্টেশনের ভেতর দৌড়াও আর পুরো গতিতে সব এড়িয়ে চলো।',
      'bio-race': 'bio ট্র্যাকে দৌড়াও আর এর নিজস্ব game over page টেস্ট করো।',
    },
    'ta': {
      'ludo': 'join room, create room மற்றும் quick match உடன் 4 வீரர் மல்டிப்ளேயர் விளையாட்டு.',
      'jewel-quest': 'ரத்தினங்களை பொருத்தி பெரிய combo உருவாக்கு.',
      'fruit-matching': '3 அல்லது அதற்கு மேற்பட்ட பழங்களை மிக வேகமாக பொருத்து.',
      'memory-match': 'வேகமான ஜோடிகளால் நினைவாற்றலும் கவனமும் வளர்த்து கொள்.',
      'tap-the-rat': 'அதிக வேகத்தில் தட்டி எல்லோரையும் வெல்.',
      'crazy-nurse': 'குழப்பத்தில் உயிர் தப்பி எவ்வளவு நேரம் முடிகிறதோ அவ்வளவு நீடித்து விளையாடு.',
      'stick-boy': 'ஓடு, தாவு, வழியிலுள்ள அனைத்தையும் தவிர்த்து செல்.',
      'stone-pile': 'புத்திசாலித்தனமாக அடுக்கி குவியலை நிலையாக வைத்திரு.',
      'space-destroyer': 'வேகமான space run-ல் எல்லாவற்றையும் சுட்டு உடை.',
      'falling-balled-man': 'அனைத்தும் கீழே விழுந்தாலும் கட்டுப்பாட்டை கையில் வை.',
      'lily-in-danger': 'Lily-ஐ காப்பாற்றி ஆபத்தான நிலைகளை கடந்து செல்.',
      'subway-trainrun': 'நிலையம் வழியாக ஓடி முழு வேகத்தில் அனைத்தையும் தவிர்த்து செல்.',
      'bio-race': 'bio track-ல் பந்தயம் பண்ணி அதன் சொந்த game over page-ஐ சோதிக்கவும்.',
    },
    'te': {
      'ludo': 'join room, create room మరియు quick match ఉన్న 4 ప్లేయర్ మల్టీప్లేయర్ గేమ్.',
      'jewel-quest': 'రత్నాలను మ్యాచ్ చేసి పెద్ద కాంబో సాధించండి.',
      'fruit-matching': '3 లేదా అంతకంటే ఎక్కువ పండ్లను ఎంత వేగంగా అయితే అంత వేగంగా మ్యాచ్ చేయండి.',
      'memory-match': 'త్వరిత జంటలతో మీ జ్ఞాపకశక్తి, ఫోకస్‌ను ట్రైన్ చేయండి.',
      'tap-the-rat': 'ఎంత వేగంగా అయితే అంత వేగంగా ట్యాప్ చేసి అందరినీ ఓడించండి.',
      'crazy-nurse': 'అల్లకల్లోలాన్ని తట్టుకుని ఎంతకాలం అయితే అంతకాలం నిలబడండి.',
      'stick-boy': 'పరుగెత్తు, ఎగురు, దారిలో ఉన్న ప్రతిదాన్ని తప్పించుకో.',
      'stone-pile': 'తెలివిగా కట్టండి, గుట్టను స్థిరంగా ఉంచండి.',
      'space-destroyer': 'వేగమైన space run లో అన్నింటినీ పేల్చేయండి.',
      'falling-balled-man': 'అన్నీ పడుతున్నప్పటికీ నియంత్రణలో ఉండు.',
      'lily-in-danger': 'Lily ను కాపాడి ప్రమాదకరమైన లెవెల్స్‌లో బతికి బయటపడు.',
      'subway-trainrun': 'స్టేషన్‌లో పరుగెత్తి పూర్తి వేగంతో అన్నింటినీ తప్పించుకో.',
      'bio-race': 'bio ట్రాక్‌లో రేస్ చేసి దాని స్వంత game over page ను పరీక్షించు.',
    },
  };

  static _GamesCopy of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
    if (languageCode == 'nl') {
      return const _GamesCopy._(
        gamesTitle: 'Games',
        gamesSubtitle: 'Speel games, verdien coins en klim omhoog op het leaderboard.',
        syncIssue: 'Synchronisatieprobleem',
        syncUnavailable: 'PlayersAreGamers is tijdelijk niet bereikbaar. Je kunt later opnieuw synchroniseren.',
        syncNotConfigured: 'Games zijn nog niet beschikbaar op deze versie. Update de app of probeer later opnieuw.',
        linkExistingHint: 'Er lijkt al een bestaand PlayersAreGamers-account te bestaan. Link dat hieronder met je username en wachtwoord.',
        pagCoinsTitle: 'PlayersAreGamers coins',
        coinsUnitLabel: 'coins',
        pagCoinsDescriptionLinked: 'Deze coins staan op je gekoppelde PlayersAreGamers-account. Gebruik ze binnen het gameplatform zelf.',
        pagCoinsDescriptionUnlinked: 'Nieuwe PlayersAreGamers-accounts starten met gratis starter coins.',
        prepareAccountTitle: 'Games-account voorbereiden',
        prepareAccountBody: 'Videomoney probeert automatisch een PlayersAreGamers-account voor je klaar te zetten. Had je al een oud PAG-account, link het dan hieronder zodat je coins en progress behouden blijven.',
        retryAutoStart: 'Probeer automatische start opnieuw',
        linkExistingButton: 'Bestaand account linken',
        createWebsiteButton: 'Account op website maken',
        usernameLabel: 'Gebruikersnaam',
        gamesPlayedLabel: 'Games gespeeld',
        coinsEarnedLabel: 'Coins verdiend',
        winRateLabel: 'Winrate',
        accountStatus: 'PAG account actief',
        keepPlaying: 'Blijf spelen!',
        totalCoinsSubtitle: 'Totaal verdiend',
        winRateSubtitle: 'Jouw speltempo',
        supportedGamesTitle: 'Spellen',
        supportedGamesSubtitle: 'Alleen de geselecteerde games hieronder staan live in Videomoney en openen direct in de app.',
        realtimeMultiplayerTitle: 'Realtime multiplayer',
        singlePlayerTitle: 'Solo games',
        play: 'Speel',
        pagLeaderboardTitle: 'PAG coin leaderboard',
        pagLeaderboardSubtitle: 'Online Videomoney-gebruikers met een gekoppeld PlayersAreGamers-account, gesorteerd op coins.',
        pagLeaderboardEmpty: 'Nog geen online gebruikers met een PAG-account gevonden.',
        youLabel: '(jij)',
        onlineLabel: 'online',
        createPagAccount: 'PlayersAreGamers-account maken',
        linkPagAccount: 'Bestaand PlayersAreGamers-account linken',
        passwordLabel: 'Wachtwoord',
        minUsernameError: 'Gebruik minimaal 3 tekens.',
        minPasswordError: 'Gebruik minimaal 6 tekens.',
        currentEmailHint: 'Je huidige Firebase e-mailadres wordt gebruikt voor het nieuwe game-account.',
        cancel: 'Annuleren',
        pleaseWait: 'Even geduld...',
        create: 'Maken',
        link: 'Linken',
        gameDescriptions: {
          'ludo': '4 speler multiplayer game met join room, create room en quick match.',
          'jewel-quest': 'Match edelstenen en haal de hoogste combo.',
          'fruit-matching': 'Match 3 of meer vruchten zo snel mogelijk.',
          'memory-match': 'Train je geheugen en focus met snelle paren.',
          'tap-the-rat': 'Tik zo snel mogelijk en versla iedereen.',
          'crazy-nurse': 'Overleef de chaos en blijf zo lang mogelijk overeind.',
          'stick-boy': 'Sprint, spring en ontwijk alles op je pad.',
          'stone-pile': 'Bouw slim en houd je stapel stabiel.',
          'space-destroyer': 'Schiet alles neer in een snelle ruimterun.',
          'falling-balled-man': 'Blijf in controle terwijl alles naar beneden stort.',
          'lily-in-danger': 'Bescherm Lily en overleef de gevaarlijke levels.',
          'subway-trainrun': 'Ren door het station en ontwijk alles op volle snelheid.',
          'bio-race': 'Race door de bio-track en check de eigen game over page.',
        },
      );
    }

    final english = const _GamesCopy._(
      gamesTitle: 'Games',
      gamesSubtitle: 'Play games, earn coins and climb higher on the leaderboard.',
      syncIssue: 'Sync issue',
      syncUnavailable: 'PlayersAreGamers is temporarily unavailable. You can sync again later.',
      syncNotConfigured: 'Games are not available on this version yet. Please update the app or try again later.',
      linkExistingHint: 'It looks like a PlayersAreGamers account already exists. Link it below with your username and password.',
      pagCoinsTitle: 'PlayersAreGamers coins',
      coinsUnitLabel: 'coins',
      pagCoinsDescriptionLinked: 'These coins live on your linked PlayersAreGamers account. Use them inside the game platform itself.',
      pagCoinsDescriptionUnlinked: 'New PlayersAreGamers accounts start with free starter coins.',
      prepareAccountTitle: 'Preparing your game account',
      prepareAccountBody: 'Videomoney tries to create a PlayersAreGamers account for you automatically. If you already had an older PAG account, link it below so your coins and progress stay intact.',
      retryAutoStart: 'Retry automatic start',
      linkExistingButton: 'Link existing account',
      createWebsiteButton: 'Create account on website',
      usernameLabel: 'Username',
      gamesPlayedLabel: 'Games played',
      coinsEarnedLabel: 'Coins earned',
      winRateLabel: 'Win rate',
      accountStatus: 'PAG account active',
      keepPlaying: 'Keep playing!',
      totalCoinsSubtitle: 'Total earned',
      winRateSubtitle: 'Your game pace',
      supportedGamesTitle: 'Games',
      supportedGamesSubtitle: 'Only the selected games below are live inside Videomoney and open directly in the app.',
      realtimeMultiplayerTitle: 'Real-time multiplayer',
      singlePlayerTitle: 'Single player',
      play: 'Play',
      pagLeaderboardTitle: 'PAG coin leaderboard',
      pagLeaderboardSubtitle: 'Online Videomoney users with a linked PlayersAreGamers account, ranked by coins.',
      pagLeaderboardEmpty: 'No online users with a PAG account found yet.',
      youLabel: '(you)',
      onlineLabel: 'online',
      createPagAccount: 'Create PlayersAreGamers account',
      linkPagAccount: 'Link existing PlayersAreGamers account',
      passwordLabel: 'Password',
      minUsernameError: 'Use at least 3 characters.',
      minPasswordError: 'Use at least 6 characters.',
      currentEmailHint: 'Your current Firebase email will be used for the new game account.',
      cancel: 'Cancel',
      pleaseWait: 'Please wait...',
      create: 'Create',
      link: 'Link',
      gameDescriptions: {
        'ludo': '4 player multiplayer game with join room, create room and quick match.',
        'jewel-quest': 'Match jewels and build the highest combo.',
        'fruit-matching': 'Match 3 or more fruits as fast as you can.',
        'memory-match': 'Train your memory and focus with fast pairs.',
        'tap-the-rat': 'Tap as fast as possible and beat everyone.',
        'crazy-nurse': 'Survive the chaos and stay alive as long as you can.',
        'stick-boy': 'Run, jump and dodge everything in your path.',
        'stone-pile': 'Stack smart and keep the pile stable.',
        'space-destroyer': 'Blast through a fast space run.',
        'falling-balled-man': 'Stay in control while everything drops around you.',
        'lily-in-danger': 'Protect Lily and survive dangerous levels.',
        'subway-trainrun': 'Run through the station and dodge everything at full speed.',
        'bio-race': 'Race through the bio track and test its own game over page.',
      },
    );

    final localizedValues = _localizedSectionValues[languageCode];
    if (localizedValues == null) return english;
    return english.copyWith(
      gamesTitle: localizedValues['gamesTitle'],
      gamesSubtitle: localizedValues['gamesSubtitle'],
      supportedGamesTitle: localizedValues['supportedGamesTitle'],
      supportedGamesSubtitle: localizedValues['supportedGamesSubtitle'],
      realtimeMultiplayerTitle: localizedValues['realtimeMultiplayerTitle'],
      singlePlayerTitle: localizedValues['singlePlayerTitle'],
      play: localizedValues['play'],
      pagLeaderboardTitle: localizedValues['pagLeaderboardTitle'],
      pagLeaderboardSubtitle: localizedValues['pagLeaderboardSubtitle'],
      pagLeaderboardEmpty: localizedValues['pagLeaderboardEmpty'],
      youLabel: localizedValues['youLabel'],
      onlineLabel: localizedValues['onlineLabel'],
      gameDescriptions:
          _localizedGameDescriptions[languageCode] ?? english.gameDescriptions,
    );
  }
}

class _PagGameDefinition {
  const _PagGameDefinition(
    this.id,
    this.name,
    this.targetUrl, {
    this.landscapeOnly = false,
  });

  final String id;
  final String name;
  final String? targetUrl;
  final bool landscapeOnly;
}
