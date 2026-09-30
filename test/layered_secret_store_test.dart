// Az API-kulcsok új tárolója (flutter_secure_storage) és a Windows
// Hitelesítőadat-kezelőből való átköltöztetés hamis tárolókkal: a valódi
// Hitelesítőadat-kezelőt és a %APPDATA% alatti kulcsfájlt a tesztek soha nem
// érintik.
import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/flutter_secure_secret_store.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Műveleteket naplózó, kulcsonként hibáztatható memóriatároló.
class _ScriptedStore extends MemorySecretStore {
  _ScriptedStore({super.values});

  final List<String> log = [];

  /// Ezeknél a kulcsoknál az írás hibázik.
  final Set<String> failWrite = {};

  /// Ezeknél a kulcsoknál a törlés hibázik.
  final Set<String> failDelete = {};

  /// Ezeknél a kulcsoknál a visszaolvasott érték eltér a beírttól.
  final Set<String> corrupt = {};

  int get writes => log.where((entry) => entry.startsWith('write:')).length;

  @override
  Future<String?> read(String key) async {
    log.add('read:$key');
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    log.add('write:$key');
    if (failWrite.contains(key)) {
      throw SecretStoreException('Írás sikertelen: $key');
    }
    await super.write(key, corrupt.contains(key) ? '$value-hibás' : value);
  }

  @override
  Future<void> delete(String key) async {
    log.add('delete:$key');
    if (failDelete.contains(key)) {
      throw SecretStoreException('Törlés sikertelen: $key');
    }
    await super.delete(key);
  }
}

final _fd = ApiKeyId.footballData.secretName;
final _rapid = ApiKeyId.rapidApi.secretName;
final _tennis = ApiKeyId.liveTennis.secretName;
final _allKeys = ApiKeyId.values.map((id) => id.secretName).toList();

