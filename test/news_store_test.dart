import 'dart:io';

import 'package:courtboard/data/news.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

NewsArticle _article(
  String slug, {
  required DateTime published,
  String sport = 'NBA',
  String sourceId = 'fox_nba',
  String title = '',
  String summary = '',
  String imageUrl = '',
  bool parsed = true,
}) => NewsArticle(
  dedupeKey: 'url:https://example.com/$slug',
  sourceId: sourceId,
  sourceName: 'FOX Sports',
  sport: sport,
  title: title.isEmpty ? 'Story $slug' : title,
  summary: summary,
  imageUrl: imageUrl,
  url: 'https://example.com/$slug',
  publishedAt: published,
  fetchedAt: published,
  publishedAtParsed: parsed,
);

void main() {
  final now = DateTime(2026, 9, 30, 12);

  test('upsert counts only new articles and keeps non-empty fields', () async {
    final store = NewsStore(path: NewsStore.inMemoryPath);
    addTearDown(store.close);

    final added = await store.saveArticles([
      _article(
        'a',
        published: now,
        summary: 'Első összefoglaló',
        imageUrl: 'https://example.com/a.jpg',
      ),
      _article('b', published: now),
    ]);
    final again = await store.saveArticles([
      _article('a', published: now, title: 'Új cím'),
      _article('a', published: now, sport: 'WNBA', sourceId: 'fox_wnba'),
      _article('c', published: now),
    ]);

    expect(added, 2);
    expect(again, 1);
    expect(await store.count(), 3);
    final stored = (await store.query(sport: 'WNBA')).single;
    expect(stored.summary, 'Első összefoglaló');
    expect(stored.imageUrl, 'https://example.com/a.jpg');
    expect(await store.query(sourceId: 'fox_wnba'), hasLength(1));
    expect(await store.query(sport: 'NBA'), hasLength(3));
  });

  test(
    'retention keeps the newest articles and anything younger than a year',
    () async {
      final store = NewsStore(path: NewsStore.inMemoryPath);
      addTearDown(store.close);
      await store.saveArticles([
        for (var i = 0; i < 4; i++)
          _article('old$i', published: now.subtract(Duration(days: 400 + i))),
        _article('recent', published: now.subtract(const Duration(days: 10))),
      ]);

      final removed = await store.applyRetention(
        const NewsRetention(minArticles: 2, maxAge: Duration(days: 365)),
        now: now,
      );

      expect(removed, 3);
      final remaining = await store.query();
      expect(remaining.map((article) => article.url), [
        'https://example.com/recent',
        'https://example.com/old0',
      ]);
      // A kapcsolósorok és a keresőindex is követik a törlést.
      expect(await store.query(sport: 'NBA'), hasLength(2));
      expect(await store.query(text: 'old1'), isEmpty);
      final db = await store.database;
      final orphans = await db
          .customSelect(
            'SELECT COUNT(*) AS count FROM news_item_sports '
            'WHERE item_id NOT IN (SELECT id FROM news_items)',
          )
          .getSingle();
      expect(orphans.read<int>('count'), 0);
    },
  );

  test(
    'full-text search matches substrings like the former LIKE query',
    () async {
      final store = NewsStore(path: NewsStore.inMemoryPath);
      addTearDown(store.close);
      await store.saveArticles([
        _article(
          'juhasz',
          published: now,
          title: 'Dorka Juhász delivers a season-best performance',
          summary: 'Minnesota celebrates the Hungarian center.',
        ),
        _article('clark', published: now, title: 'Caitlin Clark returns'),
      ]);

      expect(await store.fullTextSearchAvailable, isTrue);
      expect(await store.query(text: 'uhas'), hasLength(1));
      expect(await store.query(text: 'season-best'), hasLength(1));
      expect(await store.query(text: 'caitlin clark'), hasLength(1));
      expect(await store.query(text: 'clark caitlin'), isEmpty);
      expect(await store.query(athleteName: 'Juhász Dorka'), hasLength(1));
      // Két karakteres keresés a LIKE úton fut.
      expect(await store.query(text: 'do'), hasLength(1));
      // A frissített cím az indexben is frissül.
      await store.saveArticles([
        _article('clark', published: now, title: 'Indiana wins again'),
      ]);
      expect(await store.query(text: 'caitlin'), isEmpty);
      expect(await store.query(text: 'indiana'), hasLength(1));
    },
  );

  test(
    'version 3 databases are upgraded and indexed without data loss',
    () async {
      final path =
          '${Directory.systemTemp.path}/courtboard_news_v3_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      addTearDown(() async {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      });
      final old = sqlite3.open(path);
      old.execute('''
        CREATE TABLE news_sources (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, sport TEXT NOT NULL,
          url TEXT NOT NULL, homepage TEXT NOT NULL, enabled INTEGER NOT NULL,
          terms_note TEXT NOT NULL DEFAULT '', last_attempt_at INTEGER,
          last_success_at INTEGER, last_error TEXT NOT NULL DEFAULT '',
          etag TEXT NOT NULL DEFAULT '', last_modified TEXT NOT NULL DEFAULT ''
        )
      ''');
      old.execute('''
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
      old.execute('''
        CREATE TABLE news_item_sports (
          item_id INTEGER NOT NULL, sport TEXT NOT NULL,
          PRIMARY KEY(item_id, sport)
        )
      ''');
      old.execute('''
        CREATE TABLE news_item_sources (
          item_id INTEGER NOT NULL, source_id TEXT NOT NULL,
          PRIMARY KEY(item_id, source_id)
        )
      ''');
      old.execute(
        'INSERT INTO news_items (dedupe_key, source_id, source_name, title, '
        'url, search_text, published_at, fetched_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'url:https://example.com/legacy',
          'fox_nba',
          'FOX Sports',
          'Legacy Jokic story',
          'https://example.com/legacy',
          'legacy jokic story',
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        ],
      );
      final id = old.lastInsertRowId;
      old.execute(
        'INSERT INTO news_item_sports (item_id, sport) VALUES (?, ?)',
        [id, 'NBA'],
      );
      old.execute(
        'INSERT INTO news_item_sources (item_id, source_id) VALUES (?, ?)',
        [id, 'fox_nba'],
      );
      old.execute('PRAGMA user_version = 3');
      old.close();

      final store = NewsStore(path: path);
      addTearDown(store.close);
      final db = await store.database;
      final indexes =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      final version = await db.customSelect('PRAGMA user_version').getSingle();

      expect(version.data.values.single, NewsStore.schemaVersion);
      expect(indexes, contains('idx_news_sources_source'));
      expect(await store.query(text: 'jokic'), hasLength(1));
      expect(await store.query(sourceId: 'fox_nba'), hasLength(1));
    },
  );

  test('refresh applies the retention policy after saving', () async {
    final store = NewsStore(path: NewsStore.inMemoryPath);
    final repository = NewsRepository(
      store: store,
      provider: _OldArticleProvider(now),
      retention: const NewsRetention(
        minArticles: 1,
        maxAge: Duration(days: 30),
      ),
    );
    addTearDown(repository.close);

    final report = await repository.refresh(force: true);

    expect(report.newArticles, greaterThan(1));
    expect(report.removedArticles, report.newArticles - 1);
    expect(await store.count(), 1);
  });
}

/// Minden forrásra egy régi (két éves) cikket ad.
class _OldArticleProvider implements NewsProvider {
  _OldArticleProvider(this.now);

  final DateTime now;

  @override
  Future<RssFetchResult> fetch(
    NewsSource source, {
    String etag = '',
    String lastModified = '',
  }) async => RssFetchResult(
    articles: [
      _article(
        source.id,
        published: now.subtract(const Duration(days: 730)),
        sport: source.sport,
        sourceId: source.id,
      ),
    ],
  );

  @override
  void close() {}
}
