import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

import 'api_sports.dart' show normalizeAthleteName;

const newsRefreshInterval = Duration(minutes: 20);

enum NewsSourceFormat { rss, foxPageFeed }

class NewsSource {
  const NewsSource({
    required this.id,
    required this.name,
    required this.sport,
    required this.url,
    required this.homepage,
    this.enabledByDefault = true,
    this.summaryEnabled = true,
    this.termsNote = '',
    this.format = NewsSourceFormat.rss,
  });

  final String id;
  final String name;
  final String sport;
  final String url;
  final String homepage;
  final bool enabledByDefault;
  final bool summaryEnabled;
  final String termsNote;
  final NewsSourceFormat format;
}

const newsSources = <NewsSource>[
  NewsSource(
    id: 'fox_nba',
    name: 'FOX Sports',
    sport: 'NBA',
    url:
        'https://prod-api.foxsports.com/fs/feed?uri=basketball%2Fnba%2Fleague%2F1&component_type=news_article&size=100&from=0',
    homepage: 'https://www.foxsports.com/nba',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A FOX-oldal aktuális hírfolyama; kérésenként a legfrissebb 100 NBA-cikk.',
  ),
  NewsSource(
    id: 'fox_wnba',
    name: 'FOX Sports',
    sport: 'WNBA',
    url:
        'https://prod-api.foxsports.com/fs/feed?uri=basketball%2Fwnba%2Fleague%2F1&component_type=news_article&size=100&from=0',
    homepage: 'https://www.foxsports.com/wnba',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A régi FOX WNBA RSS elavult. Ez a forrás a FOX WNBA-oldal aktuális hírfolyamát használja, kérésenként 100 cikkel.',
  ),
  NewsSource(
    id: 'fox_soccer',
    name: 'FOX Sports',
    sport: 'Foci',
    url:
        'https://prod-api.foxsports.com/fs/feed?component_type=news_article&size=100&from=0&tags=fs%2Fsoccer%2Csoccer%2Fepl%2Fleague%2F1%2Csoccer%2Fmls%2Fleague%2F5%2Csoccer%2Fucl%2Fleague%2F7%2Csoccer%2Feuropa%2Fleague%2F8',
    homepage: 'https://www.foxsports.com/soccer',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A FOX-oldal aktuális hírfolyama; kérésenként a legfrissebb 100 focicikk.',
  ),
  NewsSource(
    id: 'fox_tennis',
    name: 'FOX Sports',
    sport: 'Tenisz',
    url:
        'https://prod-api.foxsports.com/fs/feed?component_type=news_article&size=100&from=0&tags=fs%2Fatp%2Cfs%2Fwta',
    homepage: 'https://www.foxsports.com/tennis',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A régi FOX tenisz RSS több éves elemeket is adott. Ez a forrás az ATP/WTA oldal aktuális hírfolyamát használja, kérésenként 100 cikkel.',
  ),
  NewsSource(
    id: 'cbs_nba',
    name: 'CBS Sports',
    sport: 'NBA',
    url: 'https://www.cbssports.com/rss/headlines/nba',
    homepage: 'https://www.cbssports.com/nba/',
  ),
  NewsSource(
    id: 'cbs_soccer',
    name: 'CBS Sports',
    sport: 'Foci',
    url: 'https://www.cbssports.com/rss/headlines/soccer',
    homepage: 'https://www.cbssports.com/soccer/',
  ),
  NewsSource(
    id: 'cbs_tennis',
    name: 'CBS Sports',
    sport: 'Tenisz',
    url: 'https://www.cbssports.com/rss/headlines/tennis',
    homepage: 'https://www.cbssports.com/tennis/',
  ),
  NewsSource(
    id: 'espn_nba',
    name: 'ESPN',
    sport: 'NBA',
    url: 'https://www.espn.com/espn/rss/nba/news',
    homepage: 'https://www.espn.com/nba/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_wnba',
    name: 'ESPN',
    sport: 'WNBA',
    url: 'https://www.espn.com/espn/rss/wnba/news',
    homepage: 'https://www.espn.com/wnba/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_soccer',
    name: 'ESPN',
    sport: 'Foci',
    url: 'https://www.espn.com/espn/rss/soccer/news',
    homepage: 'https://www.espn.com/soccer/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_tennis',
    name: 'ESPN',
    sport: 'Tenisz',
    url: 'https://www.espn.com/espn/rss/tennis/news',
    homepage: 'https://www.espn.com/tennis/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'guardian_football',
    name: 'The Guardian',
    sport: 'Foci',
    url: 'https://www.theguardian.com/football/rss',
    homepage: 'https://www.theguardian.com/football',
    enabledByDefault: false,
    termsNote: 'Személyes, nem kereskedelmi használatra kapcsolható be.',
  ),
  NewsSource(
    id: 'guardian_tennis',
    name: 'The Guardian',
    sport: 'Tenisz',
    url: 'https://www.theguardian.com/sport/tennis/rss',
    homepage: 'https://www.theguardian.com/sport/tennis',
    enabledByDefault: false,
    termsNote: 'Személyes, nem kereskedelmi használatra kapcsolható be.',
  ),
];

