class PlayersAreGamersProfile {
  const PlayersAreGamersProfile({
    required this.linked,
    required this.exists,
    required this.username,
    required this.email,
    required this.firebaseUid,
    required this.avatar,
    required this.coins,
    required this.totalGamesPlayed,
    required this.totalGamesWon,
    required this.totalCoinsEarned,
    required this.recentGames,
    required this.gameBreakdown,
    this.id,
    this.winRate,
    this.createdAt,
    this.lastLogin,
    this.syncedAt,
  });

  final bool linked;
  final bool exists;
  final int? id;
  final String username;
  final String email;
  final String firebaseUid;
  final String avatar;
  final int coins;
  final int totalGamesPlayed;
  final int totalGamesWon;
  final int totalCoinsEarned;
  final String? winRate;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final DateTime? syncedAt;
  final List<PlayersAreGamersRecentGame> recentGames;
  final List<PlayersAreGamersGameBreakdown> gameBreakdown;

  bool get hasStats =>
      totalGamesPlayed > 0 || totalCoinsEarned > 0 || recentGames.isNotEmpty;

  double get starterProgress {
    if (coins <= 0) return 0;
    if (coins >= 100) return 1;
    return coins / 100;
  }

  factory PlayersAreGamersProfile.unlinked({
    String firebaseUid = '',
    DateTime? syncedAt,
  }) {
    return PlayersAreGamersProfile(
      linked: false,
      exists: false,
      username: '',
      email: '',
      firebaseUid: firebaseUid,
      avatar: '',
      coins: 0,
      totalGamesPlayed: 0,
      totalGamesWon: 0,
      totalCoinsEarned: 0,
      recentGames: const [],
      gameBreakdown: const [],
      syncedAt: syncedAt,
    );
  }

  factory PlayersAreGamersProfile.fromApi(
    Map<String, dynamic> payload, {
    Map<String, dynamic>? statsPayload,
  }) {
    final player = _asMap(payload['player']);
    final statsPlayer = _asMap(statsPayload?['player']);
    return PlayersAreGamersProfile(
      linked: payload['linked'] == true || payload['success'] == true,
      exists: payload['exists'] != false,
      id: _asInt(player['id']),
      username: (player['username'] ?? '').toString(),
      email: (player['email'] ?? '').toString(),
      firebaseUid: (player['firebaseUid'] ?? player['firebase_uid'] ?? '').toString(),
      avatar: (player['avatar'] ?? '').toString(),
      coins: _asInt(player['coins']) ?? 0,
      totalGamesPlayed:
          _asInt(statsPlayer['totalGamesPlayed']) ??
          _asInt(player['stats'] is Map ? (player['stats'] as Map)['totalGamesPlayed'] : null) ??
          0,
      totalGamesWon:
          _asInt(statsPlayer['totalGamesWon']) ??
          _asInt(player['stats'] is Map ? (player['stats'] as Map)['totalGamesWon'] : null) ??
          0,
      totalCoinsEarned:
          _asInt(statsPlayer['totalCoinsEarned']) ??
          _asInt(player['stats'] is Map ? (player['stats'] as Map)['totalCoinsEarned'] : null) ??
          0,
      winRate: statsPlayer['winRate']?.toString(),
      createdAt: _asDateTime(player['createdAt'] ?? player['created_at']),
      lastLogin: _asDateTime(player['lastLogin'] ?? player['last_login']),
      recentGames:
          ((_asList(statsPayload?['recentGames']))
                  .map((item) => PlayersAreGamersRecentGame.fromMap(_asMap(item)))
                  .toList())
              .cast<PlayersAreGamersRecentGame>(),
      gameBreakdown:
          ((_asList(statsPayload?['gameBreakdown']))
                  .map((item) => PlayersAreGamersGameBreakdown.fromMap(_asMap(item)))
                  .toList())
              .cast<PlayersAreGamersGameBreakdown>(),
      syncedAt: DateTime.now(),
    );
  }

