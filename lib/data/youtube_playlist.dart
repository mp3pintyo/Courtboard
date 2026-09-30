import 'dart:convert';

import 'http_util.dart';
import 'url_safety.dart';
import 'youtube_video_id.dart';

class SavedYouTubeVideo {
  const SavedYouTubeVideo(
      {required this.videoId,
      required this.athleteName,
      required this.title,
      required this.thumbnailUrl,
      required this.savedAt});
  final String videoId;
  final String athleteName;
  final String title;
  final String thumbnailUrl;
  final DateTime savedAt;
  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'athleteName': athleteName,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'savedAt': savedAt.toIso8601String()
      };
  factory SavedYouTubeVideo.fromJson(Map<String, dynamic> json) =>
      tryFromJson(json) ??
      (throw FormatException('Érvénytelen YouTube-azonosító: ${json['videoId']}'));

  /// Mentett bejegyzés visszatöltése. A videóazonosítót újra ellenőrizzük
  /// (a fájl kézzel is szerkeszthető), érvénytelen azonosítónál `null`; nem
  /// biztonságos bélyegkép-cím helyett a YouTube alapértelmezett képe kerül be.
  static SavedYouTubeVideo? tryFromJson(Map<String, dynamic> json) {
    final videoId = YouTubeVideoId.parse('${json['videoId'] ?? ''}');
    if (videoId == null) return null;
    return SavedYouTubeVideo(
        videoId: videoId,
        athleteName: '${json['athleteName'] ?? ''}',
        title: '${json['title'] ?? 'YouTube-videó'}',
        thumbnailUrl: safeThumbnailUrl('${json['thumbnailUrl'] ?? ''}', videoId),
        savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime.now());
  }

  static String defaultThumbnailUrl(String videoId) =>
      'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  static String safeThumbnailUrl(String url, String videoId) =>
      isSafeWebUrl(url) ? url.trim() : defaultThumbnailUrl(videoId);
}

class YouTubeOEmbed {
  static Future<SavedYouTubeVideo> resolve(
      String videoId, String athleteName) async {
    final url = Uri.https('www.youtube.com', '/oembed',
        {'url': 'https://www.youtube.com/watch?v=$videoId', 'format': 'json'});
    final validId = YouTubeVideoId.parse(videoId);
    if (validId == null) {
      throw FormatException('Érvénytelen YouTube-azonosító: $videoId');
    }
    final client = createHttpClient();
    try {
      final payload = jsonDecode(
          await httpGetText(client, url, provider: 'YouTube oEmbed'));
      final map = Map<String, dynamic>.from(payload as Map);
      return SavedYouTubeVideo(
          videoId: validId,
          athleteName: athleteName,
          title: '${map['title'] ?? 'YouTube-videó'}',
          thumbnailUrl: SavedYouTubeVideo.safeThumbnailUrl(
              '${map['thumbnail_url'] ?? ''}', validId),
          savedAt: DateTime.now());
    } finally {
      client.close(force: true);
    }
  }
}

class AthleteVideoPlaylist {
  const AthleteVideoPlaylist(
      {this.videos = const [], this.unassigned = const []});
  final List<SavedYouTubeVideo> videos;
  final List<SavedYouTubeVideo> unassigned;
  List<SavedYouTubeVideo> forAthlete(String name) =>
      videos.where((video) => video.athleteName == name).toList();
  AthleteVideoPlaylist add(SavedYouTubeVideo video) =>
      AthleteVideoPlaylist(videos: [
        ...videos.where((item) => !(item.athleteName == video.athleteName &&
            item.videoId == video.videoId)),
        video
      ], unassigned: unassigned);
  AthleteVideoPlaylist remove(SavedYouTubeVideo video) => AthleteVideoPlaylist(
      videos: videos.where((item) => item != video).toList(),
      unassigned: unassigned.where((item) => item != video).toList());
  Map<String, dynamic> toJson() => {
        'version': 2,
        'videos': videos.map((v) => v.toJson()).toList(),
        'unassigned': unassigned.map((v) => v.toJson()).toList()
      };
  factory AthleteVideoPlaylist.fromJson(dynamic raw) {
    if (raw is List) {
      return AthleteVideoPlaylist(
          unassigned: raw
              .whereType<String>()
              .map(YouTubeVideoId.parse)
              .whereType<String>()
              .map((id) => SavedYouTubeVideo(
                  videoId: id,
                  athleteName: '',
                  title: 'Korábban mentett YouTube-videó',
                  thumbnailUrl: SavedYouTubeVideo.defaultThumbnailUrl(id),
                  savedAt: DateTime.now()))
              .toList());
    }
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    List<SavedYouTubeVideo> parse(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map((v) =>
                SavedYouTubeVideo.tryFromJson(Map<String, dynamic>.from(v)))
            .whereType<SavedYouTubeVideo>()
            .toList()
        : const [];
    return AthleteVideoPlaylist(
        videos: parse(map['videos']), unassigned: parse(map['unassigned']));
  }
}
