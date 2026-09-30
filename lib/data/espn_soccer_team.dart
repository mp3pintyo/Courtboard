/// Egy focicsapat legutóbbi eredményei az ESPN bajnoki scoreboardjából
/// (kulcs nélkül), bármely ott szereplő férfi vagy női bajnokságban.
///
/// A 0.13.0 előtt ez a `LigaFRepository` volt, a Barcelona női csapatára
/// és az `esp.w.1` ligára égetve; most a bajnokság és a csapat az
/// [EspnSoccerTeam] leíróból jön (a sportoló adatforrás-tippjeiből).
library;

import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/football_names.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/domain/athlete_source_hints.dart';

/// Egy csapat egy ESPN-bajnokságban: ligakód, keresett csapatnév és a
/// felületen megjelenő nevek.
class EspnSoccerTeam {
  const EspnSoccerTeam({
    required this.league,
    required this.team,
    this.competition = '',
    this.womensTeam = false,
    this.label,
    this.clubName = '',
  });

  /// A sportoló adatforrás-tippjeiből és csapatnevéből; `null`, ha nincs
  /// ESPN-ligakód, vagy nincs mi alapján csapatot keresni.
  static EspnSoccerTeam? fromHints(AthleteSourceHints hints, String team) {
    final league = hints.espnLeague;
    if (league == null) return null;
    final club = team.trim();
    final search = (hints.espnTeam ?? club).trim();
    if (search.isEmpty) return null;
    return EspnSoccerTeam(
      league: league,
      team: search,
      competition: hints.competition ?? '',
      womensTeam: hints.womensTeam,
      label: hints.teamLabel,
      clubName: club.isEmpty ? search : club,
    );
  }

  /// ESPN-ligakód (például `esp.w.1`).
  final String league;

  /// A keresett csapatnév az ESPN-ben (például `Barcelona`).
  final String team;

  /// A bajnokság megjelenített neve (például „Liga F”); üres esetén a
  /// ligakód.
  final String competition;

  /// A klub női csapata.
  final bool womensTeam;

  /// A megjelenített csapatnév, ha megadták (például „FC Barcelona
  /// Femení”).
  final String? label;

  /// A sportolónál megadott klubnév (például „FC Barcelona”).
  final String clubName;

  /// A bajnokság neve a felületen.
  String get competitionLabel => competition.isEmpty ? league : competition;

  /// A csapat neve a kártya címében.
  String get displayName {
    if (label != null) return label!;
    if (!womensTeam || _hasWomenSuffix(clubName)) return clubName;
    return '$clubName (női)';
  }

  /// A kártya alcíme: női csapatnál kiemeli, hogy nem a férfi csapat
  /// eredményei látszanak.
  String get description => womensTeam
      ? 'Valós női $team csapateredmények; nem a férfi '
            '${_withoutWomenSuffix(clubName)} feedje.'
      : 'Valós $clubName csapateredmények.';

  /// Az ESPN-csapatnév erre a csapatra utal-e (a női utótagok nélkül,
  /// tartalmazás vagy klubnév-egyezés alapján).
  bool matches(String espnName) {
    final expected = teamKey(team);
    final candidate = teamKey(espnName);
    if (expected.isEmpty || candidate.isEmpty) return false;
    return candidate.contains(expected) ||
        footballTeamNamesMatch(team, espnName);
  }

