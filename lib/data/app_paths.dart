import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:courtboard/data/file_util.dart';

/// A Courtboard által írt fájlok és könyvtárak egyetlen helyen.
///
/// Minden gyorsítótár a [cacheRoot] alatt, szolgáltatónként külön
/// névtérben él (`%APPDATA%\Courtboard\cache\<névtér>`). A felhasználói
/// állapot és a videólista a korábbi helyén marad, hogy a meglévő adatok
/// költöztetés nélkül betöltődjenek.
abstract final class AppPaths {
  static String? _rootOverride;

  /// Az alkalmazás adatkönyvtára: `%APPDATA%\Courtboard`.
  static String get root => _rootOverride ?? '${appDataPath()}/Courtboard';

  /// Az összes gyorsítótár közös gyökere.
  static String get cacheRoot => '$root/cache';

  /// Egy szolgáltató gyorsítótár-könyvtára.
  static String cacheDirectory(String namespace) => '$cacheRoot/$namespace';

  /// A hírarchívum SQLite-adatbázisa.
  static String get newsDatabase => '$root/courtboard_news.sqlite';

  /// A helyi állapotfájl (a korábbi verziókkal azonos helyen).
  static String get stateFile => '$_legacyBase/courtboard_state.json';

  /// A saját videólista (a korábbi verziókkal azonos helyen).
  static String get playlistFile => '$_legacyBase/courtboard_playlist.json';

  static String get _legacyBase => _rootOverride ?? appDataPath();

  /// A 0.9.0 előtti, szétszórt gyorsítótárak (`%APPDATA%\courtboard_cache`,
  /// `%APPDATA%\Courtboard\wnba_cache`) eltakarítása. A wehoop szezonfájlokat
  /// (több MB) átnevezéssel átviszi az új helyre, a többi régi cache-t
  /// törli; minden hiba csendben elnyelődik, mert ez csak takarítás.
  static Future<void> migrateLegacyCaches() async {
    try {
      final wehoop = Directory('$root/wnba_cache');
      final target = Directory(cacheDirectory('wehoop_wnba'));
      if (await wehoop.exists()) {
        if (!await target.exists()) {
          await target.parent.create(recursive: true);
          await wehoop.rename(target.path);
        } else {
          await wehoop.delete(recursive: true);
        }
      }
    } catch (_) {
      // A régi könyvtár maradhat; a következő indításkor újrapróbáljuk.
    }
    try {
      final old = Directory('$_legacyBase/courtboard_cache');
      if (await old.exists()) await old.delete(recursive: true);
    } catch (_) {
      // Lásd fent.
    }
  }

  /// Tesztekhez: az összes útvonal a megadott könyvtár alá kerül
  /// (`null` visszaállítja az alapértelmezést).
  @visibleForTesting
  static void overrideRoot(String? path) => _rootOverride = path;
}
