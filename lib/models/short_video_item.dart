class ShortVideoItem {
  const ShortVideoItem({
    required this.id,
    required this.videoId,
    required this.sourceUrl,
    required this.caption,
    required this.creator,
    required this.category,
    required this.durationHintSeconds,
    this.thumbnailUrl,
  });

  final String id;
  final String videoId;
  final String sourceUrl;
  final String caption;
  final String creator;
  final String category;
  final int durationHintSeconds;
  final String? thumbnailUrl;
}
