import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/secret_store.dart';

/// Az indításkori kulcsbetöltés eredménye.
class ApiKeyLoadResult {
  const ApiKeyLoadResult({
    required this.keys,
    required this.state,
    required this.secureStorageAvailable,
  });

  /// A mentett (nem üres) kulcsok; a környezeti változókat felülírják.
  final Map<ApiKeyId, String> keys;

  /// A helyi állapot a migráció után: a sikeresen átköltöztetett kulcsok
  /// már nem szerepelnek benne.
  final CourtboardLocalState state;

  /// Hamis, ha a biztonságos tároló nem volt olvasható vagy írható: ilyenkor
  /// a kulcsok memóriában élnek, a régi JSON-kulcsok pedig érintetlenek.
  final bool secureStorageAvailable;
}

/// Az API-kulcsok betöltése, mentése és egyszeri migrációja a titkosítatlan
/// állapotfájlból a [SecretStore]-ba.
class ApiKeyStore {
  /// A [secrets] alapértelmezése a közös [SecretStore.shared].
  ApiKeyStore({this._secrets});

  final SecretStore? _secrets;

  SecretStore get _store => _secrets ?? SecretStore.shared;

  /// Betölti a kulcsokat, és a [state]-ben talált régi kulcsokat átköltözteti.
  ///
  /// Migráció kulcsonként: írás a titoktárolóba → visszaolvasás → egyezés
  /// esetén a kulcs kikerül a JSON-ból (a [stateStore] atomikus mentésével).
  /// Eltérő érték esetén a JSON-beli nyer, mert azt csak egy régebbi
  /// verzió írhatta a legutóbbi migráció után. Bármely tárolóhiba esetén a
  /// JSON-kulcsok megmaradnak, és a memóriában is azok élnek.
  Future<ApiKeyLoadResult> load(
    CourtboardLocalState state, {
    LocalStateStore? stateStore,
  }) async {
    final legacy = state.legacyApiKeys;
    final keys = <ApiKeyId, String>{};
    try {
      for (final id in ApiKeyId.values) {
        final value = (await _store.read(id.secretName))?.trim() ?? '';
        if (value.isNotEmpty) keys[id] = value;
      }
    } on Object {
      return ApiKeyLoadResult(
        keys: {...legacy},
        state: state,
        secureStorageAvailable: false,
      );
    }
    if (legacy.isEmpty) {
      return ApiKeyLoadResult(
        keys: keys,
        state: state,
        secureStorageAvailable: true,
      );
    }

    final remaining = <ApiKeyId, String>{};
    var available = true;
    for (final MapEntry(key: id, :value) in legacy.entries) {
      if (available && await _migrate(id, value, alreadyStored: keys[id])) {
        keys[id] = value;
      } else {
        available = false;
        remaining[id] = value;
        // A tároló hibája esetén a JSON-beli (legfrissebb) érték él.
        keys[id] = value;
      }
    }

    var result = state;
    if (remaining.length != legacy.length) {
      result = state.withLegacyApiKeys(remaining);
      try {
        await stateStore?.save(result);
      } catch (_) {
        // A kulcsok mindkét helyen megvannak; a következő indítás újra
        // megpróbálja kivenni őket a JSON-ból.
        result = state;
      }
    }
    return ApiKeyLoadResult(
      keys: keys,
      state: result,
      secureStorageAvailable: available,
    );
  }

  /// Igaz, ha a [value] biztosan a titoktárolóban van (írás és
  /// visszaolvasás után), így a JSON-ból törölhető.
  Future<bool> _migrate(
    ApiKeyId id,
    String value, {
    String? alreadyStored,
  }) async {
    if (alreadyStored == value) return true;
    try {
      await _store.write(id.secretName, value);
      return await _store.read(id.secretName) == value;
    } on Object {
      return false;
    }
  }

  /// Az [id] kulcsának mentése; üres [value] törli a tárolt kulcsot.
  /// Hiba esetén [SecretStoreException]-t dob.
  Future<void> save(ApiKeyId id, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _store.delete(id.secretName);
    } else {
      await _store.write(id.secretName, trimmed);
    }
  }
}
