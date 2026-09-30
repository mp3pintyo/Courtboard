import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/file_util.dart';

/// Gyorsítótárból vagy hálózatról érkezett érték a frissességi adataival.
class CachedValue<T> {
  const CachedValue(
    this.value, {
    required this.fetchedAt,
    this.fromCache = false,
    this.stale = false,
  });

  final T value;

  /// Az adat letöltésének ideje (gyorsítótárból érkező adatnál az eredeti
  /// letöltésé, nem a mostani olvasásé).
  final DateTime fetchedAt;

  /// Igaz, ha az érték lemezről/memóriából jött, nem a mostani hálózati
  /// kérésből.
  final bool fromCache;

  /// Igaz, ha a gyorsítótárbeli érték már lejárt, de a frissítés hibára
  /// futott, ezért a régebbi példányt adjuk vissza.
  final bool stale;

  CachedValue<R> map<R>(R Function(T value) transform) => CachedValue<R>(
    transform(value),
    fetchedAt: fetchedAt,
    fromCache: fromCache,
    stale: stale,
  );
}

/// Egy tárolt bejegyzés nyers tartalma és utolsó módosítási ideje.
class CacheRecord {
  const CacheRecord(this.contents, this.modified);
  final String contents;
  final DateTime modified;
}

/// A gyorsítótár háttértára (lemez vagy – tesztben – memória).
abstract interface class CacheStorage {
  Future<CacheRecord?> read(String namespace, String name);
  Future<void> write(String namespace, String name, String contents);
  Future<void> delete(String namespace, String name);

  static CacheStorage? _shared;

  /// Az alkalmazás közös háttértára: [AppPaths.cacheRoot] alatti fájlok.
  static CacheStorage get shared => _shared ??= FileCacheStorage();

  /// Tesztekhez: a közös háttértár cseréje (`null` visszaállítja).
  @visibleForTesting
  static set shared(CacheStorage? value) => _shared = value;
}

/// Lemezes háttértár: `<gyökér>/<névtér>/<név>`, atomikus írással.
class FileCacheStorage implements CacheStorage {
  /// [rootPath] nélkül az [AppPaths.cacheRoot] a gyökér (lustán kiértékelve,
  /// így a tesztbeli felülírás is érvényesül).
  FileCacheStorage({this._rootPath}) : _flat = false;

  /// Minden névtér közvetlenül a megadott könyvtárba ír.
  FileCacheStorage.flat(String this._rootPath) : _flat = true;

  final String? _rootPath;
  final bool _flat;

  String directoryFor(String namespace) =>
      _flat ? _rootPath! : '${_rootPath ?? AppPaths.cacheRoot}/$namespace';

  File fileFor(String namespace, String name) =>
      File('${directoryFor(namespace)}/$name');

  @override
  Future<CacheRecord?> read(String namespace, String name) async {
    final file = fileFor(namespace, name);
    try {
      if (!await file.exists()) return null;
      final modified = await file.lastModified();
      return CacheRecord(await file.readAsString(), modified);
    } on FileSystemException {
      return null;
    } on FormatException {
      // Nem UTF-8 tartalom: sérült bejegyzésként kezeljük.
      return null;
    }
  }

  @override
  Future<void> write(String namespace, String name, String contents) =>
      writeFileAtomic(fileFor(namespace, name), contents);

  @override
  Future<void> delete(String namespace, String name) async {
    try {
      await fileFor(namespace, name).delete();
    } on FileSystemException {
      // Nem létező vagy zárolt fájl: a törlés nem kritikus.
    }
  }
}

