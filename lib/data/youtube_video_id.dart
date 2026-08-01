class YouTubeVideoId {
  const YouTubeVideoId._();

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String? parse(String input) {
    final value = input.trim();
    if (_id.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    String? candidate;
    if (uri.host.endsWith('youtu.be')) {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.host.contains('youtube.com')) {
      candidate = uri.queryParameters['v'];
      if (candidate == null &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'shorts') {
        candidate = uri.pathSegments[1];
      }
    }
    return candidate != null && _id.hasMatch(candidate) ? candidate : null;
  }
}
