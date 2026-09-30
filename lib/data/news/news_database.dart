/// A hírarchívum drift-adatbázisa: a séma a `news_database.drift` fájlban,
/// a generált kód a `news_database.g.dart`-ban (`dart run build_runner
/// build`).
///
/// A 0.14.0 előtt a tárat a `sqflite_common_ffi` kezelte (4-es
/// sémaverzió, `PRAGMA user_version = 4`). A drift ugyanazt a fájlt,
/// ugyanazokkal a tábla- és oszlopnevekkel nyitja meg; a 4 → 5 lépés csak
/// jelzi az átállást, adatot és szerkezetet nem módosít. A 4 előtti
/// verziókból a korábbi tár lépései futnak le változatlanul.
library;

import 'package:drift/drift.dart';

import 'package:courtboard/data/news/news_db_converters.dart';
import 'package:courtboard/data/news/news_sources.dart' as catalog;

part 'news_database.g.dart';

@DriftDatabase(include: {'news_database.drift'})
class NewsDatabase extends _$NewsDatabase {
  NewsDatabase(super.executor);

  /// 1–4: a sqflite-tár verziói; 5: ugyanaz a séma drifttel (0.14.0).
  @override
  int get schemaVersion => 5;

  /// Az utolsó sqflite-sémaverzió, amelyet a drift változtatás nélkül
  /// átvesz.
  static const legacySchemaVersion = 4;

  /// Igaz, ha a beépített SQLite támogatja az FTS5 `trigram` tokenizálót,
  /// és a teljes szöveges index elkészült (a megnyitás után értelmes);
  /// különben a keresés `LIKE`-kal fut.
  bool get fullTextSearch => _fullTextSearch;
  bool _fullTextSearch = false;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => transaction(m.createAll),
    onUpgrade: (m, from, to) => transaction(() => _upgrade(m, from)),
    beforeOpen: (details) async =>
        _fullTextSearch = await _seedAndEnsureFullTextSearch(),
  );

  /// A korábbi (sqflite) tár migrációi. Nyers SQL, mert a régi sémán
  /// futnak; a táblákat és indexeket csak akkor hozza létre, ha hiányoznak.
  Future<void> _upgrade(Migrator m, int from) async {
    if (from < 3) {
      // The first parser used the fetch time when an RSS date contained a
      // numeric offset or an ESPN-style named timezone. Remove only those
      // demonstrably corrupted fallback-date rows; the next refresh restores
      // them with their real publication date.
      await customStatement(
        'DELETE FROM news_items '
        "WHERE (source_id LIKE 'fox_%' OR source_id LIKE 'cbs_%' "
        "OR source_id LIKE 'espn_%') "
        'AND ABS(published_at - fetched_at) < 60000',
      );
      // Every FOX source now uses the fresher page JSON feed instead of the
      // optimized RSS endpoint. Force an immediate request with clean HTTP
      // validators after the source URLs are reseeded.
      await customStatement(
        'UPDATE news_sources '
        "SET last_success_at = NULL, etag = '', last_modified = '' "
        "WHERE id LIKE 'fox_%'",
      );
    }
    if (from < legacySchemaVersion) {
      // 0.9.0: forrás-index a szűréshez. A kapcsolótáblákat biztonság
      // kedvéért létrehozzuk, ha egy korai adatbázisból hiányoznának
      // (`CREATE TABLE IF NOT EXISTS`).
      await m.createTable(newsItemSports);
      await m.createTable(newsItemSources);
      await m.createIndex(idxNewsItemsPublished);
      await m.createIndex(idxNewsSportsSport);
      await m.createIndex(idxNewsSourcesSource);
    }
    // 4 → 5: a drift a 4-es sémát változatlanul használja.
  }

  /// Minden megnyitáskor: a beépített forráslista beírása (a felhasználói
  /// be/kikapcsolás és a frissítési állapot megmarad), valamint az FTS5
  /// trigram index és a szinkronizáló triggerek ellenőrzése. A trigram
  /// tokenizáló a `LIKE '%…%'` keresés részszó-szemantikáját indexelten adja.
  ///
  /// Megszokott indulásnál ez két kérés a háttér-isolate felé: az index
  /// próbája, majd egyetlen batch (egy tranzakció) a forrásokkal és a
  /// triggerekkel. Az index első létrehozása a meglévő cikkeket is
  /// indexeli. Ha az FTS5 modul nem érhető el, a triggereket eltávolítja
  /// (különben minden beszúrás hibára futna), és `false`-szal `LIKE`
  /// keresésre vált.
  Future<bool> _seedAndEnsureFullTextSearch() async {
    if (await _fullTextTableUsable()) {
      try {
        await batch((b) {
          _seedSources(b);
          for (final trigger in fullTextTriggers) {
            b.customStatement(trigger);
          }
        });
        return true;
      } catch (_) {
        // Lent: a források külön, a keresés LIKE-kal.
      }
    }
    await batch(_seedSources);
    return _createFullTextSearch();
  }

  /// Létezik-e és használható-e (a modul elérhető) az FTS-tábla.
  Future<bool> _fullTextTableUsable() async {
    try {
      await customSelect('SELECT rowid FROM news_fts LIMIT 0').get();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _seedSources(Batch b) {
    for (final source in catalog.newsSources) {
      b.insert(
        newsSources,
        NewsSourcesCompanion.insert(
          id: source.id,
          name: source.name,
          sport: source.sport,
          url: source.url,
          homepage: source.homepage,
          enabled: source.enabledByDefault,
          termsNote: Value(source.termsNote),
        ),
        onConflict: DoUpdate<NewsSources, NewsSourceRow>.withExcluded(
          (old, excluded) => NewsSourcesCompanion.custom(
            name: excluded.name,
            sport: excluded.sport,
            url: excluded.url,
            homepage: excluded.homepage,
            termsNote: excluded.termsNote,
          ),
        ),
      );
    }
  }

  /// Az FTS-index első létrehozása (a meglévő cikkek indexelésével) egy
  /// tranzakcióban; ha a tábla már létezik, de nem használható, vagy a
  /// létrehozás nem sikerül, a triggerek eltávolítása és `false`.
  Future<bool> _createFullTextSearch() async {
    try {
      final existing = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'news_fts'",
      ).get();
      if (existing.isNotEmpty) throw StateError('FTS5 nem érhető el');
      await transaction(() async {
        await customStatement(_createFullTextTable);
        for (final trigger in fullTextTriggers) {
          await customStatement(trigger);
        }
        await customStatement(
          "INSERT INTO news_fts(news_fts) VALUES ('rebuild')",
        );
      });
      return await _fullTextTableUsable();
    } catch (_) {
      for (final name in fullTextTriggerNames) {
        try {
          await customStatement('DROP TRIGGER IF EXISTS $name');
        } catch (_) {
          // A trigger eltávolítása nélkül is próbálkozunk a többivel.
        }
      }
      return false;
    }
  }

  static const _createFullTextTable = '''
    CREATE VIRTUAL TABLE news_fts USING fts5(
      search_text,
      content = 'news_items',
      content_rowid = 'id',
      tokenize = 'trigram'
    )
  ''';

  /// Az FTS-indexet a `news_items` táblával szinkronban tartó triggerek.
  static const fullTextTriggerNames = [
    'news_items_fts_insert',
    'news_items_fts_delete',
    'news_items_fts_update',
  ];

  static const fullTextTriggers = [
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
  ];
}
