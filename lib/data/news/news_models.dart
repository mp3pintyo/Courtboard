import 'package:courtboard/data/athlete_names.dart';

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
    this.publishedAtParsed = true,
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

  /// Igaz, ha a [publishedAt] a hírfolyamból értelmezett dátum; hamis, ha a
  /// forrás nem adott (értelmezhető) dátumot, és a letöltés ideje került be.
  /// Ilyenkor egy későbbi frissítés nem írhatja felül a tárolt dátumot.
  final bool publishedAtParsed;

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

class NewsRefreshReport {
  const NewsRefreshReport({
    required this.newArticles,
    required this.updatedSources,
    this.errors = const {},
    this.skipped = false,
    this.removedArticles = 0,
  });

  final int newArticles;
  final int updatedSources;
  final Map<String, String> errors;
  final bool skipped;

  /// A megőrzési szabály miatt törölt régi cikkek száma.
  final int removedArticles;
}
