import 'dart:io';

import 'package:courtboard/data/news.dart';
import 'package:courtboard/news_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeNewsProvider implements NewsProvider {
  int calls = 0;

  @override
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  }) async {
    calls++;
    return const RssFetchResult(notModified: true);
  }

  @override
  void close() {}
}

class _ArticleNewsProvider implements NewsProvider {
  @override
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  }) async {
    final now = DateTime.now();
    return RssFetchResult(
      articles: [
        NewsArticle(
          dedupeKey: 'url:https://example.com/${source.id}',
          sourceId: source.id,
          sourceName: source.name,
          sport: source.sport,
          title: source.id,
          url: 'https://example.com/${source.id}',
          publishedAt: now,
          fetchedAt: now,
        ),
      ],
    );
  }

  @override
  void close() {}
}

void main() {
  const fox = NewsSource(
    id: 'fox_nba',
    name: 'FOX Sports',
    sport: 'NBA',
    url: 'https://example.com/feed',
    homepage: 'https://example.com',
  );

  test('RSS parser cleans HTML, finds an image and canonicalizes the URL', () {
    final articles = RssParser.parse(
      '''
      <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel><item>
          <title>NBA &amp; WNBA update</title>
          <link>https://example.com/story?utm_source=rss&amp;keep=yes</link>
          <guid>story-1</guid>
          <pubDate>Sat, 01 Aug 2026 12:30:00 GMT</pubDate>
          <description><![CDATA[<p> First   paragraph. </p><script>bad()</script><style>.x{}</style><p>Second.</p>]]></description>
          <media:content url="https://example.com/image.jpg" type="image/jpeg" />
        </item></channel>
      </rss>
    ''',
      fox,
      fetchedAt: DateTime(2026, 8, 2),
    );

    expect(articles, hasLength(1));
    expect(articles.single.title, 'NBA & WNBA update');
    expect(articles.single.summary, 'First paragraph. Second.');
    expect(articles.single.summary, isNot(contains('bad')));
    expect(articles.single.imageUrl, 'https://example.com/image.jpg');
    expect(articles.single.dedupeKey, 'url:https://example.com/story?keep=yes');
    expect(
      articles.single.publishedAt.toUtc(),
      DateTime.utc(2026, 8, 1, 12, 30),
    );
  });

  test('RSS numeric timezone is parsed as the article publication date', () {
    final fetchedAt = DateTime(2026, 8, 2, 21, 0);
    final article = RssParser.parse(
      '''
      <rss><channel><item>
        <title>WNBA story</title>
        <link>https://foxsports.com/stories/wnba/story</link>
        <pubDate>Tue, 19 May 2026 12:19:51 -0400</pubDate>
      </item></channel></rss>
    ''',
      fox,
      fetchedAt: fetchedAt,
    ).single;

    expect(article.publishedAt.toUtc(), DateTime.utc(2026, 5, 19, 16, 19, 51));
    expect(article.publishedAt, isNot(fetchedAt));
  });

  test('ESPN named timezone is parsed instead of using the fetch time', () {
    final parsed = parseNewsDate('Sun, 2 Aug 2026 15:46:16 EST');

    expect(parsed, isNotNull);
    expect(parsed!.toUtc(), DateTime.utc(2026, 8, 2, 20, 46, 16));
  });

  test('every FOX sport uses the current page JSON feed', () {
    final foxSources = newsSources.where(
      (source) => source.id.startsWith('fox_'),
    );

    expect(foxSources, hasLength(4));
    expect(
      foxSources.every(
        (source) =>
            source.format == NewsSourceFormat.foxPageFeed &&
            source.url.startsWith('https://prod-api.foxsports.com/fs/feed') &&
            source.url.contains('size=100'),
      ),
      isTrue,
    );
  });

  test('FOX page feed uses original article dates and newest-first order', () {
    const source = NewsSource(
      id: 'fox_wnba',
      name: 'FOX Sports',
      sport: 'WNBA',
      url: 'https://prod-api.foxsports.com/fs/feed',
      homepage: 'https://www.foxsports.com/wnba',
      format: NewsSourceFormat.foxPageFeed,
    );
    final articles = FoxPageFeedParser.parse(
      '''
      {"data":{"results":[
        {"id":"older","component_type":"news_article","title":"Older",
         "canonical_url":"foxsports.com/articles/wnba/older",
         "last_published_date":"2026-08-01T12:00:00Z","dek":"Old summary"},
        {"id":"video","component_type":"video","title":"Skip video",
         "canonical_url":"https://youtube.com/watch?v=1",
         "last_published_date":"2026-08-02T15:00:00Z"},
        {"id":"newer","component_type":"news_article","title":"Newer",
         "canonical_url":"https://www.si.com/wnba/newer",
         "last_published_date":"2026-08-02T14:00:00Z",
         "external_source":"si.com","thumbnail":{"url":"https://img.test/new.jpg"}}
      ]}}
    ''',
      source,
      fetchedAt: DateTime(2026, 8, 3),
    );

    expect(articles.map((article) => article.title), ['Newer', 'Older']);
    expect(articles.first.publishedAt.toUtc(), DateTime.utc(2026, 8, 2, 14));
    expect(articles.first.sourceName, 'si.com');
    expect(articles.last.url, 'https://foxsports.com/articles/wnba/older');
  });

  test('ESPN policy disables transformed summaries', () {
    const espn = NewsSource(
      id: 'espn_nba',
      name: 'ESPN',
      sport: 'NBA',
      url: 'https://example.com/espn',
      homepage: 'https://espn.com',
      summaryEnabled: false,
    );
    final article = RssParser.parse('''
      <rss><channel><item><title>Original title</title>
      <link>https://espn.com/story</link>
      <description><![CDATA[<b>Do not transform this.</b>]]></description>
      </item></channel></rss>
    ''', espn).single;

    expect(article.title, 'Original title');
    expect(article.summary, isEmpty);
  });

  test(
    'SQLite archive survives reopening and never drops old articles',
    () async {
      sqfliteFfiInit();
      final path =
          '${Directory.systemTemp.path}/courtboard_news_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      addTearDown(() async {
        await databaseFactoryFfi.deleteDatabase(path);
      });
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      final article = NewsArticle(
        dedupeKey: 'url:https://foxsports.com/old-story',
        sourceId: 'fox_nba',
        sourceName: 'FOX Sports',
        sport: 'NBA',
        title: 'A hundred day old NBA story',
        url: 'https://foxsports.com/old-story',
        publishedAt: oldDate,
        fetchedAt: oldDate,
      );

      final first = NewsStore(path: path);
      expect(await first.saveArticles([article]), 1);
      await first.close();

      final reopened = NewsStore(path: path);
      final stored = await reopened.query();
      expect(stored, hasLength(1));
      expect(stored.single.title, article.title);
      expect(
        stored.single.publishedAt.difference(oldDate).inSeconds.abs(),
        lessThan(1),
      );
      await reopened.close();
    },
  );

  test(
    'database migration removes only corrupted fallback-date articles',
    () async {
      sqfliteFfiInit();
      final path =
          '${Directory.systemTemp.path}/courtboard_news_migration_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      addTearDown(() async => databaseFactoryFfi.deleteDatabase(path));
      final oldDb = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE news_sources (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, sport TEXT NOT NULL,
              url TEXT NOT NULL, homepage TEXT NOT NULL, enabled INTEGER NOT NULL,
              terms_note TEXT NOT NULL DEFAULT '', last_attempt_at INTEGER,
              last_success_at INTEGER, last_error TEXT NOT NULL DEFAULT '',
              etag TEXT NOT NULL DEFAULT '', last_modified TEXT NOT NULL DEFAULT ''
            )
          ''');
            await db.execute('''
            CREATE TABLE news_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT, dedupe_key TEXT NOT NULL UNIQUE,
              source_id TEXT NOT NULL, source_name TEXT NOT NULL,
              external_id TEXT NOT NULL DEFAULT '', title TEXT NOT NULL,
              summary TEXT NOT NULL DEFAULT '', url TEXT NOT NULL,
              image_url TEXT NOT NULL DEFAULT '', author TEXT NOT NULL DEFAULT '',
              search_text TEXT NOT NULL, published_at INTEGER NOT NULL,
              fetched_at INTEGER NOT NULL
            )
          ''');
          },
        ),
      );
      final fallbackTime = DateTime(2026, 8, 2).millisecondsSinceEpoch;
      await oldDb.insert('news_sources', {
        'id': 'fox_nba',
        'name': 'FOX Sports',
        'sport': 'NBA',
        'url': 'https://old-rss.test',
        'homepage': 'https://foxsports.com/nba',
        'enabled': 1,
        'last_success_at': fallbackTime,
        'etag': 'old-etag',
        'last_modified': 'old-modified',
      });
      await oldDb.insert('news_sources', {
        'id': 'espn_nba',
        'name': 'ESPN',
        'sport': 'NBA',
        'url': 'https://espn.test',
        'homepage': 'https://espn.com/nba',
        'enabled': 0,
      });
      Future<void> insertItem(String sourceId, String key, int published) =>
          oldDb.insert('news_items', {
            'dedupe_key': key,
            'source_id': sourceId,
            'source_name': sourceId,
            'title': key,
            'url': 'https://example.com/$key',
            'search_text': key,
            'published_at': published,
            'fetched_at': fallbackTime,
          });
      await insertItem('fox_nba', 'corrupt-fox', fallbackTime);
      await insertItem('espn_nba', 'corrupt-espn', fallbackTime);
      await insertItem(
        'guardian_football',
        'valid-guardian',
        fallbackTime - const Duration(days: 2).inMilliseconds,
      );
      await oldDb.close();

      final store = NewsStore(path: path);
      final upgraded = await store.database;
      final remaining = await upgraded.query('news_items', orderBy: 'id');
      final foxRow = (await upgraded.query(
        'news_sources',
        where: 'id = ?',
        whereArgs: ['fox_nba'],
      )).single;

      expect(remaining.map((row) => row['dedupe_key']), ['valid-guardian']);
      expect(
        foxRow['url'],
        startsWith('https://prod-api.foxsports.com/fs/feed'),
      );
      expect(foxRow['last_success_at'], isNull);
      expect(foxRow['etag'], isEmpty);
      await store.close();
    },
  );

  test('URL deduplication keeps every sport and source relationship', () async {
    final store = NewsStore(path: inMemoryDatabasePath);
    addTearDown(store.close);
    final now = DateTime.now();
    NewsArticle article(String sourceId, String sourceName, String sport) =>
        NewsArticle(
          dedupeKey: 'url:https://example.com/shared-story',
          sourceId: sourceId,
          sourceName: sourceName,
          sport: sport,
          title: 'Shared story',
          url: 'https://example.com/shared-story',
          publishedAt: now,
          fetchedAt: now,
        );

    await store.saveArticles([
      article('fox_nba', 'FOX Sports', 'NBA'),
      article('fox_soccer', 'FOX Sports', 'Foci'),
    ]);

    expect(await store.count(), 1);
    expect(await store.query(sport: 'NBA'), hasLength(1));
    expect(await store.query(sport: 'Foci'), hasLength(1));
    expect(await store.query(sourceId: 'fox_soccer'), hasLength(1));
  });

  test(
    'archive search supports title text and accented athlete names',
    () async {
      final store = NewsStore(path: inMemoryDatabasePath);
      addTearDown(store.close);
      final now = DateTime.now();
      await store.saveArticles([
        NewsArticle(
          dedupeKey: 'url:https://example.com/dorka-juhasz',
          sourceId: 'fox_wnba',
          sourceName: 'FOX Sports',
          sport: 'WNBA',
          title: 'Dorka Juhasz delivers a season-best performance',
          summary: 'Minnesota celebrates the Hungarian center.',
          url: 'https://example.com/dorka-juhasz',
          publishedAt: now,
          fetchedAt: now,
        ),
      ]);

      expect(await store.query(text: 'season-best'), hasLength(1));
      expect(await store.query(athleteName: 'Juhász Dorka'), hasLength(1));
      expect(await store.query(text: 'Caitlin Clark'), isEmpty);
    },
  );

  test('automatic refresh respects the twenty minute window', () async {
    final provider = _FakeNewsProvider();
    final store = NewsStore(path: inMemoryDatabasePath);
    final repository = NewsRepository(store: store, provider: provider);
    addTearDown(repository.close);

    final first = await repository.refresh();
    final second = await repository.refresh();

    expect(first.updatedSources, 7);
    expect(provider.calls, 7);
    expect(second.skipped, isTrue);
    final states = await store.sourceStates();
    expect(
      states.singleWhere((state) => state.source.id == 'espn_nba').enabled,
      isFalse,
    );
    expect(
      states
          .singleWhere((state) => state.source.id == 'guardian_tennis')
          .enabled,
      isFalse,
    );
  });

  test('parallel refresh reports the exact number of saved articles', () async {
    final store = NewsStore(path: inMemoryDatabasePath);
    final repository = NewsRepository(
      store: store,
      provider: _ArticleNewsProvider(),
    );
    addTearDown(repository.close);

    final report = await repository.refresh(force: true);

    expect(report.newArticles, 7);
    expect(await store.count(), 7);
  });

  testWidgets('news card renders source, summary and related athlete', (
    tester,
  ) async {
    final now = DateTime.now();
    final article = NewsArticle(
      dedupeKey: 'url:https://example.com/jokic',
      sourceId: 'fox_nba',
      sourceName: 'FOX Sports',
      sport: 'NBA',
      title: 'Nikola Jokic leads Denver again',
      summary: 'A triple-double for the Nuggets star.',
      url: 'https://example.com/jokic',
      publishedAt: now,
      fetchedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsArticleCard(
              article: article,
              athletes: const [
                NewsAthleteRef(name: 'Nikola Jokić', sport: 'NBA'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nikola Jokic leads Denver again'), findsOneWidget);
    expect(find.text('Nikola Jokić'), findsOneWidget);
    expect(find.text('A triple-double for the Nuggets star.'), findsOneWidget);
    expect(find.text('FOX Sports'), findsOneWidget);
    expect(find.text('Eredeti cikk'), findsOneWidget);
  });
}
