import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/youtube_playlist.dart';

void main() {
  test('migrates legacy global IDs to an unassigned list without sharing them',
      () {
    final playlist = AthleteVideoPlaylist.fromJson(['dQw4w9WgXcQ']);
    expect(playlist.unassigned.single.videoId, 'dQw4w9WgXcQ');
    expect(playlist.forAthlete('Szoboszlai Dominik'), isEmpty);
  });

  test('persists rich athlete-scoped video metadata', () {
    final video = SavedYouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        athleteName: 'Szoboszlai Dominik',
        title: 'Tesztcím',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        savedAt: DateTime.utc(2026, 8, 1));
    final restored = AthleteVideoPlaylist.fromJson(
        AthleteVideoPlaylist(videos: [video]).toJson());
    expect(restored.forAthlete('Szoboszlai Dominik').single.title, 'Tesztcím');
  });
}
