import 'dart:convert';
import 'dart:io';

import 'api_key_id.dart';
import 'app_paths.dart';
import 'file_util.dart';
import 'json_util.dart';
import 'notification_settings.dart';
import 'window_geometry.dart';

class CustomAthlete {
  const CustomAthlete({
    required this.name,
    required this.sport,
    required this.team,
    this.country = '',
    this.photoUrl = '',
  });

  final String name;
  final String sport;
  final String team;
  final String country;
  final String photoUrl;

  Map<String, dynamic> toJson() => {
    'name': name,
    'sport': sport,
    'team': team,
    'country': country,
    'photoUrl': photoUrl,
  };

  factory CustomAthlete.fromJson(Map<String, dynamic> json) => CustomAthlete(
    name: json['name'] as String? ?? '',
    sport: json['sport'] as String? ?? '',
    team: json['team'] as String? ?? '',
    country: json['country'] as String? ?? '',
    photoUrl: json['photoUrl'] as String? ?? '',
  );
}

class CourtboardLocalState {
  const CourtboardLocalState({
    this.notes = const {},
    this.alerts = const {},
    this.removedAthleteNames = const {},
    this.legacyApiKeys = const {},
    this.customAthletes = const [],
    this.theme = 'green',
    this.themeMode = 'system',
    this.overviewSort = 'custom',
    this.athleteSort = 'custom',
    this.athleteOrder = const [],
    this.railCollapsed = false,
    this.autoUpdateCheck = true,
    this.windowGeometry,
    this.closeToTray = false,
    this.closeToTrayHintShown = false,
    this.startMinimized = false,
    this.notifications = const NotificationSettings(),
    this.notificationsPausedUntil,
  });

  final Map<String, String> notes;
  final Map<String, bool> alerts;
  final Set<String> removedAthleteNames;

  /// A 0.9.0 előtt titkosítatlanul mentett API-kulcsok (csak a nem üresek).
  ///
  /// Indításkor átkerülnek a biztonságos tárolóba, és sikeres visszaolvasás
  /// után kikerülnek a JSON-ból. Csak akkor maradnak itt, ha a biztonságos
  /// tároló nem érhető el: így a kulcsok akkor sem vesznek el.
  final Map<ApiKeyId, String> legacyApiKeys;
  final List<CustomAthlete> customAthletes;
  final String theme;

  /// Megjelenési mód: `system` (alapértelmezett), `light` vagy `dark`.
  /// A 0.10.0 előtti állapotfájlokból hiányzik; ilyenkor `system`.
  final String themeMode;
  final String overviewSort;
  final String athleteSort;

  /// A „Saját sorrend” szerinti névsor; üres lista esetén az alapsorrend él.
  final List<String> athleteOrder;

  /// Igaz, ha a felhasználó széles ablakban is összecsukta az oldalsávot.
  final bool railCollapsed;

  /// Automatikus frissítés-ellenőrzés indításkor (alapból bekapcsolva; a
  /// 0.11.0 előtti állapotfájlokból hiányzik).
  final bool autoUpdateCheck;

  /// Az ablak legutóbbi helyzete és mérete (0.11.0-tól); `null`, ha még
  /// nincs mentés (ilyenkor a futtató középre igazított alapablaka él).
  final WindowGeometry? windowGeometry;

  /// Bezáráskor a tálcára kicsinyítés (alapból kikapcsolva).
  final bool closeToTray;

  /// Igaz, ha az első tálcára rejtéskor megjelent tipp már látszott.
  final bool closeToTrayHintShown;

  /// Windows-indításkor a tálcára minimalizálva induljon (a Windows-zal
  /// indítás maga a rendszerleíró adatbázisban él, lásd `StartupRegistration`).
  final bool startMinimized;

  /// Értesítési beállítások (típusok, gyakoriság, csendes órák).
  final NotificationSettings notifications;

  /// Az értesítések szüneteltetése eddig az időpontig (a tálcamenü
  /// „Értesítések szüneteltetése 1 órára” pontja); `null`: nincs szünet.
  final DateTime? notificationsPausedUntil;

  /// Másolat, amelyben a régi, titkosítatlan kulcsok helyén [keys] áll.
  CourtboardLocalState withLegacyApiKeys(Map<ApiKeyId, String> keys) =>
      CourtboardLocalState(
        notes: notes,
        alerts: alerts,
        removedAthleteNames: removedAthleteNames,
        legacyApiKeys: keys,
        customAthletes: customAthletes,
        theme: theme,
        themeMode: themeMode,
        overviewSort: overviewSort,
        athleteSort: athleteSort,
        athleteOrder: athleteOrder,
        railCollapsed: railCollapsed,
        autoUpdateCheck: autoUpdateCheck,
        windowGeometry: windowGeometry,
        closeToTray: closeToTray,
        closeToTrayHintShown: closeToTrayHintShown,
        startMinimized: startMinimized,
        notifications: notifications,
        notificationsPausedUntil: notificationsPausedUntil,
      );

  /// Másolat új ablakhelyzettel (a többi mező változatlan).
  CourtboardLocalState withWindowGeometry(WindowGeometry? geometry) =>
      CourtboardLocalState(
        notes: notes,
        alerts: alerts,
        removedAthleteNames: removedAthleteNames,
        legacyApiKeys: legacyApiKeys,
        customAthletes: customAthletes,
        theme: theme,
        themeMode: themeMode,
        overviewSort: overviewSort,
        athleteSort: athleteSort,
        athleteOrder: athleteOrder,
        railCollapsed: railCollapsed,
        autoUpdateCheck: autoUpdateCheck,
        windowGeometry: geometry,
        closeToTray: closeToTray,
        closeToTrayHintShown: closeToTrayHintShown,
        startMinimized: startMinimized,
        notifications: notifications,
        notificationsPausedUntil: notificationsPausedUntil,
      );

