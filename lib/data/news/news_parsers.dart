import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../json_util.dart';
import '../url_safety.dart';
import 'news_models.dart';

/// Egy letöltött hírfolyam feldolgozása a forrás formátuma szerint.
///
/// Tiszta, felső szintű függvény: csak küldhető adatot kap és ad vissza,
/// így `Isolate.run`-ban is futtatható.
List<NewsArticle> parseNewsFeed(
  String body,
  NewsSource source, {
  required DateTime fetchedAt,
}) => source.format == NewsSourceFormat.foxPageFeed
    ? FoxPageFeedParser.parse(body, source, fetchedAt: fetchedAt)
    : RssParser.parse(body, source, fetchedAt: fetchedAt);

/// [parseNewsFeed] külön isolate-ban: a nagy XML/JSON feldolgozása és a
/// HTML-összefoglalók tisztítása ne akassza meg a felületet.
Future<List<NewsArticle>> parseNewsFeedAsync(
  String body,
  NewsSource source, {
  required DateTime fetchedAt,
}) => Isolate.run(() => parseNewsFeed(body, source, fetchedAt: fetchedAt));

class RssParser {
  static List<NewsArticle> parse(
    String xml,
    NewsSource source, {
    DateTime? fetchedAt,
  }) {
    final document = XmlDocument.parse(xml);
    final fetched = fetchedAt ?? DateTime.now();
    final entries = document.descendants.whereType<XmlElement>().where(
      (element) =>
          element.name.local == 'item' || element.name.local == 'entry',
    );
    final articles = <NewsArticle>[];
    for (final entry in entries) {
      final title = _childText(entry, const ['title']);
      final url = _link(entry);
      if (title.isEmpty || url.isEmpty) continue;
      final externalId = _childText(entry, const ['guid', 'id']);
      final rawSummary = _childText(entry, const [
        'description',
        'summary',
        'encoded',
        'content',
      ]);
      final summary = source.summaryEnabled ? cleanSummary(rawSummary) : '';
      final parsedDate = parseNewsDate(
        _childText(entry, const ['pubDate', 'published', 'updated', 'date']),
      );
      articles.add(
        NewsArticle(
          dedupeKey: dedupeKey(
            url: url,
            externalId: externalId,
            source: source,
          ),
          sourceId: source.id,
          sourceName: source.name,
          sport: source.sport,
          externalId: externalId,
          title: _plainText(title),
          summary: summary,
          url: url,
          imageUrl: _image(entry, rawSummary),
          author: _plainText(_childText(entry, const ['creator', 'author'])),
          publishedAt: parsedDate ?? fetched,
          publishedAtParsed: parsedDate != null,
          fetchedAt: fetched,
        ),
      );
    }
    return articles;
  }

  static String cleanSummary(String value, {int maxLength = 350}) {
    if (value.trim().isEmpty) return '';
    final fragment = html_parser.parseFragment(value);
    for (final element in fragment.querySelectorAll('script,style,noscript')) {
      element.remove();
    }
    final text = (fragment.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxLength) return text;
    final shortened = text.substring(0, maxLength).trimRight();
    final lastSpace = shortened.lastIndexOf(' ');
    return '${lastSpace > maxLength - 50 ? shortened.substring(0, lastSpace) : shortened}…';
  }

  static String dedupeKey({
    required String url,
    required String externalId,
    required NewsSource source,
  }) {
    final normalizedUrl = canonicalUrl(url);
    if (normalizedUrl.isNotEmpty) return 'url:$normalizedUrl';
    return 'guid:${source.id}:${externalId.trim()}';
  }

  static String canonicalUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value.trim();
    final filtered = Map<String, String>.from(uri.queryParameters)
      ..removeWhere(
        (key, _) =>
            key.toLowerCase().startsWith('utm_') ||
            const {
              'cmpid',
              'cid',
              'source',
              'rss',
              'soc_src',
            }.contains(key.toLowerCase()),
      );
    final keys = filtered.keys.toList()..sort();
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      userInfo: uri.userInfo,
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: keys.isEmpty
          ? null
          : {for (final key in keys) key: filtered[key]!},
    ).toString();
  }

  static String _link(XmlElement entry) {
    for (final child in entry.childElements.where(
      (element) => const {'link', 'origLink'}.contains(element.name.local),
    )) {
      final href = child.getAttribute('href')?.trim() ?? '';
      if (isSafeWebUrl(href)) return href;
      final text = child.innerText.trim();
      if (isSafeWebUrl(text)) return text;
    }
    return '';
  }

  static String _image(XmlElement entry, String rawSummary) {
    for (final element in entry.descendants.whereType<XmlElement>()) {
      final local = element.name.local.toLowerCase();
      if (local == 'thumbnail' || local == 'content' || local == 'enclosure') {
        final url = element.getAttribute('url') ?? element.getAttribute('href');
        final type = element.getAttribute('type') ?? '';
        final medium = element.getAttribute('medium') ?? '';
        if (url != null &&
            isSafeWebUrl(url) &&
            (local == 'thumbnail' ||
                type.startsWith('image') ||
                medium == 'image')) {
          return url;
        }
      }
    }
    final fragment = html_parser.parseFragment(rawSummary);
    return _safeUrl(fragment.querySelector('img')?.attributes['src'] ?? '');
  }

  static String _childText(XmlElement entry, Iterable<String> names) {
    final normalizedNames = names.map((name) => name.toLowerCase()).toSet();
    for (final child in entry.childElements) {
      final localName = child.name.local.toLowerCase();
      if (normalizedNames.contains(localName)) {
        if (localName == 'author') {
          final name = child.childElements
              .where((element) => element.name.local == 'name')
              .firstOrNull;
          return name?.innerText.trim() ?? child.innerText.trim();
        }
        return child.innerText.trim();
      }
    }
    return '';
  }

  static String _plainText(String value) =>
      html_parser
          .parseFragment(value)
          .text
          ?.replaceAll(RegExp(r'\s+'), ' ')
          .trim() ??
      '';
}

