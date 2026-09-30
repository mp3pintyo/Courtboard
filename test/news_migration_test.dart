// A sqflite → drift átállás (0.14.0) tesztjei: a 0.13.0-ig használt 4-es
// sémájú hírarchívumot a drift-alapú NewsStore adatvesztés nélkül veszi át.
import 'dart:io';

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/news.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'helpers/legacy_news_database.dart';

final _now = DateTime(2026, 9, 30, 12);

int _millis(Duration ago) => _now.subtract(ago).millisecondsSinceEpoch;

const _sources = [
  LegacySource(
    'fox_nba',
    name: 'FOX Sports',
    sport: 'NBA',
    url: 'https://old-fox.example/rss',
    lastSuccessAt: 1759200000000,
    etag: 'W/"fox-etag"',
    lastModified: 'Tue, 30 Sep 2025 10:00:00 GMT',
  ),
  LegacySource('cbs_nba', name: 'CBS Sports', sport: 'NBA'),
  LegacySource('espn_nba', name: 'ESPN', sport: 'NBA', enabled: false),
  LegacySource('espn_wnba', name: 'ESPN', sport: 'WNBA'),
  LegacySource(
    'guardian_football',
    name: 'The Guardian',
    sport: 'Foci',
    lastError: 'HTTP 503 – átmeneti hiba',
  ),
  // Egy azóta megszűnt forrás sora: a tárban marad, a listában nem látszik.
  LegacySource('retired_source', name: 'Régi forrás', sport: 'NBA'),
];

final _articles = [
  LegacyArticle(
    dedupeKey: 'url:https://example.com/juhasz',
    sourceId: 'espn_wnba',
    title: 'Juhász Dorka szezoncsúcsot dobott a Lynxben',
    summary: 'Árvíztűrő tükörfúrógép: a magyar center ünneplése.',
    imageUrl: 'https://example.com/juhasz.jpg',
    author: 'Kovács Ágnes',
    searchText: normalizeAthleteName(
      'Juhász Dorka szezoncsúcsot dobott a Lynxben '
      'Árvíztűrő tükörfúrógép: a magyar center ünneplése.',
    ),
    publishedAt: _millis(const Duration(hours: 2)),
    sports: const ['WNBA'],
    sources: const ['espn_wnba'],
  ),
  LegacyArticle(
    dedupeKey: 'url:https://example.com/jokic',
    sourceId: 'fox_nba',
    title: 'Nikola Jokić triple-double again',
    searchText: normalizeAthleteName('Nikola Jokić triple-double again'),
    publishedAt: _millis(const Duration(hours: 5)),
    sports: const ['NBA', 'Foci'],
    sources: const ['fox_nba', 'cbs_nba'],
  ),
  LegacyArticle(
    dedupeKey: 'url:https://example.com/old',
    sourceId: 'guardian_football',
    title: 'Egy régi Bonmatí-cikk',
    searchText: normalizeAthleteName('Egy régi Bonmatí-cikk'),
    publishedAt: _millis(const Duration(days: 400)),
    sports: const ['Foci'],
    sources: const ['guardian_football'],
  ),
];

String _tempPath(String name) =>
    '${Directory.systemTemp.path}/courtboard_$name'
    '_${DateTime.now().microsecondsSinceEpoch}.sqlite';

void _cleanup(String path) => addTearDown(() async {
  for (final suffix in const ['', '-journal', '-wal', '-shm']) {
    final file = File('$path$suffix');
    if (file.existsSync()) await file.delete();
  }
});

