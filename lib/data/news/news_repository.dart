import 'dart:io';

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/friendly_error.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/news/news_models.dart';
import 'package:courtboard/data/news/news_parsers.dart';
import 'package:courtboard/data/news/news_sources.dart';
import 'package:courtboard/data/news/news_store.dart';

abstract class NewsProvider {
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  });

  void close();
}

/// RSS/Atom és FOX-oldalfeed letöltő a közös [HttpService]-en át
/// (kapcsolat-újrahasznosítás, újrapróbálás 5xx/időtúllépés esetén),
/// feltételes (`ETag` / `Last-Modified`) kérésekkel.
class RssNewsProvider implements NewsProvider {
  RssNewsProvider({HttpService? http}) : _http = http ?? HttpService.shared;

  final HttpService _http;
  static const _requestTimeout = Duration(seconds: 25);

  @override
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  }) async {
    final response = await _http.getResponse(
      Uri.parse(source.url),
      provider: source.name,
      timeout: _requestTimeout,
      headers: {
        HttpHeaders.userAgentHeader: 'Courtboard/0.9 RSS reader',
        HttpHeaders.acceptHeader: source.format == NewsSourceFormat.foxPageFeed
            ? 'application/json'
            : 'application/rss+xml, application/atom+xml, application/xml, text/xml',
        if (etag.isNotEmpty) HttpHeaders.ifNoneMatchHeader: etag,
        if (lastModified.isNotEmpty)
          HttpHeaders.ifModifiedSinceHeader: lastModified,
      },
    );
    final resultEtag = response.etag ?? etag;
    final resultModified = response.lastModified ?? lastModified;
    if (response.notModified) {
      return RssFetchResult(
        notModified: true,
        etag: resultEtag,
        lastModified: resultModified,
      );
    }
    return RssFetchResult(
      articles: await parseNewsFeedAsync(
        response.body,
        source,
        fetchedAt: DateTime.now(),
      ),
      etag: resultEtag,
      lastModified: resultModified,
    );
  }

  /// A közös kliens nyitva marad; nincs mit lezárni.
  @override
  void close() {}
}

class NewsRepository {
  NewsRepository({
    NewsStore? store,
    NewsProvider? provider,
    this.retention = const NewsRetention(),
  }) : store = store ?? NewsStore(),
       _provider = provider ?? RssNewsProvider();

  final NewsStore store;
  final NewsProvider _provider;

  /// A frissítés utáni takarítás szabálya.
  final NewsRetention retention;

  /// A folyamatban lévő frissítés: a Hírek oldal és a háttérfigyelő
  /// egyszerre indított kérése nem tölti le kétszer ugyanazt.
  Future<NewsRefreshReport>? _inFlight;

  Future<NewsRefreshReport> refresh({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _refresh(force: force);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<NewsRefreshReport> _refresh({bool force = false}) async {
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
          final message = friendlyError(error);
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
    var removed = 0;
    try {
      removed = await store.applyRetention(retention);
    } catch (_) {
      // A takarítás hibája nem ronthatja el a sikeres frissítést.
    }
    return NewsRefreshReport(
      newArticles: newArticles,
      updatedSources: updatedSources,
      errors: errors,
      removedArticles: removed,
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
