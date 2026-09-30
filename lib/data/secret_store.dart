import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Titkok (API-kulcsok) kulcs–érték tárolója.
///
/// Minden művelet [SecretStoreException]-t dob, ha a mögöttes tároló nem
/// érhető el; a hívó ilyenkor memóriában tartott kulcsokkal dolgozik tovább.
abstract interface class SecretStore {
  /// Az alkalmazás közös titoktárolója. Alapértelmezése a Windows
  /// Hitelesítőadat-kezelője ([SecureSecretStore]); a tesztek
  /// [MemorySecretStore]-ra cserélik (lásd `test/flutter_test_config.dart`).
  static SecretStore shared = SecureSecretStore();

  /// A [key] alatt tárolt érték, vagy `null`, ha nincs ilyen.
  Future<String?> read(String key);

  /// A [value] mentése a [key] alá (felülírja a korábbi értéket).
  Future<void> write(String key, String value);

  /// A [key] törlése; nem létező kulcsnál nem hiba.
  Future<void> delete(String key);
}

/// A titoktároló elérhetetlenségét jelző kivétel. Az üzenet soha nem
/// tartalmaz titkot, csak a művelet és a kulcs nevét.
class SecretStoreException implements Exception {
  const SecretStoreException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SecretStoreException: $message';
}

/// A Windows Hitelesítőadat-kezelőre (Credential Manager) épülő tároló.
///
/// Minden kulcs egy általános (generic) hitelesítő adat `Courtboard/<kulcs>`
/// célnévvel, a felhasználó profiljához kötve: a Windows a DPAPI-val
/// titkosítva tárolja, és más felhasználó nem olvashatja. Natív
/// fordítást nem igényel (közvetlen `advapi32` hívás a `win32` csomagon át).
class SecureSecretStore implements SecretStore {
  SecureSecretStore({this.targetPrefix = 'Courtboard/'});

  /// A hitelesítő adatok célnév-előtagja (a Hitelesítőadat-kezelőben így
  /// látszanak).
  final String targetPrefix;

  /// A Windows általános hitelesítő adatának legnagyobb mérete (5 × 512 bájt).
  static const maxValueBytes = 2560;

  static const _userName = 'Courtboard';

  String _target(String key) => '$targetPrefix$key';

  Future<T> _guard<T>(String operation, String key, T Function() run) async {
    if (!Platform.isWindows) {
      throw SecretStoreException('$operation: csak Windows alatt érhető el.');
    }
    try {
      return run();
    } on SecretStoreException {
      rethrow;
    } catch (error) {
      throw SecretStoreException('$operation sikertelen: $key', error);
    }
  }

  @override
  Future<String?> read(String key) => _guard(
    'Olvasás',
    key,
    () => using((arena) {
      final credential = arena<Pointer<CREDENTIAL>>();
      final result = CredRead(
        _target(key).toPcwstr(allocator: arena),
        CRED_TYPE_GENERIC,
        credential,
      );
      if (!result.value) {
        if (result.error == ERROR_NOT_FOUND) return null;
        throw SecretStoreException(
          'Olvasás sikertelen: $key (Win32 ${result.error})',
        );
      }
      try {
        final ref = credential.value.ref;
        final bytes = ref.CredentialBlob.asTypedList(ref.CredentialBlobSize);
        return utf8.decode(bytes);
      } finally {
        CredFree(credential.value);
      }
    }),
  );

  @override
  Future<void> write(String key, String value) => _guard('Írás', key, () {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty || bytes.length > maxValueBytes) {
      throw SecretStoreException(
        'Írás sikertelen: $key (érvénytelen hossz: ${bytes.length} bájt)',
      );
    }
    using((arena) {
      final blob = arena<Uint8>(bytes.length);
      blob.asTypedList(bytes.length).setAll(0, bytes);
      final credential = arena<CREDENTIAL>();
      credential.ref
        ..Type = CRED_TYPE_GENERIC
        ..TargetName = PWSTR(_target(key).toPcwstr(allocator: arena))
        ..UserName = PWSTR(_userName.toPcwstr(allocator: arena))
        ..CredentialBlobSize = bytes.length
        ..CredentialBlob = blob
        ..Persist = CRED_PERSIST_LOCAL_MACHINE;
      final result = CredWrite(credential, 0);
      if (!result.value) {
        throw SecretStoreException(
          'Írás sikertelen: $key (Win32 ${result.error})',
        );
      }
    });
  });

  @override
  Future<void> delete(String key) => _guard('Törlés', key, () {
    using((arena) {
      final result = CredDelete(
        _target(key).toPcwstr(allocator: arena),
        CRED_TYPE_GENERIC,
      );
      if (!result.value && result.error != ERROR_NOT_FOUND) {
        throw SecretStoreException(
          'Törlés sikertelen: $key (Win32 ${result.error})',
        );
      }
    });
  });
}

/// Memóriában élő tároló tesztekhez. A [failing] kapcsolóval a platform
/// hibája szimulálható: ilyenkor minden művelet [SecretStoreException]-t dob.
class MemorySecretStore implements SecretStore {
  MemorySecretStore({Map<String, String>? values, this.failing = false})
    : values = {...?values};

  /// A tárolt értékek (tesztből közvetlenül is vizsgálható).
  final Map<String, String> values;

  bool failing;

  void _check(String operation, String key) {
    if (failing) throw SecretStoreException('$operation sikertelen: $key');
  }

  @override
  Future<String?> read(String key) async {
    _check('Olvasás', key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check('Írás', key);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check('Törlés', key);
    values.remove(key);
  }
}