void main() {
  group('migrateLegacy (Hitelesítőadat-kezelő → flutter_secure_storage)', () {
    test(
      'sikeres költözés: írás, visszaolvasás, majd a régi törlése',
      () async {
        final primary = _ScriptedStore();
        final legacy = _ScriptedStore(
          values: {_fd: 'fd-secret', _rapid: 'rapid-secret'},
        );
        final store = LayeredSecretStore(primary: primary, legacy: legacy);

        final report = await store.migrateLegacy(_allKeys);

        expect(report.migrated, unorderedEquals([_fd, _rapid]));
        expect(report.fellBack, isFalse);
        expect(primary.values, {_fd: 'fd-secret', _rapid: 'rapid-secret'});
        expect(legacy.values, isEmpty);
        // A régi példány csak az ellenőrző visszaolvasás után törlődik.
        expect(
          primary.log.indexOf('read:$_fd'),
          lessThan(primary.log.lastIndexOf('read:$_fd')),
        );
        expect(store.usingFallback, isFalse);
        expect(await store.read(_fd), 'fd-secret');
      },
    );

    test(
      'eltérő visszaolvasás: a régi érték marad, a hibás példány törlődik',
      () async {
        final primary = _ScriptedStore()..corrupt.add(_rapid);
        final legacy = _ScriptedStore(
          values: {_fd: 'fd-secret', _rapid: 'rapid-secret'},
        );
        final store = LayeredSecretStore(primary: primary, legacy: legacy);

        final report = await store.migrateLegacy(_allKeys);

        expect(report.migrated, [_fd]);
        expect(report.keptInLegacy, [_rapid]);
        expect(legacy.values, {_rapid: 'rapid-secret'});
        expect(primary.values, {_fd: 'fd-secret'});
        // A régiben hagyott kulcs olvasáskor továbbra is elérhető.
        expect(await store.read(_rapid), 'rapid-secret');
        expect(store.usingFallback, isFalse);
      },
    );

    test(
      'részleges hiba: az új tároló írása elakad → tartalék, a régiből semmi nem törlődik',
      () async {
        final primary = _ScriptedStore()..failWrite.add(_rapid);
        final legacy = _ScriptedStore(
          values: {_fd: 'fd-secret', _rapid: 'rapid-secret'},
        );
        final store = LayeredSecretStore(primary: primary, legacy: legacy);

        final report = await store.migrateLegacy(_allKeys);

        expect(report.fellBack, isTrue);
        expect(report.migrated, isEmpty);
        expect(legacy.values, {_fd: 'fd-secret', _rapid: 'rapid-secret'});
        expect(legacy.log.where((e) => e.startsWith('delete:')), isEmpty);
        expect(store.usingFallback, isTrue);
        expect(store.description, contains('Hitelesítőadat-kezelő'));
        // Minden kulcs a tartalékból olvasható.
        expect(await store.read(_fd), 'fd-secret');
        expect(await store.read(_rapid), 'rapid-secret');
      },
    );

    test(
      'részleges hiba: a régi törlése hibázik → a következő indítás takarít',
      () async {
        final primary = _ScriptedStore();
        final legacy = _ScriptedStore(
          values: {_fd: 'fd-secret', _rapid: 'rapid-secret'},
        )..failDelete.add(_rapid);
        final store = LayeredSecretStore(primary: primary, legacy: legacy);

        final first = await store.migrateLegacy(_allKeys);
        expect(first.migrated, [_fd]);
        expect(first.legacyDeleteFailed, [_rapid]);
        expect(primary.values, {_fd: 'fd-secret', _rapid: 'rapid-secret'});

        legacy.failDelete.clear();
        final writesBefore = primary.writes;
        final second = await LayeredSecretStore(
          primary: primary,
          legacy: legacy,
        ).migrateLegacy(_allKeys);
        expect(second.cleanedUp, [_rapid]);
        expect(second.migrated, isEmpty);
        expect(primary.writes, writesBefore, reason: 'nincs újraírás');
        expect(legacy.values, isEmpty);
      },
    );

    test('nincs kétszeres költözés, és az új tároló értéke nyer', () async {
      final primary = _ScriptedStore(values: {_tennis: 'új-érték'});
      final legacy = _ScriptedStore(
        values: {_fd: 'fd-secret', _tennis: 'régi-érték'},
      );
      final store = LayeredSecretStore(primary: primary, legacy: legacy);

      final first = await store.migrateLegacy(_allKeys);
      expect(first.migrated, [_fd]);
      final writesAfterFirst = primary.writes;

      final second = await store.migrateLegacy(_allKeys);
      expect(second.migrated, isEmpty);
      expect(second.cleanedUp, isEmpty);
      expect(primary.writes, writesAfterFirst);
      // Eltérő régi példány: érintetlen, de az új tároló értéke él.
      expect(legacy.values, {_tennis: 'régi-érték'});
      expect(await store.read(_tennis), 'új-érték');
    });

    test(
      'a plugin hibája (olvasás) → tartalék a Hitelesítőadat-kezelőre',
      () async {
        final legacy = _ScriptedStore(values: {_fd: 'fd-secret'});
        final store = LayeredSecretStore(
          primary: MemorySecretStore(failing: true),
          legacy: legacy,
        );

        final report = await store.migrateLegacy(_allKeys);
        expect(report.fellBack, isTrue);
        expect(store.usingFallback, isTrue);
        expect(store.primaryError, isA<SecretStoreException>());

        expect(await store.read(_fd), 'fd-secret');
        await store.write(_rapid, 'rapid-secret');
        expect(legacy.values[_rapid], 'rapid-secret');
        await store.delete(_fd);
        expect(legacy.values.containsKey(_fd), isFalse);
      },
    );
  });

  group('LayeredSecretStore műveletek', () {
    test(
      'írás után a régi, elavult példány törlődik; törlés mindkét helyről',
      () async {
        final primary = _ScriptedStore();
        final legacy = _ScriptedStore(values: {_fd: 'régi'});
        final store = LayeredSecretStore(primary: primary, legacy: legacy);

        await store.write(_fd, 'új');
        expect(primary.values[_fd], 'új');
        expect(legacy.values, isEmpty);

        legacy.values[_rapid] = 'régi-rapid';
        primary.values[_rapid] = 'új-rapid';
        await store.delete(_rapid);
        expect(primary.values.containsKey(_rapid), isFalse);
        expect(legacy.values.containsKey(_rapid), isFalse);
        expect(await store.read(_rapid), isNull);
      },
    );

    test('futás közbeni pluginhiba: az írás a tartalékon ismétlődik', () async {
      final primary = _ScriptedStore()..failWrite.add(_fd);
      final legacy = _ScriptedStore();
      final store = LayeredSecretStore(primary: primary, legacy: legacy);

      await store.write(_fd, 'fd-secret');
      expect(store.usingFallback, isTrue);
      expect(legacy.values[_fd], 'fd-secret');
      expect(await store.read(_fd), 'fd-secret');
    });
  });

  group('FlutterSecureSecretStore', () {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('PlatformException → SecretStoreException (titok nélkül)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'Exception occurred');
          });
      final store = FlutterSecureSecretStore();
      await expectLater(
        store.read(_fd),
        throwsA(
          isA<SecretStoreException>().having(
            (error) => error.cause,
            'cause',
            isA<PlatformException>(),
          ),
        ),
      );
      final error = await store
          .write(_fd, 'titkos-érték')
          .then<Object?>((_) => null, onError: (Object error) => error);
      expect(error, isA<SecretStoreException>());
      expect(error.toString(), isNot(contains('titkos-érték')));
    });

    test('MissingPluginException → a réteg a régi tárolóra vált', () async {
      // Nincs csatornakezelő: a hívás MissingPluginException-nel zárul.
      final legacy = _ScriptedStore(values: {_fd: 'fd-secret'});
      final store = LayeredSecretStore(
        primary: FlutterSecureSecretStore(),
        legacy: legacy,
      );
      final report = await store.migrateLegacy(_allKeys);
      expect(report.fellBack, isTrue);
      expect(store.primaryError, isA<SecretStoreException>());
      expect(
        (store.primaryError! as SecretStoreException).cause,
        isA<MissingPluginException>(),
      );
      expect(await store.read(_fd), 'fd-secret');
      expect(legacy.values, {_fd: 'fd-secret'});
    });

    test('olvasás, írás és törlés a csomagon át', () async {
      FlutterSecureStorage.setMockInitialValues({_fd: 'fd-secret'});
      final store = FlutterSecureSecretStore();
      expect(await store.read(_fd), 'fd-secret');
      await store.write(_rapid, 'rapid-secret');
      expect(await store.read(_rapid), 'rapid-secret');
      await store.delete(_fd);
      expect(await store.read(_fd), isNull);
    });
  });

  group('ApiKeyStore a rétegzett tárolóval', () {
    late Directory directory;
    late File file;
    late LocalStateStore stateStore;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('courtboard-layer-');
      file = File('${directory.path}/courtboard_state.json');
      stateStore = LocalStateStore(file: file);
    });
    tearDown(() => directory.delete(recursive: true));

    test(
      'JSON → közvetlenül az új tároló; a Hitelesítőadat-kezelő is átköltözik',
      () async {
        await file.writeAsString(
          jsonEncode({'theme': 'burgundy', 'footballDataKey': 'fd-json'}),
        );
        final state = await stateStore.load();
        final primary = _ScriptedStore();
        final legacy = _ScriptedStore(values: {_rapid: 'rapid-cred'});

        final result = await ApiKeyStore(
          secrets: LayeredSecretStore(primary: primary, legacy: legacy),
        ).load(state, stateStore: stateStore);

        expect(result.secureStorageAvailable, isTrue);
        expect(result.usingFallbackStore, isFalse);
        expect(result.migration?.migrated, [_rapid]);
        expect(result.keys, {
          ApiKeyId.footballData: 'fd-json',
          ApiKeyId.rapidApi: 'rapid-cred',
        });
        expect(primary.values, {_fd: 'fd-json', _rapid: 'rapid-cred'});
        expect(
          legacy.values,
          isEmpty,
          reason: 'a JSON-kulcs nem a régi tárolóba megy',
        );
        expect(result.state.legacyApiKeys, isEmpty);
        expect(await file.readAsString(), isNot(contains('fd-json')));
      },
    );

    test(
      'pluginhiba: a kulcsok a tartalékból jönnek, figyelmeztetés nélkül',
      () async {
        final legacy = _ScriptedStore(values: {_fd: 'fd-cred'});
        final keyStore = ApiKeyStore(
          secrets: LayeredSecretStore(
            primary: MemorySecretStore(failing: true),
            legacy: legacy,
          ),
        );
        final result = await keyStore.load(const CourtboardLocalState());

        expect(result.secureStorageAvailable, isTrue);
        expect(result.usingFallbackStore, isTrue);
        expect(keyStore.usingFallbackStore, isTrue);
        expect(result.keys, {ApiKeyId.footballData: 'fd-cred'});
        await keyStore.save(ApiKeyId.rapidApi, ' rapid ');
        expect(legacy.values[_rapid], 'rapid');
      },
    );

    test('mindkét tároló hibája: a régi figyelmeztetés marad', () async {
      final result = await ApiKeyStore(
        secrets: LayeredSecretStore(
          primary: MemorySecretStore(failing: true),
          legacy: MemorySecretStore(failing: true),
        ),
      ).load(const CourtboardLocalState());
      expect(result.secureStorageAvailable, isFalse);
      expect(result.keys, isEmpty);
    });
  });
}
