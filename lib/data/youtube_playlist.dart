import 'dart:convert';
import 'dart:io';

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
      SavedYouTubeVideo(
          videoId: '${json['videoId']}',
          athleteName: '${json['athleteName']}',
          title: '${json['title']}',
          thumbnailUrl: '${json['thumbnailUrl']}',
          savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime.now());
}

class YouTubeOEmbed {
  static Future<SavedYouTubeVideo> resolve(
      String videoId, String athleteName) async {
    final url = Uri.https('www.youtube.com', '/oembed',
        {'url': 'https://www.youtube.com/watch?v=$videoId', 'format': 'json'});
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != 200) {
        throw HttpException('oEmbed HTTP ${response.statusCode}');
      }
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      final map = Map<String, dynamic>.from(payload as Map);
      return SavedYouTubeVideo(
          videoId: videoId,
          athleteName: athleteName,
          title: '${map['title'] ?? 'YouTube-videó'}',
          thumbnailUrl:
              '${map['thumbnail_url'] ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg'}',
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
      unassigned: unassigned);
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
              .map((id) => SavedYouTubeVideo(
                  videoId: id,
                  athleteName: '',
                  title: 'Korábban mentett YouTube-videó',
                  thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                  savedAt: DateTime.now()))
              .toList());
    }
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    List<SavedYouTubeVideo> parse(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map(
                (v) => SavedYouTubeVideo.fromJson(Map<String, dynamic>.from(v)))
            .toList()
        : const [];
    return AthleteVideoPlaylist(
        videos: parse(map['videos']), unassigned: parse(map['unassigned']));
  }
}
