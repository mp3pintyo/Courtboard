import 'dart:async';
import 'dart:io';

import 'package:courtboard/data/json_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late MemoryCacheStorage storage;
  late JsonFileCache cache;

  setUp(() {
    now = DateTime(2026, 9, 30, 12);
    storage = MemoryCacheStorage(clock: () => now);
    cache = JsonFileCache('teszt', storage: storage, clock: () => now);
  });

  Future<CachedValue<Map<String, dynamic>>> load(
    Future<Map<String, dynamic>> Function() fetch, {
    Duration ttl = const Duration(hours: 1),
    bool allowStale = true,
  }) => cache.getOrFetch<Map<String, dynamic>>(
    'kulcs',
    ttl: ttl,
    fetch: fetch,
    encode: (value) => value,
    decode: (json) => Map<String, dynamic>.from(json as Map),
    allowStale: allowStale,
  );

  test(
    'fresh entries are served without fetching until the TTL expires',
    () async {
      var calls = 0;
      Future<Map<String, dynamic>> fetch() async => {'n': ++calls};

      final first = await load(fetch);
      now = now.add(const Duration(minutes: 59));
      final second = await load(fetch);
      now = now.add(const Duration(minutes: 2));
      final third = await load(fetch);

      expect(first.value['n'], 1);
      expect(first.fromCache, isFalse);
      expect(first.fetchedAt, DateTime(2026, 9, 30, 12));
      expect(second.value['n'], 1);
      expect(second.fromCache, isTrue);
      expect(second.fetchedAt, DateTime(2026, 9, 30, 12));
      expect(third.value['n'], 2);
      expect(third.fromCache, isFalse);
      expect(calls, 2);
    },
  );

  test('expired entry is returned as stale when the refresh fails', () async {
    await load(() async => {'n': 1});
    now = now.add(const Duration(hours: 2));

    final stale = await load(() async => throw const SocketException('x'));

    expect(stale.value['n'], 1);
    expect(stale.stale, isTrue);
    expect(stale.fromCache, isTrue);
    await expectLater(
      load(() async => throw const SocketException('x'), allowStale: false),
      throwsA(isA<SocketException>()),
    );
  });

  test('a failure without any cached entry is rethrown', () async {
    await expectLater(
      load(() async => throw StateError('nincs adat')),
      throwsA(isA<StateError>()),
    );
    expect(storage.length, 0);
  });

  test('concurrent callers of the same key share one fetch', () async {
    var calls = 0;
    final gate = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> fetch() {
      calls++;
      return gate.future;
    }

    final first = load(fetch);
    final second = load(fetch);
    // Egy másik példány ugyanazon a háttértáron is ugyanazt a kérést kapja.
    final other = JsonFileCache('teszt', storage: storage, clock: () => now)
        .getOrFetch<Map<String, dynamic>>(
          'kulcs',
          ttl: const Duration(hours: 1),
          fetch: fetch,
          encode: (value) => value,
          decode: (json) => Map<String, dynamic>.from(json as Map),
        );
    gate.complete({'n': 7});

    expect(identical(first, second), isTrue);
    expect((await first).value['n'], 7);
    expect((await other).value['n'], 7);
    expect(calls, 1);

    // A befejezett kérés után új letöltés indulhat.
    await cache.getOrFetch<Map<String, dynamic>>(
      'kulcs',
      ttl: const Duration(hours: 1),
      forceRefresh: true,
      fetch: () async => {'n': 8},
      encode: (value) => value,
      decode: (json) => Map<String, dynamic>.from(json as Map),
    );
    expect((await load(fetch)).value['n'], 8);
  });

  test('negative results are cached only when a miss TTL is given', () async {
    var calls = 0;
    Future<CachedValue<String?>> lookup({Duration? missTtl}) =>
        cache.getOrFetch<String?>(
          'miss',
          ttl: const Duration(days: 7),
          missTtl: missTtl,
          fetch: () async {
            calls++;
            return null;
          },
          encode: (value) => value,
          decode: (json) => json as String?,
        );

    await lookup();
    await lookup();
    expect(calls, 2, reason: 'miss TTL nélkül nincs negatív cache');

    await lookup(missTtl: const Duration(hours: 24));
    now = now.add(const Duration(hours: 23));
    final cached = await lookup(missTtl: const Duration(hours: 24));
    expect(cached.value, isNull);
    expect(cached.fromCache, isTrue);
    expect(calls, 3);

    now = now.add(const Duration(hours: 2));
    await lookup(missTtl: const Duration(hours: 24));
    expect(calls, 4);
  });

  test(
    'file storage writes atomically under the namespace directory',
    () async {
      final root = await Directory.systemTemp.createTemp('courtboard-cache-');
      addTearDown(() => root.delete(recursive: true));
      final fileCache = JsonFileCache(
        'szolgaltato',
        storage: FileCacheStorage(rootPath: root.path),
      );

      final value = await fileCache.getOrFetch<List<int>>(
        'lista',
        ttl: const Duration(hours: 1),
        fetch: () async => [1, 2, 3],
        encode: (value) => value,
        decode: (json) => (json as List).cast<int>(),
      );
      final again = await fileCache.getOrFetch<List<int>>(
        'lista',
        ttl: const Duration(hours: 1),
        fetch: () async => throw StateError('nem kellene letölteni'),
        encode: (value) => value,
        decode: (json) => (json as List).cast<int>(),
      );

      expect(value.value, [1, 2, 3]);
      expect(again.value, [1, 2, 3]);
      expect(again.fromCache, isTrue);
      final directory = Directory('${root.path}/szolgaltato');
      expect(directory.listSync().map((entry) => entry.uri.pathSegments.last), [
        'lista.json',
      ]);
    },
  );

  test('corrupt entries are ignored and replaced', () async {
    await storage.write('teszt', 'kulcs.json', '{nem json');
    final value = await load(() async => {'n': 1});
    expect(value.value['n'], 1);
    expect(value.fromCache, isFalse);
  });

  test('unsafe keys become stable, distinct file names', () {
    expect(
      JsonFileCache.fileNameFor('nba_nikola_jokic_2026'),
      'nba_nikola_jokic_2026.json',
    );
    final a = JsonFileCache.fileNameFor('/players|search=jokić');
    final b = JsonFileCache.fileNameFor('/players|search=jovic');
    expect(a, isNot(b));
    expect(a, matches(RegExp(r'^[A-Za-z0-9_-]+_[0-9a-f]{8}\.json$')));
    expect(JsonFileCache.fileNameFor('../../evil'), isNot(contains('/')));
  });

  test('raw text entries keep their file name and modification time', () async {
    await cache.writeText('player_box_2026.csv', 'a,b\n1,2');
    final record = await cache.readText('player_box_2026.csv');
    expect(record?.contents, 'a,b\n1,2');
    expect(record?.modified, now);
  });
}