class NewsArticle {
  const NewsArticle({
    required this.dedupeKey,
    required this.sourceId,
    required this.sourceName,
    required this.sport,
    required this.title,
    required this.url,
    required this.publishedAt,
    required this.fetchedAt,
    this.id,
    this.externalId = '',
    this.summary = '',
    this.imageUrl = '',
    this.author = '',
  });

  final int? id;
  final String dedupeKey;
  final String sourceId;
  final String sourceName;
  final String sport;
  final String externalId;
  final String title;
  final String summary;
  final String url;
  final String imageUrl;
  final String author;
  final DateTime publishedAt;
  final DateTime fetchedAt;

  String get searchText => normalizeAthleteName('$title $summary');
}

class NewsSourceState {
  const NewsSourceState({
    required this.source,
    required this.enabled,
    this.lastSuccessAt,
    this.lastError = '',
    this.etag = '',
    this.lastModified = '',
  });

  final NewsSource source;
  final bool enabled;
  final DateTime? lastSuccessAt;
  final String lastError;
  final String etag;
  final String lastModified;
}

class RssFetchResult {
  const RssFetchResult({
    this.articles = const [],
    this.notModified = false,
    this.etag = '',
    this.lastModified = '',
  });

  final List<NewsArticle> articles;
  final bool notModified;
  final String etag;
  final String lastModified;
}

abstract class NewsProvider {
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  });

  void close();
}

class RssNewsProvider implements NewsProvider {
  RssNewsProvider({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 12);
  }

  final HttpClient _client;
  static const _requestTimeout = Duration(seconds: 25);

