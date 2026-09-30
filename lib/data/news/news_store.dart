import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/news/news_database.dart';
import 'package:courtboard/data/news/news_models.dart';
import 'package:courtboard/data/news/news_sources.dart';

export 'package:courtboard/data/news/news_database.dart' show NewsDatabase;

/// A hírarchívum megőrzési szabálya: egy cikk csak akkor törlődik, ha
/// régebbi [maxAge]-nél **és** nincs a legújabb [minArticles] között. Így
/// ritka forrásoknál is marad legalább ennyi cikk, a tár mérete pedig
/// nagyjából egy évnyi hírre korlátozódik.
class NewsRetention {
  const NewsRetention({
    this.minArticles = 5000,
    this.maxAge = const Duration(days: 365),
  });

  final int minArticles;
  final Duration maxAge;
}

/// A helyi hírarchívum (drift + SQLite, `%APPDATA%\Courtboard\
/// courtboard_news.sqlite`).
///
/// A fájlt a drift egy háttér-isolate-ben kezeli, így a lekérdezések nem
/// akasztják meg a felületet; a [inMemoryPath] (tesztek) az aktuális
/// isolate-ben futó memóriaadatbázist nyit. A lekérdezésekhez tartozó
/// `watch…` streamek minden, a táblákat érintő írás után újra lefutnak.
class NewsStore {
  NewsStore({String? path}) : _path = path ?? defaultPath();

  /// Memóriában élő (a lezárással elvesző) adatbázis útvonala.
  static const inMemoryPath = ':memory:';

  final String _path;

  /// A megnyitás Future-je: az egyidejű első hívók ugyanazt az adatbázist
  /// kapják, nem nyitnak párhuzamosan két kapcsolatot. Sikertelen megnyitás
  /// után a következő hívás újrapróbálja.
  Future<NewsDatabase>? _database;

  static String defaultPath() => AppPaths.newsDatabase;

  /// Az adatbázis sémaverziója (`PRAGMA user_version`); a 4-es a
  /// 0.13.0-ig használt sqflite-tár utolsó verziója.
  static const schemaVersion = 5;

  /// Elérhető-e az FTS5 alapú keresés (a megnyitás után értelmes).
  Future<bool> get fullTextSearchAvailable async =>
      (await database).fullTextSearch;

