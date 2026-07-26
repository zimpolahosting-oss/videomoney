import '../models/short_video_item.dart';
import 'playlist_feed_service.dart';

abstract class VideoFeedProvider {
  Future<List<ShortVideoItem>> fetchFeed({
    String? userId,
    List<String> preferredTopics,
  });
}

class PlaylistVideoFeedProvider implements VideoFeedProvider {
  PlaylistVideoFeedProvider({PlaylistFeedService? playlistFeedService})
      : _playlistFeedService = playlistFeedService ?? PlaylistFeedService();

  final PlaylistFeedService _playlistFeedService;

  @override
  Future<List<ShortVideoItem>> fetchFeed({
    String? userId,
    List<String> preferredTopics = const [],
  }) {
    return _playlistFeedService.loadPlaylistItems();
  }

  Future<List<ShortVideoItem>> fetchCachedFeed() {
    return _playlistFeedService.loadCachedPlaylistItems();
  }
}

class VideoFeedService {
  VideoFeedService({VideoFeedProvider? provider})
      : _provider = provider ?? PlaylistVideoFeedProvider();

  final VideoFeedProvider _provider;

  Future<List<ShortVideoItem>> loadCachedFeed() async {
    final provider = _provider;
    if (provider is PlaylistVideoFeedProvider) {
      return provider.fetchCachedFeed();
    }
    return const [];
  }

  Future<List<ShortVideoItem>> loadFeed({
    String? userId,
    List<String> preferredTopics = const [],
  }) {
    return _provider.fetchFeed(
      userId: userId,
      preferredTopics: preferredTopics,
    );
  }
}
