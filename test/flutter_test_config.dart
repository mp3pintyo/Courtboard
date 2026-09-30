import 'dart:async';
import 'dart:io';

import 'package:courtboard/data/app_paths.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/rate_limit.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/shared/images.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minden tesztfájlra érvényes környezet: a tesztek soha nem írnak a valódi
/// `%APPDATA%` alá, a közös gyorsítótár és kvótaszámláló memóriában él, és
/// a közös HTTP-réteg nem küld valódi hálózati kérést, az API-kulcsok pedig
/// memóriában élnek (a Windows biztonságos tárolóját a tesztek nem érintik),
/// a hálózati képek pedig nem töltődnek le.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final root = Directory.systemTemp.createTempSync('courtboard-test-');
  AppPaths.overrideRoot(root.path);
  CacheStorage.shared = MemoryCacheStorage();
  SecretStore.shared = MemorySecretStore();
  // A hálózati képek a tesztekben soha nem töltődnek be: a helyőrző látszik
  // (a letöltési hiba nem kerül a tesztek hibalistájára).
  ImageDiskCache.shared = ImageDiskCache(
    loader: (_) => Completer<Uint8List>().future,
  );
  // A tesztek sok, egymástól független hírtárat nyitnak (memóriában vagy
  // külön ideiglenes fájlban); a drift figyelmeztetése itt nem releváns.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  HttpService.shared = HttpService(
    networkEnabled: false,
    quota: QuotaTracker(storage: MemoryCacheStorage()),
  );
  tearDownAll(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {
      // Windows alatt egy még nyitott fájl megakadályozhatja a törlést.
    }
  });
  await testMain();
}
