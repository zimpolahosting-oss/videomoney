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

  final http.Client _client;

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

    if (_apiKey.isEmpty) {
      if (cachedItems.isNotEmpty) return cachedItems;
      throw const PlaylistFeedException(
        'YouTube playlist access is not configured yet. Add YOUTUBE_DATA_API_KEY for PlaylistFeedService.',
      );
    }

    try {
      final freshItems = await _fetchPlaylistItems();
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
    } catch (_) {
      if (cachedItems.isNotEmpty) return cachedItems;
      rethrow;
    }
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
    final items = <ShortVideoItem>[];
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

        items.add(
          ShortVideoItem(
            id: item['id'] as String? ?? videoId,
            videoId: videoId,
            sourceUrl: 'https://youtube.com/shorts/$videoId',
            caption: title,
            creator: '@${snippet['channelTitle'] as String? ?? 'YouTube'}',
            category: 'YouTube',
            durationHintSeconds: 60,
            thumbnailUrl: (highThumb ?? mediumThumb ?? defaultThumb)?['url']
                as String?,
          ),
        );
      }

      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    if (items.isEmpty) {
      throw const PlaylistFeedException(
        'The configured YouTube playlist does not contain playable public videos.',
      );
    }

    return items;
  }
}