  Map<String, dynamic> toJson() => {
    'notes': notes,
    'alerts': alerts,
    'removedAthleteNames': removedAthleteNames.toList(),
    for (final MapEntry(key: id, :value) in legacyApiKeys.entries)
      if (value.isNotEmpty) id.legacyJsonField: value,
    'customAthletes': customAthletes
        .map((athlete) => athlete.toJson())
        .toList(),
    'theme': theme,
    'themeMode': themeMode,
    'overviewSort': overviewSort,
    'athleteSort': athleteSort,
    'athleteOrder': athleteOrder,
    'railCollapsed': railCollapsed,
    'autoUpdateCheck': autoUpdateCheck,
    if (windowGeometry != null) 'window': windowGeometry!.toJson(),
    'closeToTray': closeToTray,
    'closeToTrayHintShown': closeToTrayHintShown,
    'startMinimized': startMinimized,
    'notifications': notifications.toJson(),
    if (notificationsPausedUntil != null)
      'notificationsPausedUntil': notificationsPausedUntil!
          .toUtc()
          .toIso8601String(),
  };

  factory CourtboardLocalState.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    final rawAlerts = json['alerts'];
    final rawRemoved = json['removedAthleteNames'];
    final rawAthletes = json['customAthletes'];
    final rawOrder = json['athleteOrder'];
    return CourtboardLocalState(
      notes: rawNotes is Map
          ? rawNotes.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      alerts: rawAlerts is Map
          ? rawAlerts.map((key, value) => MapEntry('$key', value == true))
          : const {},
      removedAthleteNames: rawRemoved is List
          ? rawRemoved.whereType<String>().toSet()
          : const {},
      legacyApiKeys: {
        for (final id in ApiKeyId.values)
          if (json[id.legacyJsonField] case final String key
              when key.trim().isNotEmpty)
            id: key.trim(),
      },
      customAthletes: rawAthletes is List
          ? jsonMapList(rawAthletes).map(CustomAthlete.fromJson).toList()
          : const [],
      theme: json['theme'] as String? ?? 'green',
      themeMode: switch (json['themeMode']) {
        final String mode
            when const {'system', 'light', 'dark'}.contains(mode) =>
          mode,
        _ => 'system',
      },
      overviewSort: json['overviewSort'] as String? ?? 'custom',
      athleteSort: json['athleteSort'] as String? ?? 'custom',
      athleteOrder: rawOrder is List
          ? rawOrder.whereType<String>().toList()
          : const [],
      railCollapsed: json['railCollapsed'] == true,
      autoUpdateCheck: json['autoUpdateCheck'] != false,
      windowGeometry: WindowGeometry.fromJson(json['window']),
      closeToTray: json['closeToTray'] == true,
      closeToTrayHintShown: json['closeToTrayHintShown'] == true,
      startMinimized: json['startMinimized'] == true,
      notifications: NotificationSettings.fromJson(json['notifications']),
      notificationsPausedUntil: switch (json['notificationsPausedUntil']) {
        final String value => DateTime.tryParse(value)?.toLocal(),
        _ => null,
      },
    );
  }
}

class LocalStateStore {
  LocalStateStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  /// Az egymás utáni mentések láncolata: egyszerre mindig csak egy írás fut,
  /// és a sorrend megegyezik a hívások sorrendjével (az utolsó állapot nyer).
  Future<void> _saveChain = Future<void>.value();

  static File _defaultFile() => File(AppPaths.stateFile);

  /// Az utolsó [load] során félretett sérült állapotfájl, ha volt ilyen.
  File? lastCorruptBackup;

  Future<CourtboardLocalState> load() async {
    // Egy folyamatban lévő mentést megvárunk, hogy ne félkész fájlt olvassunk.
    await _saveChain;
    final String raw;
    try {
      if (!await _file.exists()) return const CourtboardLocalState();
      raw = await _file.readAsString();
    } on FileSystemException {
      return const CourtboardLocalState();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CourtboardLocalState.fromJson(decoded);
      }
    } catch (_) {
      // Lent félretesszük a sérült fájlt.
    }
    await _preserveCorruptFile();
    return const CourtboardLocalState();
  }

  /// A sérült állapotfájlt `courtboard_state.corrupt-<időbélyeg>.json` néven
  /// lemásolja, hogy a következő mentés ne írja felül visszaállíthatatlanul.
  Future<void> _preserveCorruptFile() async {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 17);
    final name = _file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '.json';
    final backup = File('${_file.parent.path}/$base.corrupt-$stamp$extension');
    try {
      lastCorruptBackup = await _file.copy(backup.path);
    } on FileSystemException {
      lastCorruptBackup = null;
    }
  }

  /// Atomikus mentés (ideiglenes fájl + átnevezés). Az egyidejű hívások
  /// sorban futnak le; egy korábbi mentés hibája nem akasztja meg a későbbieket.
  Future<void> save(CourtboardLocalState state) {
    final contents = jsonEncode(state.toJson());
    final next = _saveChain
        .catchError((Object _) {})
        .then((_) => writeFileAtomic(_file, contents));
    _saveChain = next.catchError((Object _) {});
    return next;
  }
}