  @override
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  }) async {
    final request = await _client
        .getUrl(Uri.parse(source.url))
        .timeout(_requestTimeout);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Courtboard/0.6 RSS reader',
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      source.format == NewsSourceFormat.foxPageFeed
          ? 'application/json'
          : 'application/rss+xml, application/atom+xml, application/xml, text/xml',
    );
    if (etag.isNotEmpty) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
    }
    if (lastModified.isNotEmpty) {
      request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
    }
    final response = await request.close().timeout(_requestTimeout);
    final resultEtag = response.headers.value(HttpHeaders.etagHeader) ?? etag;
    final resultModified =
        response.headers.value(HttpHeaders.lastModifiedHeader) ?? lastModified;
    if (response.statusCode == HttpStatus.notModified) {
      return RssFetchResult(
        notModified: true,
        etag: resultEtag,
        lastModified: resultModified,
      );
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'RSS hiba: ${response.statusCode}',
        uri: Uri.parse(source.url),
      );
    }
    return RssFetchResult(
      articles: source.format == NewsSourceFormat.foxPageFeed
          ? FoxPageFeedParser.parse(body, source, fetchedAt: DateTime.now())
          : RssParser.parse(body, source, fetchedAt: DateTime.now()),
      etag: resultEtag,
      lastModified: resultModified,
    );
  }

  @override
  void close() => _client.close(force: true);
}

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
      final publishedAt =
          parseNewsDate(
            _childText(entry, const [
              'pubDate',
              'published',
              'updated',
              'date',
            ]),
          ) ??
          fetched;
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
          publishedAt: publishedAt,
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
      if (href.startsWith('http')) return href;
      final text = child.innerText.trim();
      if (text.startsWith('http')) return text;
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
            url.startsWith('http') &&
            (local == 'thumbnail' ||
                type.startsWith('image') ||
                medium == 'image')) {
          return url;
        }
      }
    }
    final fragment = html_parser.parseFragment(rawSummary);
    return fragment.querySelector('img')?.attributes['src'] ?? '';
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
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is! Map || data['results'] is! List) return const [];
    final fetched = fetchedAt ?? DateTime.now();
    final articles = <NewsArticle>[];
    for (final raw in data['results'] as List) {
      if (raw is! Map || raw['component_type'] != 'news_article') continue;
      final title = '${raw['title'] ?? ''}'.trim();
      final urls = raw['urls'] is Map ? raw['urls'] as Map : const {};
      final rawUrl =
          '${raw['canonical_url'] ?? urls['url'] ?? urls['original_url'] ?? ''}'
              .trim();
      final url = _absoluteUrl(rawUrl);
      if (title.isEmpty || url.isEmpty) continue;
      final thumbnail = raw['thumbnail'] is Map
          ? raw['thumbnail'] as Map
          : const {};
      final publishedAt =
          parseNewsDate(
            '${urls['original_publish_date'] ?? raw['last_published_date'] ?? raw['original_import_date'] ?? ''}',
          ) ??
          fetched;
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
          imageUrl: '${thumbnail['url'] ?? raw['external_thumbnail'] ?? ''}'
              .trim(),
          author: _authors(raw['authors']),
          publishedAt: publishedAt,
          fetchedAt: fetched,
        ),
      );
    }
    articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return articles;
  }

  static String _absoluteUrl(String value) {
    if (value.isEmpty) return '';
    if (value.startsWith('//')) return 'https:$value';
    if (!value.contains('://')) return 'https://$value';
    return value;
  }

  static String _publisher(Map raw, String url, String fallback) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host == 'foxsports.com' || host.endsWith('.foxsports.com')) {
      return fallback;
    }
    final source = raw['source'] is Map ? raw['source'] as Map : const {};
    final urls = raw['urls'] is Map ? raw['urls'] as Map : const {};
    final value =
        '${raw['external_source'] ?? source['label'] ?? urls['original_publisher'] ?? ''}'
            .trim();
    return value.isEmpty ? fallback : value;
  }

  static String _authors(Object? value) {
    if (value is! List) return '';
    return value
        .whereType<Map>()
        .map(
          (author) =>
              '${author['display_name'] ?? author['name'] ?? author['label'] ?? ''}'
                  .trim(),
        )
        .where((author) => author.isNotEmpty)
        .join(', ');
  }
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

class NewsStore {
  NewsStore({String? path}) : _path = path ?? defaultPath();

  final String _path;
  Database? _database;

