/// Az API-kulcsok elsődleges tárolója (`flutter_secure_storage`) és a
/// Windows Hitelesítőadat-kezelőre épülő régi tárolóval közös, átköltöztető
/// és tartalékra váltó réteg.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:courtboard/data/secret_store.dart';

/// A `flutter_secure_storage` csomagra épülő tároló (0.15.0-tól az
/// alapértelmezés).
///
/// Windows alatt a csomag (`flutter_secure_storage_windows`) az összes
/// kulcsot egyetlen, DPAPI-val (a felhasználói fiókhoz kötve) titkosított
/// JSON-fájlban tartja: `%APPDATA%\<CompanyName>\<ProductName>\
/// flutter_secure_storage.dat`, a Courtboardnál
/// `%APPDATA%\Mp3Pintyo\Courtboard\flutter_secure_storage.dat` (a mappanevet
/// az exe verzióadatai adják, lásd `windows/runner/Runner.rc`). A csomag
/// „visszafelé kompatibilis” módját (a régi, natív Credential Manager-alapú
/// tárolás olvasását) kikapcsoljuk: a Courtboard saját régi tárolóját a
/// [LayeredSecretStore] költözteti át.
///
/// A csomag minden hibáját (hiányzó plugin, `PlatformException`, DPAPI- vagy
/// fájlhiba) [SecretStoreException]-né alakítja; a titok soha nem kerül az
/// üzenetbe.
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(wOptions: windowsOptions);

  /// A Windows-beállítás: régi natív tároló nélkül (lásd az osztály leírását).
  static const windowsOptions = WindowsOptions();

  final FlutterSecureStorage _storage;

  Future<T> _guard<T>(
    String operation,
    String key,
    Future<T> Function() run,
  ) async {
    try {
      return await run();
    } on SecretStoreException {
      rethrow;
    } catch (error) {
      // MissingPluginException, PlatformException, WindowsException,
      // FileSystemException, FormatException (sérült fájl) …
      throw SecretStoreException(
        '$operation sikertelen: $key (${error.runtimeType})',
        error,
      );
    }
  }

  @override
  Future<String?> read(String key) =>
      _guard('Olvasás', key, () => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard('Írás', key, () => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) =>
      _guard('Törlés', key, () => _storage.delete(key: key));
}

/// Az indításkori átköltöztetés eredménye (a naplózáshoz és a tesztekhez).
class SecretMigrationReport {
  const SecretMigrationReport({
    this.migrated = const [],
    this.keptInLegacy = const [],
    this.cleanedUp = const [],
    this.legacyDeleteFailed = const [],
    this.fellBack = false,
  });

  /// Átköltözött kulcsok: az új tárolóban ellenőrizve megvannak, a régi
  /// hitelesítő adat törölve.
  final List<String> migrated;

  /// A régi tárolóban maradt kulcsok (eltérő visszaolvasás miatt).
  final List<String> keptInLegacy;

  /// Egy korábbi, félbemaradt költözés maradéka: a régi példány az újjal
  /// egyezett, ezért most törlődött.
  final List<String> cleanedUp;

  /// Ellenőrzötten átkerült, de a régi példány törlése nem sikerült (a
  /// következő indítás újra megpróbálja).
  final List<String> legacyDeleteFailed;

  /// Igaz, ha az új tároló hibázott, és a réteg a régire váltott.
  final bool fellBack;

  @override
  String toString() =>
      'SecretMigrationReport(migrated: $migrated, kept: $keptInLegacy, '
      'cleaned: $cleanedUp, deleteFailed: $legacyDeleteFailed, '
      'fellBack: $fellBack)';
}

/// Titoktároló, amelynek régi (korábbi verziók által használt) tárolója is
/// van, és indításkor átköltöztethető.
abstract interface class MigratingSecretStore implements SecretStore {
  /// A [keys] kulcsok átköltöztetése a régi tárolóból. Soha nem dob.
  Future<SecretMigrationReport> migrateLegacy(Iterable<String> keys);

  /// Igaz, ha az elsődleges tároló hibája miatt a régi tároló él.
  bool get usingFallback;

  /// A ténylegesen használt tároló rövid, felhasználónak szóló neve.
  String get description;
}

/// Az elsődleges ([primary], alapból [FlutterSecureSecretStore]) és a régi
/// ([legacy], alapból a Hitelesítőadat-kezelős [SecureSecretStore]) tároló
/// közös rétege.
///
/// - **Átköltöztetés** ([migrateLegacy], indításkor): kulcsonként, ha az új
///   tárolóban nincs érték, de a régiben van → írás az újba →
///   visszaolvasás és összevetés → a régi hitelesítő adat törlése csak akkor,
///   ha minden átírás ellenőrzötten sikerült. Eltérő visszaolvasásnál a régi
///   érték marad (az új tárolóba írt hibás példány törlődik). Ha az új
///   tárolóban már van érték, az nyer; ha a régi ugyanaz, a régi (egy
///   félbemaradt költözés maradéka) törlődik. Így kétszeres költözés nincs.
/// - **Tartalék:** ha az elsődleges tároló bármely művelete hibázik (például
///   `MissingPluginException` / `PlatformException`), a réteg az app
///   bezárásáig a régi tárolóra vált, és a műveletet ott ismétli meg.
/// - **Olvasás:** az új tárolóban hiányzó kulcsot a régiből olvassa (így egy
///   még át nem költözött kulcs sem vész el); **törlés:** mindkét helyről.
class LayeredSecretStore implements MigratingSecretStore {
  LayeredSecretStore({required this.primary, required this.legacy});