  /// Összehasonlító kulcs: kisbetűs, ékezet, női utótag és írásjel
  /// nélkül (`FC Barcelona Femení` → `fcbarcelona`).
  static String teamKey(String value) {
    var key = normalizeAthleteName(value);
    for (final suffix in _womenSuffixes) {
      key = key.replaceAll(suffix, '');
    }
    return key.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Női csapatnév-utótagok (ékezet nélkül; a [teamKey] már normalizált
  /// szövegből veszi ki őket).
  static const _womenSuffixes = [
    'femenino',
    'femeni',
    'feminines',
    'women',
    'frauen',
  ];

  static bool _hasWomenSuffix(String value) {
    final normalized = normalizeAthleteName(value);
    return _womenSuffixes.any(normalized.contains);
  }

  static String _withoutWomenSuffix(String value) {
    var result = value;
    for (final suffix in const [
      'Femenino',
      'Femení',
      'Femeni',
      'Féminines',
      'Feminines',
      'Women',
      'Frauen',
    ]) {
      result = result.replaceAll(RegExp(suffix, caseSensitive: false), '');
    }
    final trimmed = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.isEmpty ? value.trim() : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is EspnSoccerTeam &&
      other.league == league &&
      other.team == team &&
      other.competition == competition &&
      other.womensTeam == womensTeam &&
      other.label == label &&
      other.clubName == clubName;

  @override
  int get hashCode =>
      Object.hash(league, team, competition, womensTeam, label, clubName);
}

/// Egy lejátszott bajnoki mérkőzés a csapat szemszögéből.
class EspnSoccerGame {
  const EspnSoccerGame({
    required this.date,
    required this.opponent,
    required this.teamScore,
    required this.opponentScore,
    required this.home,
    this.eventId,
  });

  final DateTime date;

  /// ESPN-mérkőzésazonosító (az idővonalhoz), ha ismert.
  final String? eventId;
  final String opponent;
  final int teamScore;
  final int opponentScore;
  final bool home;

  String get score => '$teamScore–$opponentScore';
  String get result => teamScore > opponentScore
      ? 'GYŐZELEM'
      : teamScore < opponentScore
      ? 'VERESÉG'
      : 'DÖNTETLEN';
}

class EspnSoccerTeamRepository {
  EspnSoccerTeamRepository([SportsApiClient? client])
    : _client = client ?? SportsApiClient();

  final SportsApiClient _client;

  /// Visszafelé kompatibilis: a közös HTTP-klienst nem zárja le.
  void close() => _client.close();

  /// A csapat legutóbbi lejátszott bajnoki mérkőzései.
  ///
  /// Az ESPN scoreboard `dates=ÉÉÉÉHHNN-ÉÉÉÉHHNN` tartományt kap az utolsó
  /// [window] napra; ha ebben nincs lejátszott meccs (nyári szünet), egy
  /// egyéves ablakkal próbálja újra.
  Future<List<EspnSoccerGame>> recentGames(
    EspnSoccerTeam team, {
    DateTime? now,
    Duration window = const Duration(days: 60),
  }) async {
    final today = now ?? DateTime.now();
    final recent = parseGames(
      await _client.espnSoccerScoreboard(
        team.league,
        from: today.subtract(window),
        to: today,
      ),
      team,
    );
    if (recent.isNotEmpty) return recent;
    return parseGames(
      await _client.espnSoccerScoreboard(
        team.league,
        from: today.subtract(const Duration(days: 365)),
        to: today,
        limit: 500,
      ),
      team,
    );
  }

  /// A scoreboard befejezett meccsei a [team] szemszögéből (legfrissebb
  /// elöl, legfeljebb 5).
  static List<EspnSoccerGame> parseGames(
    Map<String, dynamic> payload,
    EspnSoccerTeam team,
  ) {
    final games = <EspnSoccerGame>[];
    for (final rawEvent in jsonMapList(payload['events'])) {
      final competitions = jsonList(rawEvent['competitions']);
      if (competitions.isEmpty) continue;
      final competition = competitions.first;
      if (competition is! Map) continue;
      final status = competition['status'];
      final statusType = status is Map ? status['type'] : null;
      if (statusType is Map && statusType['completed'] != true) continue;
      final competitors = competition['competitors'];
      if (competitors is! List) continue;
      final entries = jsonMapList(competitors);
      Map<String, dynamic>? own;
      Map<String, dynamic>? opponent;
      for (final entry in entries) {
        final rawTeam = jsonMap(entry['team']);
        final displayName =
            '${rawTeam['displayName'] ?? rawTeam['name'] ?? ''}';
        if (team.matches(displayName)) own = entry;
      }
      if (own == null) continue;
      for (final entry in entries) {
        if (!identical(entry, own)) opponent = entry;
      }
      if (opponent == null) continue;
      final date = DateTime.tryParse('${rawEvent['date'] ?? ''}');
      if (date == null) continue;
      final opponentTeam = opponent['team'];
      games.add(
        EspnSoccerGame(
          date: date,
          opponent: opponentTeam is Map
              ? '${opponentTeam['displayName'] ?? opponentTeam['name'] ?? 'Ismeretlen'}'
              : 'Ismeretlen',
          teamScore: int.tryParse('${own['score'] ?? ''}') ?? 0,
          opponentScore: int.tryParse('${opponent['score'] ?? ''}') ?? 0,
          home: '${own['homeAway']}' == 'home',
          eventId: jsonString(rawEvent['id']),
        ),
      );
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }
}