void main() {
  test('the bundled SQLite supports FTS5 with the trigram tokenizer', () async {
    // Ugyanaz a kötés (drift → sqlite3 csomag natív assetje), amelyet az
    // alkalmazás és a release build sqlite3.dll-je használ.
    final db = NativeDatabase.memory();
    final connection = DatabaseConnection(db);
    addTearDown(connection.close);
    await connection.ensureOpen(_NoMigrations());
    await connection.runCustom(
      "CREATE VIRTUAL TABLE t USING fts5(x, tokenize = 'trigram')",
    );
    await connection.runInsert('INSERT INTO t(x) VALUES (?)', ['juhász dorka']);
    final rows = await connection.runSelect('SELECT x FROM t WHERE t MATCH ?', [
      '"hász"',
    ]);

    expect(rows.single['x'], 'juhász dorka');
    expect(sqlite3.version.libVersion, isNotEmpty);
  });

  test('a sqflite schema v4 archive is adopted without data loss', () async {
    final path = _tempPath('legacy_v4');
    _cleanup(path);
    createLegacyNewsDatabase(path, sources: _sources, articles: _articles);
    final before = inspectNewsDatabase(path);
    expect(before.version, 4);

    final store = NewsStore(path: path);
    addTearDown(store.close);
    final all = await store.query();
    final states = {
      for (final state in await store.sourceStates()) state.source.id: state,
    };

    // Cikkek: sorrend, azonosítók és minden mező változatlan.
    expect(all.map((article) => article.dedupeKey), [
      for (final article in _articles) article.dedupeKey,
    ]);
    expect(all.map((article) => article.id), [1, 2, 3]);
    final juhasz = all.first;
    expect(juhasz.title, 'Juhász Dorka szezoncsúcsot dobott a Lynxben');
    expect(
      juhasz.summary,
      'Árvíztűrő tükörfúrógép: a magyar center ünneplése.',
    );
    expect(juhasz.imageUrl, 'https://example.com/juhasz.jpg');
    expect(juhasz.author, 'Kovács Ágnes');
    expect(juhasz.externalId, 'ext-url:https://example.com/juhasz');
    expect(juhasz.sourceName, 'Legacy');
    expect(juhasz.sport, 'WNBA');
    expect(
      juhasz.publishedAt.millisecondsSinceEpoch,
      _articles.first.publishedAt,
    );
    expect(
      juhasz.fetchedAt.millisecondsSinceEpoch,
      _articles.first.publishedAt + 1000,
    );

    // Kapcsolatok (sportág és forrás szerinti szűrés).
    expect((await store.query(sport: 'Foci')).map((a) => a.dedupeKey), [
      'url:https://example.com/jokic',
      'url:https://example.com/old',
    ]);
    expect(await store.query(sourceId: 'cbs_nba'), hasLength(1));
    expect(await store.query(sport: 'WNBA'), hasLength(1));

    // Keresés: a meglévő FTS-index (ékezetes névvel is) és a LIKE-út.
    expect(await store.fullTextSearchAvailable, isTrue);
    expect(await store.query(text: 'szezoncsúcs'), hasLength(1));
    expect(await store.query(athleteName: 'Juhász Dorka'), hasLength(1));
    expect(await store.query(text: 'tükörfúró'), hasLength(1));
    expect(await store.query(text: 'jo'), hasLength(1));
    expect(await store.query(text: 'bonmati'), hasLength(1));

    // Forrásállapotok: a felhasználói beállítás és a HTTP-validátorok
    // megmaradnak, a forráslista (URL) frissül.
    expect(states['espn_nba']!.enabled, isFalse);
    expect(states['fox_nba']!.enabled, isTrue);
    expect(states['fox_nba']!.etag, 'W/"fox-etag"');
    expect(states['fox_nba']!.lastModified, 'Tue, 30 Sep 2025 10:00:00 GMT');
    expect(
      states['fox_nba']!.lastSuccessAt?.millisecondsSinceEpoch,
      1759200000000,
    );
    expect(states['guardian_football']!.lastError, 'HTTP 503 – átmeneti hiba');
    expect(states, isNot(contains('retired_source')));
    final db = await store.database;
    final foxUrl = await db
        .customSelect("SELECT url FROM news_sources WHERE id = 'fox_nba'")
        .getSingle();
    expect(
      foxUrl.read<String>('url'),
      startsWith('https://prod-api.foxsports.com/fs/feed'),
    );
    final retired = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM news_sources WHERE id = 'retired_source'",
        )
        .getSingle();
    expect(retired.read<int>('c'), 1);

    // Az upsert és az FTS-triggerek a régi táblán is működnek.
    final added = await store.saveArticles([
      NewsArticle(
        dedupeKey: 'url:https://example.com/jokic',
        sourceId: 'fox_nba',
        sourceName: 'FOX Sports',
        sport: 'NBA',
        title: 'Jokić and Murray lead Denver',
        url: 'https://example.com/jokic',
        publishedAt: _now,
        fetchedAt: _now,
        publishedAtParsed: false,
      ),
      NewsArticle(
        dedupeKey: 'url:https://example.com/new',
        sourceId: 'fox_nba',
        sourceName: 'FOX Sports',
        sport: 'NBA',
        title: 'Brand new Nuggets story',
        url: 'https://example.com/new',
        publishedAt: _now,
        fetchedAt: _now,
      ),
    ]);
    expect(added, 1);
    expect(await store.count(), 4);
    expect(await store.query(text: 'murray'), hasLength(1));
    expect(await store.query(text: 'triple-double'), isEmpty);
    final updated = (await store.query(text: 'murray')).single;
    // Dátum nélküli frissítés nem írja felül a tárolt dátumot.
    expect(
      updated.publishedAt.millisecondsSinceEpoch,
      _articles[1].publishedAt,
    );
    final fresh = (await store.query(text: 'brand new')).single;
    // Az AUTOINCREMENT a régi sorszámláló (sqlite_sequence) után folytatja.
    expect(fresh.id, greaterThan(3));

    // A megőrzési szabály kaszkádolva a kapcsolósorokat is törli.
    final removed = await store.applyRetention(
      const NewsRetention(minArticles: 1, maxAge: Duration(days: 365)),
      now: _now,
    );
    expect(removed, 1);
    expect(await store.query(text: 'bonmati'), isEmpty);
    final orphans = await db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM news_item_sports WHERE item_id = 3) '
          '+ (SELECT COUNT(*) FROM news_item_sources WHERE item_id = 3) AS c',
        )
        .getSingle();
    expect(orphans.read<int>('c'), 0);
    await store.close();

    // A séma elemei azonosak maradtak; csak a verzió lépett 5-re.
    final after = inspectNewsDatabase(path);
    expect(after.version, NewsStore.schemaVersion);
    expect(after.schema, before.schema);
  });

  test('a v4 archive without an FTS index is indexed on first open', () async {
    final path = _tempPath('legacy_v4_nofts');
    _cleanup(path);
    createLegacyNewsDatabase(
      path,
      sources: _sources,
      articles: _articles,
      fullText: false,
    );
    expect(inspectNewsDatabase(path).schema, isNot(contains('table:news_fts')));

    final store = NewsStore(path: path);
    addTearDown(store.close);
    expect(await store.fullTextSearchAvailable, isTrue);
    expect(await store.query(text: 'szezoncsúcs'), hasLength(1));
    expect(await store.query(athleteName: 'Nikola Jokić'), hasLength(1));
    await store.close();

    final schema = inspectNewsDatabase(path).schema;
    expect(
      schema,
      containsAll([
        'table:news_fts',
        'trigger:news_items_fts_insert',
        'trigger:news_items_fts_delete',
        'trigger:news_items_fts_update',
      ]),
    );
  });

  test(
    'a fresh install creates the same schema as the sqflite store',
    () async {
      final legacyPath = _tempPath('legacy_schema');
      final freshPath = _tempPath('fresh');
      _cleanup(legacyPath);
      _cleanup(freshPath);
      createLegacyNewsDatabase(
        legacyPath,
        sources: const [],
        articles: const [],
      );

      final store = NewsStore(path: freshPath);
      addTearDown(store.close);
      expect(await store.count(), 0);
      expect(await store.fullTextSearchAvailable, isTrue);
      expect(
        (await store.sourceStates()).map((state) => state.source.id).toSet(),
        {for (final source in newsSources) source.id},
      );
      await store.close();

      final fresh = inspectNewsDatabase(freshPath);
      expect(fresh.version, NewsStore.schemaVersion);
      expect(fresh.schema, inspectNewsDatabase(legacyPath).schema);
    },
  );

  test('reopening a drift archive keeps data and version', () async {
    final path = _tempPath('reopen');
    _cleanup(path);
    final first = NewsStore(path: path);
    addTearDown(first.close);
    await first.saveArticles([
      NewsArticle(
        dedupeKey: 'url:https://example.com/a',
        sourceId: 'fox_nba',
        sourceName: 'FOX Sports',
        sport: 'NBA',
        title: 'Szoboszlai Dominik gólja',
        url: 'https://example.com/a',
        publishedAt: _now,
        fetchedAt: _now,
      ),
    ]);
    await first.setSourceEnabled('fox_nba', false);
    await first.close();

    final second = NewsStore(path: path);
    addTearDown(second.close);
    expect(await second.query(athleteName: 'Szoboszlai Dominik'), hasLength(1));
    expect(
      (await second.sourceStates())
          .singleWhere((state) => state.source.id == 'fox_nba')
          .enabled,
      isFalse,
    );
    await second.close();
    expect(inspectNewsDatabase(path).version, NewsStore.schemaVersion);
  });

  test('watch streams emit again after saving and retention', () async {
    final store = NewsStore(path: NewsStore.inMemoryPath);
    addTearDown(store.close);
    final counts = <int>[];
    final lists = <int>[];
    final countSub = store.watchCount().listen(counts.add);
    final listSub = store
        .watchArticles(sport: 'NBA')
        .listen((articles) => lists.add(articles.length));
    addTearDown(countSub.cancel);
    addTearDown(listSub.cancel);

    Future<void> settle() => pumpEventQueue(times: 50);
    await settle();
    await store.saveArticles([
      for (var i = 0; i < 3; i++)
        NewsArticle(
          dedupeKey: 'k$i',
          sourceId: 'fox_nba',
          sourceName: 'FOX Sports',
          sport: 'NBA',
          title: 'Story $i',
          url: 'https://example.com/$i',
          publishedAt: _now.subtract(Duration(days: 400 * i)),
          fetchedAt: _now,
        ),
    ]);
    await settle();
    await store.applyRetention(
      const NewsRetention(minArticles: 1, maxAge: Duration(days: 365)),
      now: _now,
    );
    await settle();

    expect(counts, [0, 3, 1]);
    expect(lists, [0, 3, 1]);
  });
}

class _NoMigrations extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
