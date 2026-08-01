import 'sports_api.dart';

class LigaFGame {
  const LigaFGame({
    required this.date,
    required this.opponent,
    required this.teamScore,
    required this.opponentScore,
    required this.home,
  });

  final DateTime date;
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

  Future<List<LigaFGame>> recentBarcelonaGames({int? year}) async {
    final payload = await _client.espnSoccerScoreboard(
        'esp.w.1', year ?? DateTime.now().year);
    return parseGames(payload, 'Barcelona');
  }

  static List<LigaFGame> parseGames(
      Map<String, dynamic> payload, String teamName) {
    final events = payload['events'];
    if (events is! List) return const [];
    final games = <LigaFGame>[];
    for (final rawEvent in events.whereType<Map>()) {
      final competitions = rawEvent['competitions'];
      if (competitions is! List || competitions.isEmpty) continue;
      final competition = competitions.first;
      if (competition is! Map) continue;
      final status = competition['status'];
      final statusType = status is Map ? status['type'] : null;
      if (statusType is Map && statusType['completed'] != true) continue;
      final competitors = competition['competitors'];
      if (competitors is! List) continue;
      final entries = competitors.whereType<Map>().toList();
      Map? team;
      Map? opponent;
      for (final entry in entries) {
        final rawTeam = entry['team'];
        final displayName = rawTeam is Map
            ? '${rawTeam['displayName'] ?? rawTeam['name'] ?? ''}'
            : '';
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
