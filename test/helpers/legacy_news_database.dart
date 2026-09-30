/// A 0.13.0-ig használt sqflite-hírtár sémája (4-es verzió), a régi
/// `NewsStore._create` / `_ensureFullTextSearch` DDL-jének szó szerinti
/// másolata. A migrációs tesztek ezzel hoznak létre „régi” adatbázist,
/// amelyet aztán a drift-alapú [NewsStore] nyit meg.
///
/// A régi tár a sqflite_common_ffi-n át ugyanazt a sqlite3 csomagot
/// használta, mint most a drift, ezért itt is közvetlenül azzal írunk.
library;

import 'package:sqlite3/sqlite3.dart';

const legacyV4Tables = [
  '''
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
  ''',
  '''
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
  ''',
  '''
      CREATE TABLE news_item_sports (
        item_id INTEGER NOT NULL,
        sport TEXT NOT NULL,
        PRIMARY KEY(item_id, sport),
        FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE
      )
  ''',
  '''
      CREATE TABLE news_item_sources (
        item_id INTEGER NOT NULL,
        source_id TEXT NOT NULL,
        PRIMARY KEY(item_id, source_id),
        FOREIGN KEY(item_id) REFERENCES news_items(id) ON DELETE CASCADE,
        FOREIGN KEY(source_id) REFERENCES news_sources(id)
      )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_news_items_published '
      'ON news_items(published_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_news_sports_sport '
      'ON news_item_sports(sport)',
  'CREATE INDEX IF NOT EXISTS idx_news_sources_source '
      'ON news_item_sources(source_id)',
];

const legacyV4FullText = [
  '''
          CREATE VIRTUAL TABLE news_fts USING fts5(
            search_text,
            content = 'news_items',
            content_rowid = 'id',
            tokenize = 'trigram'
          )
  ''',
  '''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_insert
          AFTER INSERT ON news_items BEGIN
            INSERT INTO news_fts(rowid, search_text)
            VALUES (new.id, new.search_text);
          END
  ''',
  '''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_delete
          AFTER DELETE ON news_items BEGIN
            INSERT INTO news_fts(news_fts, rowid, search_text)
            VALUES ('delete', old.id, old.search_text);
          END
  ''',
  '''
          CREATE TRIGGER IF NOT EXISTS news_items_fts_update
          AFTER UPDATE OF search_text ON news_items BEGIN
            INSERT INTO news_fts(news_fts, rowid, search_text)
            VALUES ('delete', old.id, old.search_text);
            INSERT INTO news_fts(rowid, search_text)
            VALUES (new.id, new.search_text);
          END
  ''',
  "INSERT INTO news_fts(news_fts) VALUES ('rebuild')",
];

/// Egy régi hírforrás-sor.
class LegacySource {
  const LegacySource(
    this.id, {
    required this.name,
    required this.sport,
    this.enabled = true,
    this.url = 'https://legacy.example/feed',
    this.lastSuccessAt,
    this.lastError = '',
    this.etag = '',
    this.lastModified = '',
  });

  final String id;
  final String name;
  final String sport;
  final bool enabled;
  final String url;
  final int? lastSuccessAt;
  final String lastError;
  final String etag;
  final String lastModified;
}

/// Egy régi cikk a kapcsolósoraival.
class LegacyArticle {
  const LegacyArticle({
    required this.dedupeKey,
    required this.sourceId,
    required this.title,
    required this.searchText,
    required this.publishedAt,
    required this.sports,
    required this.sources,
    this.summary = '',
    this.imageUrl = '',
    this.author = '',
  });

  final String dedupeKey;
  final String sourceId;
  final String title;
  final String summary;
  final String imageUrl;
  final String author;
  final String searchText;
  final int publishedAt;
  final List<String> sports;
  final List<String> sources;
}

/// Régi (sqflite-kori) hírarchívum létrehozása a [path] fájlban.
///
/// [version] a `PRAGMA user_version` értéke (a sqflite ebben tartotta a
/// sémaverziót). [fullText] hamis értéke egy FTS5 nélküli SQLite-tal
/// létrehozott (index és triggerek nélküli) 4-es adatbázist utánoz.
/// A cikkek sorrendben kapják az 1, 2, … azonosítót.
void createLegacyNewsDatabase(
  String path, {
  required List<LegacySource> sources,
  required List<LegacyArticle> articles,
  int version = 4,
  bool fullText = true,
}) {
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    for (final statement in legacyV4Tables) {
      db.execute(statement);
    }
    if (fullText) {
      for (final statement in legacyV4FullText) {
        db.execute(statement);
      }
    }
    for (final source in sources) {
      db.execute(
        'INSERT INTO news_sources (id, name, sport, url, homepage, enabled, '
        'terms_note, last_attempt_at, last_success_at, last_error, etag, '
        'last_modified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          source.id,
          source.name,
          source.sport,
          source.url,
          'https://legacy.example',
          source.enabled ? 1 : 0,
          '',
          source.lastSuccessAt,
          source.lastSuccessAt,
          source.lastError,
          source.etag,
          source.lastModified,
        ],
      );
    }
    for (final article in articles) {
      db.execute(
        'INSERT INTO news_items (dedupe_key, source_id, source_name, '
        'external_id, title, summary, url, image_url, author, search_text, '
        'published_at, fetched_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          article.dedupeKey,
          article.sourceId,
          'Legacy',
          'ext-${article.dedupeKey}',
          article.title,
          article.summary,
          'https://example.com/${article.dedupeKey}',
          article.imageUrl,
          article.author,
          article.searchText,
          article.publishedAt,
          article.publishedAt + 1000,
        ],
      );
      final id = db.lastInsertRowId;
      for (final sport in article.sports) {
        db.execute(
          'INSERT INTO news_item_sports (item_id, sport) VALUES (?, ?)',
          [id, sport],
        );
      }
      for (final source in article.sources) {
        db.execute(
          'INSERT INTO news_item_sources (item_id, source_id) VALUES (?, ?)',
          [id, source],
        );
      }
    }
    db.execute('PRAGMA user_version = $version');
  } finally {
    db.close();
  }
}

/// A [path] adatbázis `PRAGMA user_version` értéke és sémaelemei
/// (`type:name` alakban), közvetlen sqlite3-kapcsolattal.
({int version, Set<String> schema}) inspectNewsDatabase(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final version = db.select('PRAGMA user_version').single.columnAt(0) as int;
    final schema = {
      for (final row in db.select(
        "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
      ))
        '${row['type']}:${row['name']}',
    };
    return (version: version, schema: schema);
  } finally {
    db.close();
  }
}