/// Memóriabeli háttértár tesztekhez és lemez nélküli futtatáshoz.
class MemoryCacheStorage implements CacheStorage {
  MemoryCacheStorage({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, CacheRecord> _records = {};

  /// A tárolt bejegyzések száma (tesztekhez).
  int get length => _records.length;

  @override
  Future<CacheRecord?> read(String namespace, String name) async =>
      _records['$namespace/$name'];

  @override
  Future<void> write(String namespace, String name, String contents) async {
    _records['$namespace/$name'] = CacheRecord(contents, _clock());
  }

  @override
  Future<void> delete(String namespace, String name) async {
    _records.remove('$namespace/$name');
  }
}

/// Egységes, névterenkénti JSON-gyorsítótár.
///
/// * Friss bejegyzésnél ([ttl]-en belül) nem indul hálózati kérés.
/// * Lejárt bejegyzésnél letölt; ha ez hibára fut, a régi értéket adja
///   vissza `stale: true` jelzéssel ([allowStale]).
/// * Ugyanarra a kulcsra egyszerre futó hívások ugyanazt a Future-t kapják.
/// * „Nem található” eredmény (alapból `null`) külön [missTtl] ideig
///   tárolható (negatív cache), így a hiábavaló keresés nem ismétlődik.
///
/// A bejegyzés egy boríték: `{"v":1,"fetchedAt":…,"miss":…,"data":…}`; a
/// frissességet a tárolt letöltési idő dönti el, nem a fájl módosítási ideje.
class JsonFileCache {
  JsonFileCache(
    this.namespace, {
    CacheStorage? storage,
    Directory? directory,
    DateTime Function()? clock,
  }) : storage =
           storage ??
           (directory == null
               ? CacheStorage.shared
               : FileCacheStorage.flat(directory.path)),
       _clock = clock ?? DateTime.now;

  final String namespace;
  final CacheStorage storage;
  final DateTime Function() _clock;

  /// Háttértáranként a folyamatban lévő letöltések (példányok között is
  /// közösek, így két repository-példány sem tölti le kétszer ugyanazt).
  static final Expando<Map<String, Future<Object?>>> _inFlight = Expando();

  Map<String, Future<Object?>> get _pending =>
      _inFlight[storage] ??= <String, Future<Object?>>{};

  static const _version = 1;

  /// Biztonságos fájlnév egy tetszőleges kulcsból.
  static String fileNameFor(String key, {String extension = '.json'}) {
    if (RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,119}$').hasMatch(key)) {
      return '$key$extension';
    }
    var slug = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    if (slug.length > 60) slug = slug.substring(0, 60);
    return '${slug}_${fnv1a32Hex(key)}$extension';
  }

  Future<CachedValue<T>> getOrFetch<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() fetch,
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
    bool allowStale = true,
    bool forceRefresh = false,
    Duration? missTtl,
    bool Function(T value)? isMiss,
  }) {
    final pendingKey = '$namespace/$key';
    final pending = _pending[pendingKey];
    if (pending != null) return pending as Future<CachedValue<T>>;
    final future = _load<T>(
      key,
      ttl: ttl,
      fetch: fetch,
      encode: encode,
      decode: decode,
      allowStale: allowStale,
      forceRefresh: forceRefresh,
      missTtl: missTtl,
      isMiss: isMiss,
    );
    final map = _pending;
    map[pendingKey] = future;
    void cleanup() =>
        map.removeWhere((k, v) => k == pendingKey && identical(v, future));

    // A hívó kapja meg (és kezeli) a hibát; ez csak a nyilvántartást takarítja.
    unawaited(future.then((_) => cleanup(), onError: (Object _) => cleanup()));
    return future;
  }

  Future<CachedValue<T>> _load<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() fetch,
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
    required bool allowStale,
    required bool forceRefresh,
    required Duration? missTtl,
    required bool Function(T value)? isMiss,
  }) async {
    final entry = await _readEntry(key);
    (T,)? decoded;
    if (entry != null) {
      try {
        decoded = (decode(entry.data),);
      } catch (_) {
        decoded = null; // Sérült vagy régi formátumú bejegyzés.
      }
    }
    if (entry != null && decoded != null && !forceRefresh) {
      final lifetime = entry.miss ? (missTtl ?? Duration.zero) : ttl;
      final age = _clock().difference(entry.fetchedAt);
      if (!age.isNegative && age < lifetime) {
        return CachedValue<T>(
          decoded.$1,
          fetchedAt: entry.fetchedAt,
          fromCache: true,
        );
      }
    }

    final T value;
    try {
      value = await fetch();
    } catch (error, stack) {
      if (allowStale && entry != null && decoded != null) {
        return CachedValue<T>(
          decoded.$1,
          fetchedAt: entry.fetchedAt,
          fromCache: true,
          stale: true,
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
    final fetchedAt = _clock();
    final miss = isMiss?.call(value) ?? value == null;
    if (!miss || missTtl != null) {
      try {
        await storage.write(
          namespace,
          fileNameFor(key),
          jsonEncode({
            'v': _version,
            'fetchedAt': fetchedAt.toUtc().toIso8601String(),
            'miss': miss,
            'data': encode(value),
          }),
        );
      } catch (_) {
        // A mentés hibája (tele lemez, zárolt fájl) nem ronthatja el a
        // már sikeresen letöltött választ.
      }
    }
    return CachedValue<T>(value, fetchedAt: fetchedAt);
  }

  Future<_Entry?> _readEntry(String key) async {
    try {
      final record = await storage.read(namespace, fileNameFor(key));
      if (record == null) return null;
      final decoded = jsonDecode(record.contents);
      if (decoded is! Map || decoded['v'] != _version) return null;
      final fetchedAt = DateTime.tryParse('${decoded['fetchedAt'] ?? ''}');
      if (fetchedAt == null) return null;
      return _Entry(
        fetchedAt.toLocal(),
        decoded['miss'] == true,
        decoded['data'],
      );
    } catch (_) {
      return null;
    }
  }

  /// A kulcs bejegyzésének törlése.
  Future<void> remove(String key) =>
      storage.delete(namespace, fileNameFor(key));

  /// Nyers szöveges bejegyzés (például CSV) a módosítási idejével; a
  /// fájlnév változatlanul a [name].
  Future<CacheRecord?> readText(String name) async {
    try {
      return await storage.read(namespace, name);
    } catch (_) {
      return null;
    }
  }

  /// Nyers szöveges bejegyzés atomikus mentése.
  Future<void> writeText(String name, String contents) =>
      storage.write(namespace, name, contents);
}

class _Entry {
  const _Entry(this.fetchedAt, this.miss, this.data);
  final DateTime fetchedAt;
  final bool miss;
  final Object? data;
}
