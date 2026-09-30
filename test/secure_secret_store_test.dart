import 'dart:io';

import 'package:courtboard/data/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valódi Windows Hitelesítőadat-kezelőt érintő ellenőrzés. Alapból kimarad,
/// mert a tesztek nem írnak a felhasználó rendszerébe; futtatás:
/// `$env:COURTBOARD_CREDENTIAL_TEST='1'; flutter test test/secure_secret_store_test.dart`
void main() {
  final enabled =
      Platform.isWindows &&
      Platform.environment['COURTBOARD_CREDENTIAL_TEST'] == '1';
  final prefix = 'CourtboardTest/${DateTime.now().microsecondsSinceEpoch}/';
  final store = SecureSecretStore(targetPrefix: prefix);

  tearDown(() async {
    if (enabled) await store.delete('roundtrip');
  });

  test(
    'Credential Manager round trip: write, read, overwrite, delete',
    () async {
      expect(await store.read('roundtrip'), isNull);

      await store.write('roundtrip', 'első-érték 🔑');
      expect(await store.read('roundtrip'), 'első-érték 🔑');

      await store.write('roundtrip', 'második');
      expect(await store.read('roundtrip'), 'második');

      await store.delete('roundtrip');
      expect(await store.read('roundtrip'), isNull);
      // Nem létező kulcs törlése nem hiba.
      await store.delete('roundtrip');
    },
    skip: enabled ? false : 'COURTBOARD_CREDENTIAL_TEST=1 nélkül kimarad',
  );

  test(
    'oversized values are rejected without touching the store',
    () async {
      await expectLater(
        store.write('roundtrip', 'x' * (SecureSecretStore.maxValueBytes + 1)),
        throwsA(isA<SecretStoreException>()),
      );
    },
    skip: enabled ? false : 'COURTBOARD_CREDENTIAL_TEST=1 nélkül kimarad',
  );
}