  /// Az éles tároló: `flutter_secure_storage`, tartalékként és
  /// költöztetési forrásként a Hitelesítőadat-kezelő.
  factory LayeredSecretStore.production() => LayeredSecretStore(
    primary: FlutterSecureSecretStore(),
    legacy: SecureSecretStore(),
  );

  final SecretStore primary;
  final SecretStore legacy;

  bool _primaryFailed = false;

  /// Az elsődleges tároló hibája (a tartalékra váltás oka), ha volt.
  Object? get primaryError => _primaryError;
  Object? _primaryError;

  @override
  bool get usingFallback => _primaryFailed;

  @override
  String get description => _primaryFailed
      ? 'Windows Hitelesítőadat-kezelő (tartalék)'
      : 'Titkosított kulcsfájl (flutter_secure_storage, DPAPI)';

  void _fail(Object error) {
    _primaryFailed = true;
    _primaryError = error;
  }

  @override
  Future<String?> read(String key) async {
    if (_primaryFailed) return legacy.read(key);
    final String? value;
    try {
      value = await primary.read(key);
    } on SecretStoreException catch (error) {
      _fail(error);
      return legacy.read(key);
    }
    if (value != null && value.isNotEmpty) return value;
    // Még át nem költözött (például eltérő visszaolvasás miatt a régi
    // tárolóban hagyott) kulcs.
    try {
      return await legacy.read(key);
    } on Object {
      return value;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (_primaryFailed) return legacy.write(key, value);
    try {
      await primary.write(key, value);
    } on SecretStoreException catch (error) {
      _fail(error);
      return legacy.write(key, value);
    }
    // Az új érték ellenőrzötten az új tárolóban van: a régi példány (ha
    // volt) elavult, törölhető.
    try {
      if (await primary.read(key) == value) await legacy.delete(key);
    } on Object {
      // A régi példányt az új tároló értéke amúgy is elfedi.
    }
  }

  @override
  Future<void> delete(String key) async {
    if (!_primaryFailed) {
      try {
        await primary.delete(key);
      } on SecretStoreException catch (error) {
        _fail(error);
      }
    }
    if (_primaryFailed) return legacy.delete(key);
    // A régi példány se bukkanjon fel újra olvasáskor; ha a régi tároló nem
    // érhető el, abban amúgy sincs mit törölni.
    try {
      await legacy.delete(key);
    } on Object {
      // Lásd fent.
    }
  }

  @override
  Future<SecretMigrationReport> migrateLegacy(Iterable<String> keys) async {
    if (_primaryFailed) return const SecretMigrationReport(fellBack: true);
    final toMigrate = <String, String>{};
    final cleanup = <String>[];
    // 1. Felmérés: mi van a két tárolóban.
    for (final key in keys) {
      final String? current;
      try {
        current = await primary.read(key);
      } on SecretStoreException catch (error) {
        _fail(error);
        return const SecretMigrationReport(fellBack: true);
      }
      final String? old;
      try {
        old = await legacy.read(key);
      } on Object {
        // A régi tároló nem olvasható: nincs mit átvinni.
        continue;
      }
      if (old == null || old.isEmpty) continue;
      if (current == null || current.isEmpty) {
        toMigrate[key] = old;
      } else if (current == old) {
        cleanup.add(key);
      }
      // Eltérő érték: az új tárolóé nyer, a régi érintetlen marad.
    }

    // 2. Írás és visszaolvasás; a régi tárolóból még semmi nem törlődik,
    // így az új tároló hibájánál a tartalék minden kulcsot megtart.
    final verified = <String>[];
    final kept = <String>[];
    for (final MapEntry(:key, :value) in toMigrate.entries) {
      try {
        await primary.write(key, value);
        final readBack = await primary.read(key);
        if (readBack == value) {
          verified.add(key);
          continue;
        }
      } on SecretStoreException catch (error) {
        _fail(error);
        return SecretMigrationReport(
          keptInLegacy: toMigrate.keys.toList(),
          fellBack: true,
        );
      }
      kept.add(key);
      // A hibás példány ne fedje el a régi értéket.
      try {
        await primary.delete(key);
      } on SecretStoreException catch (error) {
        // A hibás példány olvasáskor elfedné a régit: ebben a futásban a
        // régi tároló él, és abból semmi nem törlődik.
        _fail(error);
        return SecretMigrationReport(
          keptInLegacy: toMigrate.keys.toList(),
          fellBack: true,
        );
      }
    }

    // 3. A régi hitelesítő adatok törlése csak ellenőrzött átírás után.
    final migrated = <String>[];
    final cleanedUp = <String>[];
    final deleteFailed = <String>[];
    for (final key in [...verified, ...cleanup]) {
      try {
        await legacy.delete(key);
        (verified.contains(key) ? migrated : cleanedUp).add(key);
      } on Object {
        deleteFailed.add(key);
      }
    }
    return SecretMigrationReport(
      migrated: migrated,
      keptInLegacy: kept,
      cleanedUp: cleanedUp,
      legacyDeleteFailed: deleteFailed,
    );
  }
}
