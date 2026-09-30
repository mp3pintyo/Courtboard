import 'json_util.dart';
import 'sports_api.dart';

class LigaFGame {
  const LigaFGame({
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

class LigaFRepository {
  LigaFRepository([SportsApiClient? client])
      : _client = client ?? SportsApiClient();

  final SportsApiClient _client;

  /// Visszafelé kompatibilis: a közös HTTP-klienst nem zárja le.
  void close() => _client.close();

  /// A Barcelona legutóbbi lejátszott Liga F mérkőzései.
  ///
  /// Az ESPN scoreboard `dates=ÉÉÉÉHHNN-ÉÉÉÉHHNN` tartományt kap az utolsó
  /// [window] napra; ha ebben nincs lejátszott meccs (nyári szünet), egy
  /// egyéves ablakkal próbálja újra.
  Future<List<LigaFGame>> recentBarcelonaGames({
    DateTime? now,
    Duration window = const Duration(days: 60),
  }) async {
    final today = now ?? DateTime.now();
    final recent = parseGames(
        await _client.espnSoccerScoreboard('esp.w.1',
            from: today.subtract(window), to: today),
        'Barcelona');
    if (recent.isNotEmpty) return recent;
    return parseGames(
        await _client.espnSoccerScoreboard('esp.w.1',
            from: today.subtract(const Duration(days: 365)),
            to: today,
            limit: 500),
        'Barcelona');
  }

  static List<LigaFGame> parseGames(
      Map<String, dynamic> payload, String teamName) {
    final games = <LigaFGame>[];
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
      Map<String, dynamic>? team;
      Map<String, dynamic>? opponent;
      for (final entry in entries) {
        final rawTeam = jsonMap(entry['team']);
        final displayName =
            '${rawTeam['displayName'] ?? rawTeam['name'] ?? ''}';
        if (_teamName(displayName).contains(_teamName(teamName))) {
          team = entry;
        }
      }
      if (team == null) continue;
      for (final entry in entries) {
        if (!identical(entry, team)) opponent = entry;
      }
      if (opponent == null) continue;
      final date = DateTime.tryParse('${rawEvent['date'] ?? ''}');
      if (date == null) continue;
      final opponentTeam = opponent['team'];
      games.add(LigaFGame(
        date: date,
        opponent: opponentTeam is Map
            ? '${opponentTeam['displayName'] ?? opponentTeam['name'] ?? 'Ismeretlen'}'
            : 'Ismeretlen',
        teamScore: int.tryParse('${team['score'] ?? ''}') ?? 0,
        opponentScore: int.tryParse('${opponent['score'] ?? ''}') ?? 0,
        home: '${team['homeAway']}' == 'home',
        eventId: jsonString(rawEvent['id']),
      ));
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }
}

String _teamName(String value) => value
    .toLowerCase()
    .replaceAll('femení', '')
    .replaceAll('femeni', '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');