  static String defaultPath() {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    return '$appData/Courtboard/courtboard_news.sqlite';
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    if (_path != inMemoryDatabasePath) {
      await Directory(File(_path).parent.path).create(recursive: true);
    }
    _database = await databaseFactoryFfi.openDatabase(
      _path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    await _seedSources(_database!);
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE news_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sport TEXT NOT NULL,
        url TEXT NOT NULL,
        homepage TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        terms_note TEXT NOT NULL DEFAULT '',
        last_attempt_at INTEGER,
        last_success_at INTEGER,
        last_error TEXT NOT NULL DEFAULT '',
        etag TEXT NOT NULL DEFAULT '',
        last_modified TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE news_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dedupe_key TEXT NOT NULL UNIQUE,
        source_id TEXT NOT NULL,
        source_name TEXT NOT NULL,
        external_id TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL,
        image_url TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        search_text TEXT NOT NULL,
        published_at INTEGER NOT NULL,
        fetched_at INTEGER NOT NULL,
        FOREIGN KEY(source_id) REFERENCES news_sources(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE news_item_sports (
        item_id INTEGER NOT NULL,
        sport TEXT NOT NULL,
        PRIMARY KEY(item_id, sport),
        FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE news_item_sources (
        item_id INTEGER NOT NULL,
        source_id TEXT NOT NULL,
        PRIMARY KEY(item_id, source_id),
        FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE,
        FOREIGN KEY(source_id) REFERENCES news_sources(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_news_items_published ON news_items(published_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_news_sports_sport ON news_item_sports(sport)',
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // The first parser used the fetch time when an RSS date contained a
      // numeric offset or an ESPN-style named timezone. Remove only those
      // demonstrably corrupted fallback-date rows; the next refresh restores
      // them with their real publication date.
      await db.delete(
        'news_items',
        where:
            "(source_id LIKE 'fox_%' OR source_id LIKE 'cbs_%' OR source_id LIKE 'espn_%') "
            'AND ABS(published_at - fetched_at) < 60000',
      );
      // Every FOX source now uses the fresher page JSON feed instead of the
      // optimized RSS endpoint. Force an immediate request with clean HTTP
      // validators after the source URLs are reseeded.
      await db.update('news_sources', {
        'last_success_at': null,
        'etag': '',
        'last_modified': '',
      }, where: "id LIKE 'fox_%'");
    }
  }

  Future<void> _seedSources(Database db) async {
    final batch = db.batch();
    for (final source in newsSources) {
      batch.rawInsert(
        '''
        INSERT INTO news_sources
          (id, name, sport, url, homepage, enabled, terms_note)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          sport = excluded.sport,
          url = excluded.url,
          homepage = excluded.homepage,
          terms_note = excluded.terms_note
      ''',
        [
          source.id,
          source.name,
          source.sport,
          source.url,
          source.homepage,
          source.enabledByDefault ? 1 : 0,
          source.termsNote,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<NewsSourceState>> sourceStates() async {
    final db = await database;
    final rows = await db.query('news_sources', orderBy: 'name, sport');
    final byId = {for (final source in newsSources) source.id: source};
    return rows
        .where((row) => byId.containsKey(row['id']))
        .map(
          (row) => NewsSourceState(
            source: byId[row['id']]!,
            enabled: row['enabled'] == 1,
            lastSuccessAt: _fromMillis(row['last_success_at']),
            lastError: '${row['last_error'] ?? ''}',
            etag: '${row['etag'] ?? ''}',
            lastModified: '${row['last_modified'] ?? ''}',
          ),
        )
        .toList();
  }

  Future<void> setSourceEnabled(String sourceId, bool enabled) async {
    final db = await database;
    await db.update(
      'news_sources',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [sourceId],
    );
  }

  Future<void> markSourceResult(
    String sourceId, {
    required bool success,
    String error = '',
    String etag = '',
    String lastModified = '',
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'news_sources',
      {
        'last_attempt_at': now,
        if (success) 'last_success_at': now,
        'last_error': success ? '' : error,
        if (etag.isNotEmpty) 'etag': etag,
        if (lastModified.isNotEmpty) 'last_modified': lastModified,
      },
      where: 'id = ?',
      whereArgs: [sourceId],
    );
  }

  Future<int> saveArticles(List<NewsArticle> articles) async {
    if (articles.isEmpty) return 0;
    final db = await database;
    var added = 0;
    await db.transaction((txn) async {
      for (final article in articles) {
        final existing = await txn.query(
          'news_items',
          columns: ['id'],
          where: 'dedupe_key = ?',
          whereArgs: [article.dedupeKey],
          limit: 1,
        );
        int id;
        if (existing.isEmpty) {
          id = await txn.insert('news_items', {
            'dedupe_key': article.dedupeKey,
            'source_id': article.sourceId,
            'source_name': article.sourceName,
            'external_id': article.externalId,
            'title': article.title,
            'summary': article.summary,
            'url': article.url,
            'image_url': article.imageUrl,
            'author': article.author,
            'search_text': article.searchText,
            'published_at': article.publishedAt.millisecondsSinceEpoch,
            'fetched_at': article.fetchedAt.millisecondsSinceEpoch,
          });
          added++;
        } else {
          id = existing.first['id'] as int;
          await txn.update(
            'news_items',
            {
              'title': article.title,
              if (article.summary.isNotEmpty) 'summary': article.summary,
              if (article.imageUrl.isNotEmpty) 'image_url': article.imageUrl,
              if (article.author.isNotEmpty) 'author': article.author,
              'search_text': article.searchText,
              'published_at': article.publishedAt.millisecondsSinceEpoch,
              'fetched_at': article.fetchedAt.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await txn.insert('news_item_sports', {
          'item_id': id,
          'sport': article.sport,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('news_item_sources', {
          'item_id': id,
          'source_id': article.sourceId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return added;
  }

  Future<List<NewsArticle>> query({
    String text = '',
    String sport = 'Mind',
    String sourceId = 'Mind',
    String athleteName = 'Mind',
    int limit = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (sport != 'Mind') {
      where.add('s.sport = ?');
      args.add(sport);
    }
    if (sourceId != 'Mind') {
      where.add('src.source_id = ?');
      args.add(sourceId);
    }
    final normalized = normalizeAthleteName(text);
    if (normalized.isNotEmpty) {
      where.add('n.search_text LIKE ?');
      args.add('%$normalized%');
    }
    if (athleteName != 'Mind') {
      final tokens = normalizeAthleteName(
        athleteName,
      ).split(' ').where((token) => token.length >= 3);
      for (final token in tokens) {
        where.add('n.search_text LIKE ?');
        args.add('%$token%');
      }
    }
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT n.*, COALESCE(s.sport, '') AS matched_sport
      FROM news_items n
      LEFT JOIN news_item_sports s ON s.item_id = n.id
      LEFT JOIN news_item_sources src ON src.item_id = n.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY n.id
      ORDER BY n.published_at DESC, n.id DESC
      LIMIT ?
    ''',
      [...args, limit],
    );
    return rows.map(_articleFromRow).toList();
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM news_items',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static NewsArticle _articleFromRow(Map<String, Object?> row) => NewsArticle(
    id: row['id'] as int?,
    dedupeKey: '${row['dedupe_key']}',
    sourceId: '${row['source_id']}',
    sourceName: '${row['source_name']}',
    sport: '${row['matched_sport']}',
    externalId: '${row['external_id'] ?? ''}',
    title: '${row['title']}',
    summary: '${row['summary'] ?? ''}',
    url: '${row['url']}',
    imageUrl: '${row['image_url'] ?? ''}',
    author: '${row['author'] ?? ''}',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(
      row['published_at'] as int,
      isUtc: false,
    ),
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(
      row['fetched_at'] as int,
      isUtc: false,
    ),
  );

  static DateTime? _fromMillis(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: false)
      : null;
}

class NewsRefreshReport {
  const NewsRefreshReport({
    required this.newArticles,
    required this.updatedSources,
    this.errors = const {},
    this.skipped = false,
  });

  final int newArticles;
  final int updatedSources;
  final Map<String, String> errors;
  final bool skipped;
}

class NewsRepository {
  NewsRepository({NewsStore? store, NewsProvider? provider})
    : store = store ?? NewsStore(),
      _provider = provider ?? RssNewsProvider();

  final NewsStore store;
  final NewsProvider _provider;

  Future<NewsRefreshReport> refresh({bool force = false}) async {
    final states = (await store.sourceStates())
        .where((state) => state.enabled)
        .toList();
    final due = states.where((state) {
      if (force || state.lastSuccessAt == null) return true;
      return DateTime.now().difference(state.lastSuccessAt!) >=
          newsRefreshInterval;
    }).toList();
    if (due.isEmpty) {
      return const NewsRefreshReport(
        newArticles: 0,
        updatedSources: 0,
        skipped: true,
      );
    }
    var updatedSources = 0;
    final errors = <String, String>{};
    final savedCounts = await Future.wait(
      due.map((state) async {
        var saved = 0;
        try {
          final result = await _provider.fetch(
            state.source,
            etag: state.etag,
            lastModified: state.lastModified,
          );
          if (!result.notModified) {
            saved = await store.saveArticles(result.articles);
          }
          await store.markSourceResult(
            state.source.id,
            success: true,
            etag: result.etag,
            lastModified: result.lastModified,
          );
          updatedSources++;
        } catch (error) {
          final message = '$error';
          errors[state.source.id] = message;
          await store.markSourceResult(
            state.source.id,
            success: false,
            error: message,
          );
        }
        return saved;
      }),
    );
    final newArticles = savedCounts.fold<int>(
      0,
      (total, count) => total + count,
    );
    return NewsRefreshReport(
      newArticles: newArticles,
      updatedSources: updatedSources,
      errors: errors,
    );
  }

  Future<void> close() async {
    _provider.close();
    await store.close();
  }
}

bool newsMatchesAthlete(NewsArticle article, String athleteName) {
  final haystack = article.searchText.split(' ').toSet();
  final tokens = normalizeAthleteName(
    athleteName,
  ).split(' ').where((token) => token.length >= 3).toList();
  return tokens.isNotEmpty && tokens.every(haystack.contains);
}
