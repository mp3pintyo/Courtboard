import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/news/news_models.dart';
import 'package:courtboard/data/news/news_sources.dart';

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

class NewsStore {
  NewsStore({String? path}) : _path = path ?? defaultPath();

  final String _path;

  /// Igaz, ha a beépített SQLite támogatja az FTS5 `trigram` tokenizálót,
  /// és a teljes szöveges index elkészült; különben `LIKE` keresés fut.
  bool _fullTextSearch = false;

  /// A megnyitás Future-je: az egyidejű első hívók ugyanazt az adatbázist
  /// kapják, nem nyitnak párhuzamosan két kapcsolatot. Sikertelen megnyitás
  /// után a következő hívás újrapróbálja.
  Future<Database>? _database;

  static String defaultPath() => AppPaths.newsDatabase;

  /// Az adatbázis sémaverziója.
  static const schemaVersion = 4;

  /// Elérhető-e az FTS5 alapú keresés (a megnyitás után értelmes).
  Future<bool> get fullTextSearchAvailable async {
    await database;
    return _fullTextSearch;
  }

  Future<Database> get database {
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

  Future<Database> _open() async {
    sqfliteFfiInit();
    if (_path != inMemoryDatabasePath) {
      await Directory(File(_path).parent.path).create(recursive: true);
    }
    final db = await databaseFactoryFfi.openDatabase(
      _path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    await _seedSources(db);
    _fullTextSearch = await _ensureFullTextSearch(db);
    return db;
  }

  /// Az FTS5 trigram index létrehozása (első alkalommal a meglévő cikkek
  /// újraindexelésével) és a szinkronizáló triggerek. A trigram tokenizáló a
  /// korábbi `LIKE '%…%'` keresés részszó-szemantikáját indexelten adja.
  ///
  /// Ha a modul nem érhető el, a triggereket eltávolítja (különben minden
  /// beszúrás hibára futna), és `false`-szal `LIKE` keresésre vált.
  static Future<bool> _ensureFullTextSearch(Database db) async {
    try {
      final existing = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'news_fts'",
      );
      await db.transaction((txn) async {
        if (existing.isEmpty) {
          await txn.execute('''
            CREATE VIRTUAL TABLE news_fts USING fts5(
              search_text,
              content = 'news_items',
              content_rowid = 'id',
              tokenize = 'trigram'
            )
          ''');
        }
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_insert
          AFTER INSERT ON news_items BEGIN
            INSERT INTO news_fts(rowid, search_text)
            VALUES (new.id, new.search_text);
          END
        ''');
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_delete
          AFTER DELETE ON news_items BEGIN
            INSERT INTO news_fts(news_fts, rowid, search_text)
            VALUES ('delete', old.id, old.search_text);
          END
        ''');
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_update
          AFTER UPDATE OF search_text ON news_items BEGIN
            INSERT INTO news_fts(news_fts, rowid, search_text)
            VALUES ('delete', old.id, old.search_text);
            INSERT INTO news_fts(rowid, search_text)
            VALUES (new.id, new.search_text);
          END
        ''');
        if (existing.isEmpty) {
          await txn.execute(
            "INSERT INTO news_fts(news_fts) VALUES ('rebuild')",
          );
        }
      });
      await db.rawQuery('SELECT rowid FROM news_fts LIMIT 0');
      return true;
    } catch (_) {
      for (final name in const [
        'news_items_fts_insert',
        'news_items_fts_delete',
        'news_items_fts_update',
      ]) {
        try {
          await db.execute('DROP TRIGGER IF EXISTS $name');
        } catch (_) {
          // A trigger eltávolítása nélkül is próbálkozunk a többivel.
        }
      }
      return false;
    }
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
    await _createIndexes(db);
  }

  /// A lekérdezések és a takarítás indexei (idempotens).
  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_news_items_published '
      'ON news_items(published_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_news_sports_sport '
      'ON news_item_sports(sport)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_news_sources_source '
      'ON news_item_sources(source_id)',
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
    if (oldVersion < 4) {
      // 0.9.0: forrás-index a szűréshez. A kapcsolótáblákat biztonság
      // kedvéért létrehozzuk, ha egy korai adatbázisból hiányoznának.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS news_item_sports (
          item_id INTEGER NOT NULL,
          sport TEXT NOT NULL,
          PRIMARY KEY(item_id, sport),
          FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS news_item_sources (
          item_id INTEGER NOT NULL,
          source_id TEXT NOT NULL,
          PRIMARY KEY(item_id, source_id),
          FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE,
          FOREIGN KEY(source_id) REFERENCES news_sources(id)
        )
      ''');
      await _createIndexes(db);
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

  /// Cikkek mentése egyetlen tranzakcióban, cikkenként egy upserttel és két
  /// kapcsolósorral (egy batch-ben, oda-vissza lekérdezés nélkül).
  ///
  /// Meglévő cikknél a cím, a keresőszöveg és a letöltési idő frissül; az
  /// összefoglaló, kép és szerző csak nem üres új értékkel; a megjelenési
  /// dátum csak akkor, ha a hírfolyamból értelmezett dátum érkezett
  /// ([NewsArticle.publishedAtParsed]). Az új cikkek számát adja vissza.
  Future<int> saveArticles(List<NewsArticle> articles) async {
    if (articles.isEmpty) return 0;
    final db = await database;
    return db.transaction((txn) async {
      final before = await _countItems(txn);
      final batch = txn.batch();
      for (final article in articles) {
        batch.rawInsert(_upsertSql, [
          article.dedupeKey,
          article.sourceId,
          article.sourceName,
          article.externalId,
          article.title,
          article.summary,
          article.url,
          article.imageUrl,
          article.author,
          article.searchText,
          article.publishedAt.millisecondsSinceEpoch,
          article.fetchedAt.millisecondsSinceEpoch,
          article.publishedAtParsed ? 1 : 0,
        ]);
        batch.rawInsert(
          'INSERT OR IGNORE INTO news_item_sports (item_id, sport) '
          'SELECT id, ? FROM news_items WHERE dedupe_key = ?',
          [article.sport, article.dedupeKey],
        );
        batch.rawInsert(
          'INSERT OR IGNORE INTO news_item_sources (item_id, source_id) '
          'SELECT id, ? FROM news_items WHERE dedupe_key = ?',
          [article.sourceId, article.dedupeKey],
        );
      }
      await batch.commit(noResult: true);
      return await _countItems(txn) - before;
    });
  }

  static Future<int> _countItems(DatabaseExecutor db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM news_items');
    return (rows.first['count'] as int?) ?? 0;
  }

  static const _upsertSql = '''
    INSERT INTO news_items (
      dedupe_key, source_id, source_name, external_id, title, summary, url,
      image_url, author, search_text, published_at, fetched_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(dedupe_key) DO UPDATE SET
      title = excluded.title,
      summary = CASE WHEN excluded.summary <> ''
        THEN excluded.summary ELSE news_items.summary END,
      image_url = CASE WHEN excluded.image_url <> ''
        THEN excluded.image_url ELSE news_items.image_url END,
      author = CASE WHEN excluded.author <> ''
        THEN excluded.author ELSE news_items.author END,
      search_text = excluded.search_text,
      -- Dátum nélküli tételnél megtartjuk az első mentéskori időt, különben
      -- minden frissítéskor a lista tetejére ugrana.
      published_at = CASE WHEN ? = 1
        THEN excluded.published_at ELSE news_items.published_at END,
      fetched_at = excluded.fetched_at
  ''';

  /// Régi cikkek törlése a [retention] szerint; a kapcsolósorok a külső
  /// kulcs `ON DELETE CASCADE` szabályával, az FTS-index triggerrel törlődik.
  /// A törölt cikkek számát adja vissza.
  Future<int> applyRetention(NewsRetention retention, {DateTime? now}) async {
    final db = await database;
    final cutoff = (now ?? DateTime.now())
        .subtract(retention.maxAge)
        .millisecondsSinceEpoch;
    return db.rawDelete(
      '''
      DELETE FROM news_items
      WHERE published_at < ?
        AND id NOT IN (
          SELECT id FROM news_items
          ORDER BY published_at DESC, id DESC
          LIMIT ?
        )
      ''',
      [cutoff, retention.minArticles],
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
    // A keresőszöveg normalizált (csak a-z, 0-9 és szóköz), így idézőjelek
    // közé téve biztonságos FTS5-kifejezés. A trigram index legalább 3
    // karakteres részszóra működik; rövidebbre marad a LIKE.
    final ftsTerms = <String>[];
    final normalized = normalizeAthleteName(text);
    if (normalized.isNotEmpty) {
      if (_fullTextSearch && normalized.length >= 3) {
        ftsTerms.add('"$normalized"');
      } else {
        where.add('n.search_text LIKE ?');
        args.add('%$normalized%');
      }
    }
    if (athleteName != 'Mind') {
      final tokens = normalizeAthleteName(
        athleteName,
      ).split(' ').where((token) => token.length >= 3);
      for (final token in tokens) {
        if (_fullTextSearch) {
          ftsTerms.add('"$token"');
        } else {
          where.add('n.search_text LIKE ?');
          args.add('%$token%');
        }
      }
    }
    if (ftsTerms.isNotEmpty) {
      where.add('n.id IN (SELECT rowid FROM news_fts WHERE news_fts MATCH ?)');
      args.add(ftsTerms.join(' AND '));
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
      LIMIT ? OFFSET ?
    ''',
      [...args, limit, offset],
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
    final opening = _database;
    _database = null;
    if (opening == null) return;
    try {
      await (await opening).close();
    } catch (_) {
      // A sikertelen megnyitást nem kell lezárni.
    }
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
