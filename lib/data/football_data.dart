import 'sports_api.dart';

enum FootballResult { win, draw, loss, unknown }

class FootballGame {
  const FootballGame({
    required this.date,
    required this.opponent,
    required this.score,
    required this.result,
  });
  final DateTime date;
  final String opponent;
  final String score;
  final FootballResult result;
}

class FootballDataRepository {
  FootballDataRepository(this._client);
  final SportsApiClient _client;

  Future<List<FootballGame>> fetchRecentTeamGames(String teamName) async {
    if (_client.config.footballDataKey.isNotEmpty) {
      try {
        final teams = await _client.footballData('/v4/teams', {'limit': '500'});
        final id = parseFootballDataTeamId(teams, teamName);
        if (id == null) {
          throw StateError('A csapat nem található a Free listában.');
        }
        final now = DateTime.now().toUtc();
        final from = DateTime(now.year - 1, now.month, now.day);
        String date(DateTime value) => value.toIso8601String().substring(0, 10);
        final data = await _client.footballData('/v4/teams/$id/matches', {
          'status': 'FINISHED',
          'dateFrom': date(from),
          'dateTo': date(now),
        });
        final games = parseMatches(data, teamName);
        if (games.isNotEmpty) return games;
      } catch (_) {
        // A kulcs nélküli, szélesebb csapatlefedettségű fallback lent fut le.
      }
    }

    final teams = await _client.theSportsDb('/searchteams.php', {
      't': footballTeamSearchTerm(teamName),
    });
    final sportsDbId = parseTheSportsDbTeamId(teams, teamName);
    if (sportsDbId == null) return const [];
    final payloads = await Future.wait([
      _client.theSportsDb('/eventslast.php', {'id': sportsDbId}),
      _client.theSportsDb('/eventsnext.php', {'id': sportsDbId}),
    ]);
    final games = [
      ...parseTheSportsDbMatches(payloads[0], sportsDbId),
      ...parseTheSportsDbMatches(payloads[1], sportsDbId),
    ];
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList(growable: false);
  }

  static int? parseFootballDataTeamId(
    Map<String, dynamic> data,
    String teamName,
  ) {
    final teams = data['teams'];
    if (teams is! List) return null;
    final expected = normalizeFootballTeamName(teamName);
    for (final team in teams.whereType<Map>()) {
      final names = [
        '${team['name'] ?? ''}',
        '${team['shortName'] ?? ''}',
        '${team['tla'] ?? ''}',
      ];
      if (names.any((name) => normalizeFootballTeamName(name) == expected)) {
        return int.tryParse('${team['id'] ?? ''}');
      }
    }
    return null;
  }

  static String? parseTheSportsDbTeamId(
    Map<String, dynamic> data,
    String teamName,
  ) {
    final teams = data['teams'];
    if (teams is! List) return null;
    final expected = normalizeFootballTeamName(teamName);
    for (final team in teams.whereType<Map>()) {
      if ('${team['strSport'] ?? ''}'.toLowerCase() != 'soccer') continue;
      final names = <String>[
        '${team['strTeam'] ?? ''}',
        ...'${team['strTeamAlternate'] ?? ''}'.split(','),
      ];
      if (names.any((name) => normalizeFootballTeamName(name) == expected)) {
        final id = '${team['idTeam'] ?? ''}'.trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  static List<FootballGame> parseTheSportsDbMatches(
    Map<String, dynamic> data,
    String teamId,
  ) {
    final rawEvents = data['results'] ?? data['events'];
    if (rawEvents is! List) return const [];
    return rawEvents
        .whereType<Map>()
        .map((raw) {
          final isHome = '${raw['idHomeTeam'] ?? ''}' == teamId;
          final opponent = isHome
              ? '${raw['strAwayTeam'] ?? 'Ismeretlen'}'
              : '${raw['strHomeTeam'] ?? 'Ismeretlen'}';
          final ownScore = isHome ? raw['intHomeScore'] : raw['intAwayScore'];
          final otherScore = isHome ? raw['intAwayScore'] : raw['intHomeScore'];
          final own = int.tryParse('${ownScore ?? ''}');
          final other = int.tryParse('${otherScore ?? ''}');
          final result = own == null || other == null
              ? FootballResult.unknown
              : own == other
              ? FootballResult.draw
              : own > other
              ? FootballResult.win
              : FootballResult.loss;
          final date = '${raw['dateEvent'] ?? ''}';
          final time = '${raw['strTime'] ?? ''}'.trim();
          return FootballGame(
            date:
                DateTime.tryParse(time.isEmpty ? date : '${date}T$time') ??
                DateTime(2000),
            opponent: opponent,
            score: own == null || other == null ? '–' : '$own–$other',
            result: result,
          );
        })
        .toList(growable: false);
  }

  static List<FootballGame> parseMatches(
    Map<String, dynamic> data,
    String teamName,
  ) {
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
      final fullTime = Map<String, dynamic>.from(
        score['fullTime'] as Map? ?? {},
      );
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
        result: result,
      );
    }).toList();
    games.sort((a, b) => b.date.compareTo(a.date));
    return games.take(5).toList();
  }
}

String footballTeamSearchTerm(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  const clubTokens = {'fc', 'cf', 'afc', 'sc', 'ac'};
  final useful = words
      .where((word) => !clubTokens.contains(word.toLowerCase()))
      .join(' ')
      .trim();
  return useful.isEmpty ? value.trim() : useful;
}

String normalizeFootballTeamName(String value) => footballTeamSearchTerm(
  value,
).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
