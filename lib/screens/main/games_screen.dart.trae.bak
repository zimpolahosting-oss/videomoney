import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/players_are_gamers_profile.dart';
import '../../services/players_are_gamers_service.dart';
import 'players_are_gamers_webview_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final PlayersAreGamersService _service = PlayersAreGamersService();
  bool _loading = true;
  String? _error;

  static const List<_PagGameDefinition> _games = [
    _PagGameDefinition('bionic-race', 'Bionic Race'),
    _PagGameDefinition('bomberman', 'Bomberman'),
    _PagGameDefinition('chicken-road', 'Chicken Road'),
    _PagGameDefinition('cookie-match', 'Cookie Match'),
    _PagGameDefinition('crazy-nurse', 'Crazy Nurse'),
    _PagGameDefinition('donkey-kong', 'Donkey Kong'),
    _PagGameDefinition('duck-shooter', 'Duck Shooter'),
    _PagGameDefinition('falling-baldman', 'Falling Baldman'),
    _PagGameDefinition('fruit-matching', 'Fruit Matching'),
    _PagGameDefinition('halloween-bubble', 'Halloween Bubble'),
    _PagGameDefinition('highway-moto-rider', 'Highway Moto Rider'),
    _PagGameDefinition('minesweeper', 'Minesweeper'),
    _PagGameDefinition('moons', 'Moons'),
    _PagGameDefinition('rider-online', 'Rider Online'),
    _PagGameDefinition('word-search-classic', 'Word Search Classic'),
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
      await _service.refreshProfile(includeStats: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openLobby() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayersAreGamersWebViewScreen(service: _service),
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
                createMode
                    ? 'Create PlayersAreGamers account'
                    : 'Link existing PlayersAreGamers account',
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length < 3) {
                          return 'Use at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    if (createMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Your current Firebase email will be used for the new game account.',
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Please wait...' : (createMode ? 'Create' : 'Link')),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayersAreGamersProfile?>(
      stream: _service.watchProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Games'),
            actions: [
              IconButton(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  _StatusCard(
                    title: 'Sync issue',
                    message: _error!,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildCoinsCard(profile),
                const SizedBox(height: 16),
                if (_loading && profile == null)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: CircularProgressIndicator(),
                  ))
                else if (profile == null || !profile.linked)
                  _buildUnlinkedState()
                else
                  ...[
                    _buildStatsGrid(profile),
                    const SizedBox(height: 16),
                    _buildLobbyCard(),
                    const SizedBox(height: 16),
                    _buildRecentGames(profile),
                    const SizedBox(height: 16),
                    _buildGameBreakdown(profile),
                    const SizedBox(height: 16),
                    _buildGamesList(),
                  ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoinsCard(PlayersAreGamersProfile? profile) {
    final coins = profile?.coins ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports_rounded),
                const SizedBox(width: 10),
                Text(
                  'PlayersAreGamers coins',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$coins / 100 starter coins',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: profile?.starterProgress ?? 0,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 10),
            Text(
              profile?.linked == true
                  ? 'Starter coins come from PlayersAreGamers. Games use and earn coins inside the game platform.'
                  : 'New PlayersAreGamers accounts start with 100 free coins.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlinkedState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up your game account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Videomoney keeps your Firebase login. To start games without a second login later, first link an existing PlayersAreGamers account or create a new one.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showLinkDialog(createMode: false),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Link existing account'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _openRegistrationWebsite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create account on website'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showLinkDialog(createMode: false),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('I already created one, link it now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(PlayersAreGamersProfile profile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Username',
                value: profile.username,
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Games played',
                value: '${profile.totalGamesPlayed}',
                icon: Icons.videogame_asset_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Coins earned',
                value: '${profile.totalCoinsEarned}',
                icon: Icons.toll_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Win rate',
                value: profile.winRate ?? '${profile.totalGamesWon}',
                icon: Icons.emoji_events_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLobbyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game lobby, profile and leaderboard',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the embedded PlayersAreGamers lobby to launch games without logging in again. The same lobby also contains the live profile, leaderboard and game results pages.',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openLobby,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Open PlayersAreGamers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGames(PlayersAreGamersProfile profile) {
    if (profile.recentGames.isEmpty) {
      return const _StatusCard(
        title: 'Recent games',
        message: 'Your recent game history will appear here after your first finished match.',
        icon: Icons.history_rounded,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent games',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final game in profile.recentGames.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.sports_esports_rounded),
                ),
                title: Text(game.gameId),
                subtitle: Text('Score ${game.score} • ${game.playTime}s'),
                trailing: Text('+${game.coinsAwarded}'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameBreakdown(PlayersAreGamersProfile profile) {
    if (profile.gameBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final breakdown in profile.gameBreakdown.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(breakdown.gameId),
                subtitle: Text(
                  '${breakdown.plays} plays • best ${breakdown.bestScore} • avg ${breakdown.averageScore.toStringAsFixed(0)}',
                ),
                trailing: Text('${breakdown.totalCoins} coins'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supported games',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'All supported PlayersAreGamers titles are available from the embedded lobby.',
            ),
            const SizedBox(height: 8),
            for (final game in _games)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gamepad_rounded),
                title: Text(game.name),
                subtitle: Text(game.id),
                trailing: TextButton(
                  onPressed: _openLobby,
                  child: const Text('Play'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
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
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PagGameDefinition {
  const _PagGameDefinition(this.id, this.name);

  final String id;
  final String name;
}
