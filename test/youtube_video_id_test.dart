import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/youtube_video_id.dart';

void main() {
  test('extracts a YouTube id from common URLs and bare ids', () {
    expect(YouTubeVideoId.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ');
    expect(YouTubeVideoId.parse('https://youtu.be/dQw4w9WgXcQ?t=10'),
        'dQw4w9WgXcQ');
    expect(YouTubeVideoId.parse('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(YouTubeVideoId.parse('not a video'), isNull);
  });
}
