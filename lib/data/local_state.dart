import 'dart:convert';
import 'dart:io';

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
    this.customAthletes = const [],
    this.theme = 'green',
    this.overviewSort = 'custom',
    this.athleteSort = 'custom',
  });

  final Map<String, String> notes;
  final Map<String, bool> alerts;
  final Set<String> removedAthleteNames;
  final String footballDataKey;
  final String apiSportsKey;
  final String balldontlieKey;
  final String rapidApiDartsKey;
  final List<CustomAthlete> customAthletes;
  final String theme;
  final String overviewSort;
  final String athleteSort;

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'alerts': alerts,
        'removedAthleteNames': removedAthleteNames.toList(),
        'footballDataKey': footballDataKey,
        'apiSportsKey': apiSportsKey,
        'balldontlieKey': balldontlieKey,
        'rapidApiDartsKey': rapidApiDartsKey,
        'customAthletes':
            customAthletes.map((athlete) => athlete.toJson()).toList(),
        'theme': theme,
        'overviewSort': overviewSort,
        'athleteSort': athleteSort,
      };

  factory CourtboardLocalState.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    final rawAlerts = json['alerts'];
    final rawRemoved = json['removedAthleteNames'];
    final rawAthletes = json['customAthletes'];
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
    );
  }
}

class LocalStateStore {
  LocalStateStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;

  static File _defaultFile() {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File('$appData/courtboard_state.json');
  }

  Future<CourtboardLocalState> load() async {
    try {
      if (!await _file.exists()) return const CourtboardLocalState();
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic>
          ? CourtboardLocalState.fromJson(decoded)
          : const CourtboardLocalState();
    } catch (_) {
      return const CourtboardLocalState();
    }
  }

  Future<void> save(CourtboardLocalState state) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(state.toJson()));
  }
}
