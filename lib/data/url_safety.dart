/// Igaz, ha az [url] megnyitható webcím: `http` vagy `https` séma, nem üres
/// host, és nincs benne beágyazott felhasználónév/jelszó.
///
/// Külső adatforrásból érkező linkeket (hírek, képek, videók) csak ezen a
/// szűrőn átengedve szabad megnyitni vagy betölteni; a `file://`, UNC,
/// `javascript:` és egyéb sémák így kiesnek.
bool isSafeWebUrl(String url) {
  final text = url.trim();
  if (text.isEmpty || text.contains(RegExp(r'[\\\x00-\x1f]'))) return false;
  final uri = Uri.tryParse(text);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  return true;
}