  Future<NewsDatabase> get database {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _open();
    _database = opening;
    // A hibát a hívó kapja meg; itt csak a következő próbálkozást engedjük.
    unawaited(
      opening.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_database, opening)) _database = null;
        },
      ),
    );
    return opening;
  }

  Future<NewsDatabase> _open() async {
    final QueryExecutor executor;
    if (_path == inMemoryPath) {
      executor = NativeDatabase.memory(setup: _configure);
    } else {
      await Directory(File(_path).parent.path).create(recursive: true);
      executor = NativeDatabase.createInBackground(
        File(_path),
        setup: _configure,
      );
    }
    // A streamek a leiratkozáskor azonnal zárulnak (nincs késleltető
    // időzítő), így a widgettesztek sem hagynak függő Timer-t.
    final db = NewsDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    try {
      // A drift lustán nyit: az első lekérdezés futtatja a migrációt, a
      // forráslista beírását és az FTS-index ellenőrzését.
      await db.doWhenOpened((_) {});
    } catch (_) {
      try {
        await db.close();
      } catch (_) {
        // A sikertelen megnyitás lezárása maga is hibázhat.
      }
      rethrow;
    }
    return db;
  }

  /// A kapcsolat beállítása közvetlenül a megnyitás után, a migrációk
  /// előtt (a korábbi `onConfigure` megfelelője). Statikus, mert a háttér-
  /// isolate-be kerül. A kaszkádolt törléshez a külső kulcsok bekapcsolása
  /// kell; egy másik kapcsolat (például egy második példány) írási zárja
  /// alatt a kérés legfeljebb 5 mp-ig vár, mielőtt hibát adna.
  static void _configure(sqlite3.Database database) {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA busy_timeout = 5000');
  }

  Future<List<NewsSourceState>> sourceStates() async {
    final db = await database;
    return _toSourceStates(await _sourceRows(db).get());
  }

  /// A forrásállapotok, minden (be/kikapcsolás, frissítés) után újra.
  Stream<List<NewsSourceState>> watchSourceStates() async* {
    final db = await database;
    yield* _sourceRows(db).watch().map(_toSourceStates);
  }

  static Selectable<NewsSourceRow> _sourceRows(NewsDatabase db) =>
      db.select(db.newsSources)..orderBy([
        (t) => OrderingTerm.asc(t.name),
        (t) => OrderingTerm.asc(t.sport),
      ]);

  /// Csak a beépített listában (még) szereplő források állapota.
  static List<NewsSourceState> _toSourceStates(List<NewsSourceRow> rows) {
    final byId = {for (final source in newsSources) source.id: source};
    return [
      for (final row in rows)
        if (byId[row.id] case final source?)
          NewsSourceState(
            source: source,
            enabled: row.enabled,
            lastSuccessAt: row.lastSuccessAt,
            lastError: row.lastError,
            etag: row.etag,
            lastModified: row.lastModified,
          ),
    ];
  }

  Future<void> setSourceEnabled(String sourceId, bool enabled) async {
    final db = await database;
    await (db.update(db.newsSources)..where((t) => t.id.equals(sourceId)))
        .write(NewsSourcesCompanion(enabled: Value(enabled)));
  }

  Future<void> markSourceResult(
    String sourceId, {
    required bool success,
    String error = '',
    String etag = '',
    String lastModified = '',
  }) async {
    final db = await database;
    final now = DateTime.now();
    await (db.update(
      db.newsSources,
    )..where((t) => t.id.equals(sourceId))).write(
      NewsSourcesCompanion(
        lastAttemptAt: Value(now),
        lastSuccessAt: success ? Value(now) : const Value.absent(),
        lastError: Value(success ? '' : error),
        etag: etag.isNotEmpty ? Value(etag) : const Value.absent(),
        lastModified: lastModified.isNotEmpty
            ? Value(lastModified)
            : const Value.absent(),
      ),
    );
  }

  /// Cikkek mentése egyetlen tranzakcióban, cikkenként egy upserttel és két
  /// kapcsolósorral.
  ///
  /// Meglévő cikknél a cím, a keresőszöveg és a letöltési idő frissül; az
  /// összefoglaló, kép és szerző csak nem üres új értékkel; a megjelenési
  /// dátum csak akkor, ha a hírfolyamból értelmezett dátum érkezett
  /// ([NewsArticle.publishedAtParsed]). Az új cikkek számát adja vissza.
  Future<int> saveArticles(List<NewsArticle> articles) async {
    if (articles.isEmpty) return 0;
    final db = await database;
    return db.transaction(() async {
      final before = await db.countItems().getSingle();
      for (final article in articles) {
        await db.upsertItem(
          dedupeKey: article.dedupeKey,
          sourceId: article.sourceId,
          sourceName: article.sourceName,
          externalId: article.externalId,
          title: article.title,
          summary: article.summary,
          url: article.url,
          imageUrl: article.imageUrl,
          author: article.author,
          searchText: article.searchText,
          publishedAt: article.publishedAt,
          fetchedAt: article.fetchedAt,
          publishedAtParsed: article.publishedAtParsed,
        );
        await db.linkItemSport(
          sport: article.sport,
          dedupeKey: article.dedupeKey,
        );
        await db.linkItemSource(
          sourceId: article.sourceId,
          dedupeKey: article.dedupeKey,
        );
      }
      return await db.countItems().getSingle() - before;
    });
  }

  /// Régi cikkek törlése a [retention] szerint; a kapcsolósorok a külső
  /// kulcs `ON DELETE CASCADE` szabályával, az FTS-index triggerrel törlődik.
  /// A törölt cikkek számát adja vissza.
  Future<int> applyRetention(NewsRetention retention, {DateTime? now}) async {
    final db = await database;
    return db.deleteExpiredItems(
      cutoff: (now ?? DateTime.now()).subtract(retention.maxAge),
      keep: retention.minArticles,
    );
  }

  Future<List<NewsArticle>> query({
    String text = '',
    String sport = 'Mind',
    String sourceId = 'Mind',
    String athleteName = 'Mind',
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await database;
    return _articles(
      db,
      text: text,
      sport: sport,
      sourceId: sourceId,
      athleteName: athleteName,
      limit: limit,
      offset: offset,
    ).get();
  }

  /// A [query] eredménye streamként: minden cikkmentés, -frissítés és
  /// takarítás után újra lefut.
  Stream<List<NewsArticle>> watchArticles({
    String text = '',
    String sport = 'Mind',
    String sourceId = 'Mind',
    String athleteName = 'Mind',
    int limit = 500,
    int offset = 0,
  }) async* {
    final db = await database;
    yield* _articles(
      db,
      text: text,
      sport: sport,
      sourceId: sourceId,
      athleteName: athleteName,
      limit: limit,
      offset: offset,
    ).watch();
  }

  /// A szűrt, lapozott cikklista lekérdezése. Az SQL a feltételektől függ
  /// (FTS5 vagy `LIKE`), ezért egyedi SELECT; a sorokat a generált
  /// `news_items` táblaleíró alakítja típusos sorrá.
  static Selectable<NewsArticle> _articles(
    NewsDatabase db, {
    required String text,
    required String sport,
    required String sourceId,
    required String athleteName,
    required int limit,
    required int offset,
  }) {
    final where = <String>[];
    final args = <Variable<Object>>[];
    if (sport != 'Mind') {
      where.add('s.sport = ?');
      args.add(Variable.withString(sport));
    }
    if (sourceId != 'Mind') {
      where.add('src.source_id = ?');
      args.add(Variable.withString(sourceId));
    }
    // A keresőszöveg normalizált (csak a-z, 0-9 és szóköz), így idézőjelek
    // közé téve biztonságos FTS5-kifejezés. A trigram index legalább 3
    // karakteres részszóra működik; rövidebbre marad a LIKE.
    final ftsTerms = <String>[];
    final fullText = db.fullTextSearch;
    final normalized = normalizeAthleteName(text);
    if (normalized.isNotEmpty) {
      if (fullText && normalized.length >= 3) {
        ftsTerms.add('"$normalized"');
      } else {
        where.add('n.search_text LIKE ?');
        args.add(Variable.withString('%$normalized%'));
      }
    }
    if (athleteName != 'Mind') {
      final tokens = normalizeAthleteName(
        athleteName,
      ).split(' ').where((token) => token.length >= 3);
      for (final token in tokens) {
        if (fullText) {
          ftsTerms.add('"$token"');
        } else {
          where.add('n.search_text LIKE ?');
          args.add(Variable.withString('%$token%'));
        }
      }
    }
    if (ftsTerms.isNotEmpty) {
      where.add('n.id IN (SELECT rowid FROM news_fts WHERE news_fts MATCH ?)');
      args.add(Variable.withString(ftsTerms.join(' AND ')));
    }
    return db
        .customSelect(
          '''
      SELECT DISTINCT n.*, COALESCE(s.sport, '') AS matched_sport
      FROM news_items n
      LEFT JOIN news_item_sports s ON s.item_id = n.id
      LEFT JOIN news_item_sources src ON src.item_id = n.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY n.id
      ORDER BY n.published_at DESC, n.id DESC
      LIMIT ? OFFSET ?
    ''',
          variables: [
            ...args,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: {db.newsItems, db.newsItemSports, db.newsItemSources},
        )
        .map(
          (row) => _articleFromRow(
            db.newsItems.map(row.data),
            row.read<String>('matched_sport'),
          ),
        );
  }

  Future<int> count() async {
    final db = await database;
    return db.countItems().getSingle();
  }

  /// A mentett cikkek száma streamként (mentés és takarítás után frissül).
  Stream<int> watchCount() async* {
    final db = await database;
    yield* db.countItems().watchSingle();
  }

  Future<void> close() async {
    final opening = _database;
    _database = null;
    if (opening == null) return;
    try {
      await (await opening).close();
    } catch (_) {
      // A sikertelen megnyitást nem kell lezárni.
    }
  }

  static NewsArticle _articleFromRow(NewsItemRow row, String sport) =>
      NewsArticle(
        id: row.id,
        dedupeKey: row.dedupeKey,
        sourceId: row.sourceId,
        sourceName: row.sourceName,
        sport: sport,
        externalId: row.externalId,
        title: row.title,
        summary: row.summary,
        url: row.url,
        imageUrl: row.imageUrl,
        author: row.author,
        publishedAt: row.publishedAt,
        fetchedAt: row.fetchedAt,
      );
}
