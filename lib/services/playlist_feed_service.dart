import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/short_video_item.dart';

class PlaylistFeedException implements Exception {
  const PlaylistFeedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaylistFeedService {
  PlaylistFeedService({http.Client? client}) : _client = client ?? http.Client();

  static const String playlistId = 'PLSry5ygXdUKY';
  static const String playlistUrl =
      'https://youtube.com/playlist?list=$playlistId';
  static const String _apiKey = String.fromEnvironment('YOUTUBE_DATA_API_KEY');
  static const Duration refreshInterval = Duration(minutes: 30);
  static const String _cacheItemsKey = 'playlist_feed_cache_items_v1';
  static const String _cacheFetchedAtKey = 'playlist_feed_cache_fetched_at_v1';
  static const Map<String, String> _playlistHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  final http.Client _client;

  Future<List<ShortVideoItem>> loadCachedPlaylistItems() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCachedItems(prefs);
  }

  Future<List<ShortVideoItem>> loadPlaylistItems({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedItems = _readCachedItems(prefs);
    final fetchedAtMs = prefs.getInt(_cacheFetchedAtKey);
    final isFresh = fetchedAtMs != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
            ) <
            refreshInterval;

    if (!forceRefresh && cachedItems.isNotEmpty && isFresh) {
      return cachedItems;
    }

    try {
      final freshItems = _apiKey.isEmpty
          ? await _fetchPlaylistItemsFromPublicPage()
          : await _fetchPlaylistItems();
      await prefs.setString(
        _cacheItemsKey,
        jsonEncode(
          freshItems
              .map(
                (item) => {
                  'id': item.id,
                  'videoId': item.videoId,
                  'sourceUrl': item.sourceUrl,
                  'caption': item.caption,
                  'creator': item.creator,
                  'category': item.category,
                  'durationHintSeconds': item.durationHintSeconds,
                  'thumbnailUrl': item.thumbnailUrl,
                },
              )
              .toList(growable: false),
        ),
      );
      await prefs.setInt(
        _cacheFetchedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return freshItems;
    } catch (error) {
      if (_shouldUsePublicFallback(error)) {
        try {
          final fallbackItems = await _fetchPlaylistItemsFromPublicPage();
          await prefs.setString(
            _cacheItemsKey,
            jsonEncode(
              fallbackItems
                  .map(
                    (item) => {
                      'id': item.id,
                      'videoId': item.videoId,
                      'sourceUrl': item.sourceUrl,
                      'caption': item.caption,
                      'creator': item.creator,
                      'category': item.category,
                      'durationHintSeconds': item.durationHintSeconds,
                      'thumbnailUrl': item.thumbnailUrl,
                    },
                  )
                  .toList(growable: false),
            ),
          );
          await prefs.setInt(
            _cacheFetchedAtKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          return fallbackItems;
        } catch (_) {}
      }
      if (cachedItems.isNotEmpty) return cachedItems;
      if (error is PlaylistFeedException) rethrow;
      throw const PlaylistFeedException(
        'Unable to load playlist videos right now.',
      );
    }
  }

  bool _shouldUsePublicFallback(Object error) {
    final message = error.toString();
    return _apiKey.isEmpty ||
        message.contains('(400)') ||
        message.contains('(401)') ||
        message.contains('(403)') ||
        message.contains('not configured yet');
  }

  List<ShortVideoItem> _readCachedItems(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheItemsKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (item) => ShortVideoItem(
            id: item['id'] as String? ?? '',
            videoId: item['videoId'] as String? ?? '',
            sourceUrl: item['sourceUrl'] as String? ?? '',
            caption: item['caption'] as String? ?? '',
            creator: item['creator'] as String? ?? '',
            category: item['category'] as String? ?? 'YouTube',
            durationHintSeconds:
                (item['durationHintSeconds'] as num?)?.toInt() ?? 60,
            thumbnailUrl: item['thumbnailUrl'] as String?,
          ),
        )
        .where((item) => item.videoId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ShortVideoItem>> _fetchPlaylistItems() async {
    final playlistEntries = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/playlistItems',
        {
          'part': 'snippet,contentDetails',
          'playlistId': playlistId,
          'maxResults': '50',
          'pageToken': pageToken ?? '',
          'key': _apiKey,
        }..removeWhere((key, value) => value.isEmpty),
      );

      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw PlaylistFeedException(
          'Unable to load playlist feed (${response.statusCode}).',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (json['items'] as List<dynamic>? ?? const []);

      for (final rawItem in rawItems) {
        final item = rawItem as Map<String, dynamic>;
        final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
        final resourceId =
            snippet['resourceId'] as Map<String, dynamic>? ?? const {};
        final videoId = resourceId['videoId'] as String? ?? '';
        final title = snippet['title'] as String? ?? '';
        if (videoId.isEmpty ||
            title == 'Deleted video' ||
            title == 'Private video') {
          continue;
        }

        final thumbnails =
            snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
        final highThumb = thumbnails['high'] as Map<String, dynamic>?;
        final mediumThumb = thumbnails['medium'] as Map<String, dynamic>?;
        final defaultThumb = thumbnails['default'] as Map<String, dynamic>?;

        playlistEntries.add(
          {
            'id': item['id'] as String? ?? videoId,
            'videoId': videoId,
            'caption': title,
            'creator': '@${snippet['channelTitle'] as String? ?? 'YouTube'}',
            'thumbnailUrl': (highThumb ?? mediumThumb ?? defaultThumb)?['url']
                as String?,
          },
        );
      }

      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    final items = await _filterEmbeddableVideos(playlistEntries);

    if (items.isEmpty) {
      throw const PlaylistFeedException(
        'The configured YouTube playlist does not contain embeddable public videos.',
      );
    }

    return items;
  }

  Future<List<ShortVideoItem>> _fetchPlaylistItemsFromPublicPage() async {
    final response = await _client.get(
      Uri.parse(playlistUrl),
      headers: _playlistHeaders,
    );
    if (response.statusCode != 200) {
      throw PlaylistFeedException(
        'Unable to load public playlist page (${response.statusCode}).',
      );
    }

    final matches = RegExp(
      r'watch\?v=([A-Za-z0-9_-]{11})',
    ).allMatches(response.body);
    final seen = <String>{};
    final ids = <String>[];
    for (final match in matches) {
      final id = match.group(1);
      if (id == null || !seen.add(id)) continue;
      ids.add(id);
    }

    if (ids.isEmpty) {
      throw const PlaylistFeedException(
        'Unable to extract videos from the public playlist page.',
      );
    }

    return ids.take(60).map((videoId) {
      return ShortVideoItem(
        id: videoId,
        videoId: videoId,
        sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
        caption: 'YouTube playlist video',
        creator: '@YouTube',
        category: 'YouTube',
        durationHintSeconds: 60,
        thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      );
    }).toList(growable: false);
  }

  Future<List<ShortVideoItem>> _filterEmbeddableVideos(
    List<Map<String, dynamic>> playlistEntries,
  ) async {
    if (playlistEntries.isEmpty) return const [];

    final detailsByVideoId = <String, Map<String, dynamic>>{};
    for (var start = 0; start < playlistEntries.length; start += 50) {
      final chunk = playlistEntries.skip(start).take(50).toList(growable: false);
      final ids = chunk
          .map((entry) => entry['videoId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) continue;

      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/videos',
        {
          'part': 'status,contentDetails',
          'id': ids.join(','),
          'key': _apiKey,
        },
      );

      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw PlaylistFeedException(
          'Unable to validate embeddable playlist items (${response.statusCode}).',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (json['items'] as List<dynamic>? ?? const []);
      for (final rawItem in rawItems) {
        final item = rawItem as Map<String, dynamic>;
        final id = item['id'] as String? ?? '';
        if (id.isNotEmpty) {
          detailsByVideoId[id] = item;
        }
      }
    }

    return playlistEntries
        .where((entry) {
          final videoId = entry['videoId'] as String? ?? '';
          final details = detailsByVideoId[videoId];
          if (details == null) return false;
          final status = details['status'] as Map<String, dynamic>? ?? const {};
          final privacyStatus = status['privacyStatus'] as String? ?? '';
          final embeddable = status['embeddable'] as bool? ?? false;
          return embeddable && (privacyStatus == 'public' || privacyStatus == 'unlisted');
        })
        .map((entry) {
          final videoId = entry['videoId'] as String? ?? '';
          final details = detailsByVideoId[videoId];
          final contentDetails =
              details?['contentDetails'] as Map<String, dynamic>? ?? const {};
          return ShortVideoItem(
            id: entry['id'] as String? ?? videoId,
            videoId: videoId,
            sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
            caption: entry['caption'] as String? ?? '',
            creator: entry['creator'] as String? ?? '@YouTube',
            category: 'YouTube',
            durationHintSeconds: _parseDurationSeconds(
              contentDetails['duration'] as String?,
            ),
            thumbnailUrl: entry['thumbnailUrl'] as String?,
          );
        })
        .toList(growable: false);
  }

  int _parseDurationSeconds(String? iso8601Duration) {
    if (iso8601Duration == null || iso8601Duration.isEmpty) return 60;

    final match = RegExp(
      r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
    ).firstMatch(iso8601Duration);
    if (match == null) return 60;

    final days = int.tryParse(match.group(1) ?? '0') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '0') ?? 0;
    final totalSeconds =
        (days * 24 * 60 * 60) + (hours * 60 * 60) + (minutes * 60) + seconds;
    return totalSeconds > 0 ? totalSeconds : 60;
  }
}
