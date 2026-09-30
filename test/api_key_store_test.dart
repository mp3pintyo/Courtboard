import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Írást elfogadó, de semmit meg nem jegyző tároló (hibás visszaolvasás).
class _ForgetfulSecretStore extends MemorySecretStore {
  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  late Directory directory;
  late File file;
  late LocalStateStore stateStore;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('courtboard-keys-');
    file = File('${directory.path}/courtboard_state.json');
    stateStore = LocalStateStore(file: file);
  });
  tearDown(() => directory.delete(recursive: true));

  Future<CourtboardLocalState> writeLegacyState() async {
    await file.writeAsString(
      jsonEncode({
        'theme': 'burgundy',
        'footballDataKey': 'fd-secret',
        'rapidApiDartsKey': 'rapid-secret',
        'liveTennisKey': '',
      }),
    );
    return stateStore.load();
  }

  test(
    'legacy JSON keys move to the secret store and leave the JSON',
    () async {
      final secrets = MemorySecretStore();
      final state = await writeLegacyState();
      expect(state.legacyApiKeys, {
        ApiKeyId.footballData: 'fd-secret',
        ApiKeyId.rapidApi: 'rapid-secret',
      });

      final result = await ApiKeyStore(
        secrets: secrets,
      ).load(state, stateStore: stateStore);

      expect(result.secureStorageAvailable, isTrue);
      expect(result.keys, {
        ApiKeyId.footballData: 'fd-secret',
        ApiKeyId.rapidApi: 'rapid-secret',
      });
      expect(secrets.values, {
        ApiKeyId.footballData.secretName: 'fd-secret',
        ApiKeyId.rapidApi.secretName: 'rapid-secret',
      });
      expect(result.state.legacyApiKeys, isEmpty);
      expect(result.state.theme, 'burgundy');
      final saved = await file.readAsString();
      expect(saved, isNot(contains('fd-secret')));
      expect(saved, isNot(contains('rapid-secret')));
      expect(saved, isNot(contains('rapidApiDartsKey')));
      expect((await stateStore.load()).theme, 'burgundy');
    },
  );

  test('a failing secret store keeps the keys in JSON and in memory', () async {
    final state = await writeLegacyState();
    final before = await file.readAsString();

    final result = await ApiKeyStore(
      secrets: MemorySecretStore(failing: true),
    ).load(state, stateStore: stateStore);

    expect(result.secureStorageAvailable, isFalse);
    expect(result.keys[ApiKeyId.footballData], 'fd-secret');
    expect(result.keys[ApiKeyId.rapidApi], 'rapid-secret');
    expect(result.state.legacyApiKeys, state.legacyApiKeys);
    expect(await file.readAsString(), before);
    // A mentés is visszaírja a régi kulcsokat, így nem vesznek el.
    expect(result.state.toJson()['rapidApiDartsKey'], 'rapid-secret');
  });

  test('keys stay in JSON when the read-back does not match', () async {
    final state = await writeLegacyState();

    final result = await ApiKeyStore(
      secrets: _ForgetfulSecretStore(),
    ).load(state, stateStore: stateStore);

    expect(result.secureStorageAvailable, isFalse);
    expect(result.state.legacyApiKeys, state.legacyApiKeys);
    expect(result.keys[ApiKeyId.footballData], 'fd-secret');
    expect(await file.readAsString(), contains('fd-secret'));
  });

  test('stored keys load without migration; a newer JSON value wins', () async {
    final secrets = MemorySecretStore(
      values: {
        ApiKeyId.apiSports.secretName: 'as-stored',
        ApiKeyId.footballData.secretName: 'fd-old',
      },
    );
    final state = await writeLegacyState();

    final result = await ApiKeyStore(
      secrets: secrets,
    ).load(state, stateStore: stateStore);

    expect(result.keys[ApiKeyId.apiSports], 'as-stored');
    expect(result.keys[ApiKeyId.footballData], 'fd-secret');
    expect(secrets.values[ApiKeyId.footballData.secretName], 'fd-secret');
    expect(result.state.legacyApiKeys, isEmpty);
  });

  test('saving an empty key deletes it from the secret store', () async {
    final secrets = MemorySecretStore();
    final store = ApiKeyStore(secrets: secrets);

    await store.save(ApiKeyId.liveTennis, '  lt-secret ');
    expect(secrets.values[ApiKeyId.liveTennis.secretName], 'lt-secret');
    await store.save(ApiKeyId.liveTennis, '');
    expect(secrets.values, isEmpty);

    secrets.failing = true;
    expect(
      store.save(ApiKeyId.liveTennis, 'x'),
      throwsA(isA<SecretStoreException>()),
    );
  });

  test('RapidAPI key reads RAPIDAPI_KEY first, then the old variable', () {
    expect(
      SportsApiConfig.fromEnvironment({
        'RAPIDAPI_DARTS_KEY': 'old',
      }).rapidApiKey,
      'old',
    );
    expect(
      SportsApiConfig.fromEnvironment({
        'RAPIDAPI_KEY': 'new',
        'RAPIDAPI_DARTS_KEY': 'old',
      }).rapidApiKey,
      'new',
    );
  });

  test('withKey and withKeys update only the requested keys', () {
    const base = SportsApiConfig(apiSportsKey: 'env', youtubeKey: 'yt');
    final updated = base.withKey(ApiKeyId.liveTennis, ' lt ').withKeys({
      ApiKeyId.apiSports: '',
      ApiKeyId.rapidApi: 'rapid',
    });

    expect(updated.liveTennisKey, 'lt');
    expect(updated.apiSportsKey, 'env');
    expect(updated.rapidApiKey, 'rapid');
    expect(updated.youtubeKey, 'yt');
    for (final id in ApiKeyId.values) {
      expect(base.withKey(id, 'v').key(id), 'v');
    }
  });
}