  factory PlayersAreGamersProfile.fromFirestore(Map<String, dynamic> data) {
    return PlayersAreGamersProfile(
      linked: data['linked'] == true,
      exists: data['exists'] != false,
      id: _asInt(data['id']),
      username: (data['username'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      firebaseUid: (data['firebaseUid'] ?? '').toString(),
      avatar: (data['avatar'] ?? '').toString(),
      coins: _asInt(data['coins']) ?? 0,
      totalGamesPlayed: _asInt(data['totalGamesPlayed']) ?? 0,
      totalGamesWon: _asInt(data['totalGamesWon']) ?? 0,
      totalCoinsEarned: _asInt(data['totalCoinsEarned']) ?? 0,
      winRate: data['winRate']?.toString(),
      createdAt: _asDateTime(data['createdAt']),
      lastLogin: _asDateTime(data['lastLogin']),
      syncedAt: _asDateTime(data['syncedAt']),
      recentGames:
          _asList(data['recentGames'])
              .map((item) => PlayersAreGamersRecentGame.fromMap(_asMap(item)))
              .toList(),
      gameBreakdown:
          _asList(data['gameBreakdown'])
              .map((item) => PlayersAreGamersGameBreakdown.fromMap(_asMap(item)))
              .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'linked': linked,
      'exists': exists,
      'id': id,
      'username': username,
      'email': email,
      'firebaseUid': firebaseUid,
      'avatar': avatar,
      'coins': coins,
      'totalGamesPlayed': totalGamesPlayed,
      'totalGamesWon': totalGamesWon,
      'totalCoinsEarned': totalCoinsEarned,
      'winRate': winRate,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'syncedAt': (syncedAt ?? DateTime.now()).toIso8601String(),
      'recentGames': recentGames.map((game) => game.toMap()).toList(),
      'gameBreakdown': gameBreakdown.map((game) => game.toMap()).toList(),
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

class PlayersAreGamersRecentGame {
  const PlayersAreGamersRecentGame({
    required this.gameId,
    required this.score,
    required this.playTime,
    required this.coinsAwarded,
    this.submittedAt,
  });

  final String gameId;
  final int score;
  final int playTime;
  final int coinsAwarded;
  final DateTime? submittedAt;

  factory PlayersAreGamersRecentGame.fromMap(Map<String, dynamic> data) {
    return PlayersAreGamersRecentGame(
      gameId: (data['game_id'] ?? data['gameId'] ?? '').toString(),
      score: PlayersAreGamersProfile._asInt(data['score']) ?? 0,
      playTime: PlayersAreGamersProfile._asInt(data['play_time'] ?? data['playTime']) ?? 0,
      coinsAwarded:
          PlayersAreGamersProfile._asInt(data['coins_awarded'] ?? data['coinsAwarded']) ?? 0,
      submittedAt: PlayersAreGamersProfile._asDateTime(
        data['submitted_at'] ?? data['submittedAt'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'score': score,
      'playTime': playTime,
      'coinsAwarded': coinsAwarded,
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }
}

class PlayersAreGamersGameBreakdown {
  const PlayersAreGamersGameBreakdown({
    required this.gameId,
    required this.plays,
    required this.totalCoins,
    required this.bestScore,
    required this.averageScore,
  });

  final String gameId;
  final int plays;
  final int totalCoins;
  final int bestScore;
  final double averageScore;

  factory PlayersAreGamersGameBreakdown.fromMap(Map<String, dynamic> data) {
    return PlayersAreGamersGameBreakdown(
      gameId: (data['game_id'] ?? data['gameId'] ?? '').toString(),
      plays: PlayersAreGamersProfile._asInt(data['plays']) ?? 0,
      totalCoins: PlayersAreGamersProfile._asInt(data['total_coins'] ?? data['totalCoins']) ?? 0,
      bestScore: PlayersAreGamersProfile._asInt(data['best_score'] ?? data['bestScore']) ?? 0,
      averageScore: double.tryParse(
            (data['avg_score'] ?? data['averageScore'] ?? '0').toString(),
          ) ??
          0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'plays': plays,
      'totalCoins': totalCoins,
      'bestScore': bestScore,
      'averageScore': averageScore,
    };
  }
}

class PlayersAreGamersSession {
  const PlayersAreGamersSession({
    required this.token,
    required this.userJson,
  });

  final String token;
  final String userJson;
}

class PlayersAreGamersLaunchContext {
  const PlayersAreGamersLaunchContext({
    required this.redirectUrl,
    required this.cookies,
  });

  final String redirectUrl;
  final List<PlayersAreGamersCookie> cookies;
}

class PlayersAreGamersCookie {
  const PlayersAreGamersCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.isSecure = true,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool isSecure;
}

class PlayersAreGamersAdRewardResult {
  const PlayersAreGamersAdRewardResult({
    required this.pagCoinsGranted,
    required this.videomoneyRewardGranted,
  });

  final bool pagCoinsGranted;
  final bool videomoneyRewardGranted;
}
