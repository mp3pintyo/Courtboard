import 'dart:convert';
import 'dart:io';

import 'file_util.dart';

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
    this.footballDataKey = '',
    this.apiSportsKey = '',
    this.balldontlieKey = '',
    this.rapidApiDartsKey = '',
    this.liveTennisKey = '',
    this.customAthletes = const [],
    this.theme = 'green',
    this.overviewSort = 'custom',
    this.athleteSort = 'custom',
    this.athleteOrder = const [],
  });

  final Map<String, String> notes;
  final Map<String, bool> alerts;
  final Set<String> removedAthleteNames;
  final String footballDataKey;
  final String apiSportsKey;
  final String balldontlieKey;
  final String rapidApiDartsKey;
  final String liveTennisKey;
  final List<CustomAthlete> customAthletes;
  final String theme;
  final String overviewSort;
  final String athleteSort;

  /// A „Saját sorrend” szerinti névsor; üres lista esetén az alapsorrend él.
  final List<String> athleteOrder;

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'alerts': alerts,
        'removedAthleteNames': removedAthleteNames.toList(),
        'footballDataKey': footballDataKey,
        'apiSportsKey': apiSportsKey,
        'balldontlieKey': balldontlieKey,
        'rapidApiDartsKey': rapidApiDartsKey,
        'liveTennisKey': liveTennisKey,
        'customAthletes':
            customAthletes.map((athlete) => athlete.toJson()).toList(),
        'theme': theme,
        'overviewSort': overviewSort,
        'athleteSort': athleteSort,
        'athleteOrder': athleteOrder,
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
      footballDataKey: json['footballDataKey'] as String? ?? '',
      apiSportsKey: json['apiSportsKey'] as String? ?? '',
      balldontlieKey: json['balldontlieKey'] as String? ?? '',
      rapidApiDartsKey: json['rapidApiDartsKey'] as String? ?? '',
      liveTennisKey: json['liveTennisKey'] as String? ?? '',
      customAthletes: rawAthletes is List
          ? rawAthletes
              .whereType<Map>()
              .map((item) =>
                  CustomAthlete.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      theme: json['theme'] as String? ?? 'green',
      overviewSort: json['overviewSort'] as String? ?? 'custom',
      athleteSort: json['athleteSort'] as String? ?? 'custom',
      athleteOrder: rawOrder is List
          ? rawOrder.whereType<String>().toList()
          : const [],
    );
  }
}

class LocalStateStore {
  LocalStateStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  /// Az egymás utáni mentések láncolata: egyszerre mindig csak egy írás fut,
  /// és a sorrend megegyezik a hívások sorrendjével (az utolsó állapot nyer).
  Future<void> _saveChain = Future<void>.value();

  static File _defaultFile() => File('${appDataPath()}/courtboard_state.json');

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
