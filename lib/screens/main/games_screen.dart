import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/players_are_gamers_profile.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/presence_service.dart';
import 'players_are_gamers_webview_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final PlayersAreGamersService _service = PlayersAreGamersService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<Set<String>> _onlineUserIdsStream =
      PresenceService.instance.watchOnlineUserIds();
  bool _loading = true;
  String? _error;

  static const List<_PagGameDefinition> _multiplayerGames = [
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
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayersAreGamersWebViewScreen(
          service: _service,
          initialUrl: initialUrl,
          landscapeOnly: game?.landscapeOnly ?? false,
        ),
      ),
    );
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

    return StreamBuilder<PlayersAreGamersProfile?>(
      stream: _service.watchProfile(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        return StreamBuilder<Set<String>>(
          stream: _onlineUserIdsStream,
          builder: (context, onlineSnapshot) {
            final onlineUserIds = onlineSnapshot.data ?? <String>{};
            final onlineCount = onlineUserIds.length;

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
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        _buildHero(copy),
                        const SizedBox(height: 18),
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
                          const SizedBox(height: 18),
                          _buildPagCoinLeaderboard(
                            copy: copy,
                            onlineUserIds: onlineUserIds,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildPagCoinLeaderboard({
    required _GamesCopy copy,
    required Set<String> onlineUserIds,
  }) {
    return _NeonPanel(
      child: FutureBuilder<List<_PagCoinLeaderboardEntry>>(
        future: _loadPagCoinLeaderboard(onlineUserIds),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <_PagCoinLeaderboardEntry>[];
          final currentUid = FirebaseAuth.instance.currentUser?.uid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.pagLeaderboardTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.pagLeaderboardSubtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (entries.isEmpty)
                Text(
                  copy.pagLeaderboardEmpty,
                  style: TextStyle(color: Colors.white.withOpacity(0.68)),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      _LeaderboardTile(
                        rank: i + 1,
                        entry: entries[i],
                        isCurrentUser: entries[i].uid == currentUid,
                        youLabel: copy.youLabel,
                        coinsLabel: copy.coinsUnitLabel,
                        onlineLabel: copy.onlineLabel,
                      ),
                      if (i != entries.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
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
            Text(
              playLabel,
              style: const TextStyle(
                color: Color(0xFF18E477),
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
        },
      );
    }

    return const _GamesCopy._(
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
      },
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