class FoxPageFeedParser {
  static List<NewsArticle> parse(
    String json,
    NewsSource source, {
    DateTime? fetchedAt,
  }) {
    final data = jsonMap(jsonMap(jsonDecode(json))['data']);
    if (data['results'] is! List) return const [];
    final fetched = fetchedAt ?? DateTime.now();
    final articles = <NewsArticle>[];
    for (final raw in jsonMapList(data['results'])) {
      if (raw['component_type'] != 'news_article') continue;
      final title = '${raw['title'] ?? ''}'.trim();
      final urls = jsonMap(raw['urls']);
      final rawUrl =
          '${raw['canonical_url'] ?? urls['url'] ?? urls['original_url'] ?? ''}'
              .trim();
      final url = _absoluteUrl(rawUrl);
      if (title.isEmpty || url.isEmpty) continue;
      final thumbnail = jsonMap(raw['thumbnail']);
      final parsedDate = parseNewsDate(
        '${urls['original_publish_date'] ?? raw['last_published_date'] ?? raw['original_import_date'] ?? ''}',
      );
      final externalId = '${raw['id'] ?? raw['external_id'] ?? ''}'.trim();
      articles.add(
        NewsArticle(
          dedupeKey: RssParser.dedupeKey(
            url: url,
            externalId: externalId,
            source: source,
          ),
          sourceId: source.id,
          sourceName: _publisher(raw, url, source.name),
          sport: source.sport,
          externalId: externalId,
          title: RssParser._plainText(title),
          summary: RssParser.cleanSummary(
            '${raw['dek'] ?? raw['description'] ?? ''}',
          ),
          url: url,
          imageUrl: _safeUrl(
            '${thumbnail['url'] ?? raw['external_thumbnail'] ?? ''}',
          ),
          author: _authors(raw['authors']),
          publishedAt: parsedDate ?? fetched,
          publishedAtParsed: parsedDate != null,
          fetchedAt: fetched,
        ),
      );
    }
    articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return articles;
  }

  /// Abszolút `http(s)` cím a feed linkjéből. Protokoll-relatív (`//…`) és
  /// séma nélküli (`foxsports.com/…`) alakot `https`-re egészít ki; minden
  /// más sémát (`file://`, UNC, `javascript:` stb.) üres szövegre cserél, így
  /// a cikk kimarad.
  static String _absoluteUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final String candidate;
    if (text.startsWith('//')) {
      candidate = 'https:$text';
    } else if (!text.contains('://') && !text.contains(':')) {
      candidate = 'https://$text';
    } else {
      candidate = text;
    }
    return _safeUrl(candidate);
  }

  static String _publisher(
    Map<String, dynamic> raw,
    String url,
    String fallback,
  ) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host == 'foxsports.com' || host.endsWith('.foxsports.com')) {
      return fallback;
    }
    final source = jsonMap(raw['source']);
    final urls = jsonMap(raw['urls']);
    final value =
        '${raw['external_source'] ?? source['label'] ?? urls['original_publisher'] ?? ''}'
            .trim();
    return value.isEmpty ? fallback : value;
  }

  static String _authors(Object? value) {
    if (value is! List) return '';
    return jsonMapList(value)
        .map(
          (author) =>
              '${author['display_name'] ?? author['name'] ?? author['label'] ?? ''}'
                  .trim(),
        )
        .where((author) => author.isNotEmpty)
        .join(', ');
  }
}

/// A cím változatlanul, ha biztonságos `http(s)` webcím; különben üres.
String _safeUrl(String value) {
  final text = value.trim();
  return isSafeWebUrl(text) ? text : '';
}

DateTime? parseNewsDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso.toLocal();
  try {
    return HttpDate.parse(text).toLocal();
  } catch (_) {
    // RSS RFC 822 dates often use numeric offsets (for example -0400),
    // while HttpDate.parse only accepts HTTP's GMT form.
  }
  const namedOffsets = {
    'UTC': '+0000',
    'GMT': '+0000',
    'EST': '-0500',
    'EDT': '-0400',
    'CST': '-0600',
    'CDT': '-0500',
    'MST': '-0700',
    'MDT': '-0600',
    'PST': '-0800',
    'PDT': '-0700',
  };
  final namedZone = RegExp(r'\s+([A-Za-z]{3})$').firstMatch(text);
  final namedOffset = namedZone == null
      ? null
      : namedOffsets[namedZone.group(1)!.toUpperCase()];
  if (namedZone != null && namedOffset != null) {
    return parseNewsDate(
      text.replaceRange(namedZone.start, null, ' $namedOffset'),
    );
  }
  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([+-])(\d{2})(\d{2})$',
  ).firstMatch(text);
  if (match == null) return null;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  final offsetMinutes =
      int.parse(match.group(8)!) * 60 + int.parse(match.group(9)!);
  final signedOffset = match.group(7) == '+' ? offsetMinutes : -offsetMinutes;
  final localAtOffset = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
  return localAtOffset.subtract(Duration(minutes: signedOffset)).toLocal();
}
