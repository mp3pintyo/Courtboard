import 'sports_api.dart';

enum FootballResult { win, draw, loss, unknown }

class FootballGame {
  const FootballGame(
      {required this.date,
      required this.opponent,
      required this.score,
      required this.result});
  final DateTime date;
  final String opponent;
  final String score;
  final FootballResult result;
}

class FootballDataRepository {
  FootballDataRepository(this._client);
  final SportsApiClient _client;

  static const teamIds = {'liverpool': 64, 'liverpool fc': 64};

  Future<List<FootballGame>> fetchRecentTeamGames(String teamName) async {
    final id = teamIds[teamName.trim().toLowerCase()];
    if (id == null) return const [];
    final now = DateTime.now().toUtc();
    final from = DateTime(now.year - 1, now.month, now.day);
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    final data = await _client.footballData('/v4/teams/$id/matches', {
      'status': 'FINISHED',
      'dateFrom': date(from),
      'dateTo': date(now),
    });
    return parseMatches(data, teamName);
  }

  static List<FootballGame> parseMatches(
      Map<String, dynamic> data, String teamName) {
    final matches = data['matches'];
    if (matches is! List) return const [];
    final normalized = teamName.trim().toLowerCase().replaceAll(' fc', '');
    final games = matches.whereType<Map>().map((raw) {
      final home = Map<String, dynamic>.from(raw['homeTeam'] as Map? ?? {});
      final away = Map<String, dynamic>.from(raw['awayTeam'] as Map? ?? {});
      final homeName = '${home['name'] ?? ''}';
      final awayName = '${away['name'] ?? ''}';
      final isHome = homeName.toLowerCase().replaceAll(' fc', '') == normalized;
      final score = Map<String, dynamic>.from(raw['score'] as Map? ?? {});
      final fullTime =
          Map<String, dynamic>.from(score['fullTime'] as Map? ?? {});
      final homeScore = fullTime['home'] ?? 0;
      final awayScore = fullTime['away'] ?? 0;
      final winner = '${score['winner'] ?? ''}';
      final result = winner == 'DRAW'
          ? FootballResult.draw
          : (isHome && winner == 'HOME_TEAM') ||
                  (!isHome && winner == 'AWAY_TEAM')
              ? FootballResult.win
              : FootballResult.loss;
      return FootballGame(
          date: DateTime.tryParse('${raw['utcDate']}') ?? DateTime(2000),
          opponent: isHome ? awayName : homeName,
          score: isHome ? '$homeScore–$awayScore' : '$awayScore–$homeScore',
          result: result);
    }).toList();
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }
}
