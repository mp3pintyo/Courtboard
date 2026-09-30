import 'athlete_names.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';

/// Az ESPN nyilvános „site” API-jának ligái, amelyekhez csapatmenetrend
/// kérhető (`/apis/site/v2/sports/{sport}/{league}/teams/{team}/schedule`).
enum EspnLeague {
  nba('basketball', 'nba', 'NBA'),
  wnba('basketball', 'wnba', 'WNBA'),
  nfl('football', 'nfl', 'NFL');

  const EspnLeague(this.sport, this.league, this.label);

  /// Az ESPN útvonal sportága (`basketball`, `football`).
  final String sport;

  /// Az ESPN útvonal ligakódja (`nba`, `wnba`, `nfl`).
  final String league;

  /// Felhasználónak szóló rövid név.
  final String label;

  /// A Courtboard sportág-címkéjéből (`NBA`, `WNBA`, `NFL`).
  static EspnLeague? fromSport(String sport) => switch (sport.trim()) {
    'NBA' => EspnLeague.nba,
    'WNBA' => EspnLeague.wnba,
    'NFL' => EspnLeague.nfl,
    _ => null,
  };
}

/// Egy ESPN-csapat azonosítója és nevei.
class EspnTeam {
  const EspnTeam({
    required this.id,
    required this.displayName,
    this.abbreviation = '',
  });

  final String id;
  final String displayName;
  final String abbreviation;
}

/// Egy menetrendbeli mérkőzés a követett csapat szemszögéből.
class EspnScheduledGame {
  const EspnScheduledGame({
    required this.id,
    required this.start,
    required this.home,
    required this.away,
    required this.opponent,
    required this.competition,
    this.homeAway,
    this.venue,
    this.url,
    this.timeKnown = true,
    this.live = false,
  });

  final String id;

  /// Kezdési idő helyi időben (az ESPN UTC-ben küldi).
  final DateTime start;
  final String home;
  final String away;
  final String opponent;

  /// Liga és szakasz, például „NBA · Alapszakasz”.
  final String competition;

  /// `home` / `away`, ha a forrás megadja.
  final String? homeAway;
  final String? venue;

  /// Az ESPN mérkőzésoldala (Gamecast), ha van.
  final String? url;

  /// Hamis, ha az ESPN szerint az időpont még nem végleges.
  final bool timeKnown;

  /// Igaz, ha a mérkőzés éppen zajlik.
  final bool live;
}

/// Egy befejezett mérkőzés eredménye a követett csapat szemszögéből
/// (a háttérfigyelő „Új eredmény” értesítéséhez).
class EspnCompletedGame {
  const EspnCompletedGame({
    required this.id,
    required this.start,
    required this.opponent,
    required this.ownScore,
    required this.opponentScore,
    this.outcome = '',
    this.homeAway,
  });

  final String id;

  /// Kezdési idő helyi időben.
  final DateTime start;
  final String opponent;

  /// Pontszámok szövegként („118”); ismeretlennél üres.
  final String ownScore;
  final String opponentScore;

  /// `win` / `loss` / `draw`, vagy üres, ha nem állapítható meg.
  final String outcome;
  final String? homeAway;

  /// „118–104” (saját pontszám elöl), vagy üres.
  String get score => ownScore.isEmpty || opponentScore.isEmpty
      ? ''
      : '$ownScore–$opponentScore';

  Map<String, Object?> toJson() => {
    'id': id,
    'start': start.toUtc().toIso8601String(),
    'opponent': opponent,
    'ownScore': ownScore,
    'opponentScore': opponentScore,
    'outcome': outcome,
    'homeAway': homeAway,
  };

  static EspnCompletedGame? fromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonString(map['id']);
    final start = DateTime.tryParse(jsonString(map['start']) ?? '');
    if (id == null || start == null) return null;
    return EspnCompletedGame(
      id: id,
      start: start.toLocal(),
      opponent: jsonString(map['opponent']) ?? '',
      ownScore: jsonString(map['ownScore']) ?? '',
      opponentScore: jsonString(map['opponentScore']) ?? '',
      outcome: jsonString(map['outcome']) ?? '',
      homeAway: jsonString(map['homeAway']),
    );
  }
}

/// ESPN csapatlisták és -menetrendek. Kulcs nem kell; a kéréseket a közös
/// [HttpService] „ESPN” korlátja (percenként 30) fogja vissza, a csapatlista
/// 7 napig lemezes gyorsítótárból jön.
class EspnScheduleRepository {
  EspnScheduleRepository({HttpService? http, this._cacheStorage})
    : _http = http ?? HttpService.shared;

  final HttpService _http;
  final CacheStorage? _cacheStorage;

  static const provider = 'ESPN';
  static const teamsCacheLifetime = Duration(days: 7);

  /// A befejezett mérkőzések listája ennyi ideig jön gyorsítótárból (a
  /// háttérfigyelő ennél gyakrabban sem kérdezi az ESPN-t).
  static const resultsCacheLifetime = Duration(minutes: 60);

  JsonFileCache get _cache => JsonFileCache('espn', storage: _cacheStorage);

  static Uri teamsUri(EspnLeague league) => Uri.https(
    'site.api.espn.com',
    '/apis/site/v2/sports/${league.sport}/${league.league}/teams',
  );

  static Uri scheduleUri(
    EspnLeague league,
    String teamId, {
    int? seasonType,
    int? season,
  }) => Uri.https(
    'site.api.espn.com',
    '/apis/site/v2/sports/${league.sport}/${league.league}/teams/$teamId/schedule',
    seasonType == null && season == null
        ? null
        : {
            if (season != null) 'season': '$season',
            if (seasonType != null) 'seasontype': '$seasonType',
          },
  );

  /// Az ESPN szezonévének becslése: az NBA szezonját a záró év jelöli
  /// (2026–27 → 2027), az NFL-ét a kezdő év (márciusig az előző), a WNBA-ét
  /// a naptári év.
  static int currentSeasonYear(EspnLeague league, DateTime now) =>
      switch (league) {
        EspnLeague.nba => now.month >= 8 ? now.year + 1 : now.year,
        EspnLeague.nfl => now.month >= 3 ? now.year : now.year - 1,
        EspnLeague.wnba => now.year,
      };

  /// A liga csapatlistája (7 napos gyorsítótárral).
  Future<Map<String, dynamic>> teams(EspnLeague league) async =>
      (await _cache.getOrFetch<Map<String, dynamic>>(
        'teams_${league.league}',
        ttl: teamsCacheLifetime,
        fetch: () => _http.getJson(teamsUri(league), provider: provider),
        encode: (value) => value,
        decode: jsonMap,
      )).value;

  /// A [teamName] csapat ESPN-azonosítója, vagy `null`, ha nincs ilyen.
  Future<EspnTeam?> findTeam(EspnLeague league, String teamName) async =>
      findTeamIn(await teams(league), teamName);

  /// A csapat közelgő mérkőzései. Az ESPN alapból az aktuális szezonszakaszt
  /// adja; felkészülési időszakban (1) az alapszakaszt (2) is lekéri.
  Future<List<EspnScheduledGame>> upcomingGames(
    EspnLeague league,
    EspnTeam team, {
    DateTime? now,
  }) async {
    final first = await _http.getJson(
      scheduleUri(league, team.id),
      provider: provider,
    );
    final payloads = [first];
    final seasonType = jsonIntOrNull(jsonMap(first['requestedSeason'])['type']);
    if (seasonType == 1) {
      payloads.add(
        await _http.getJson(
          scheduleUri(league, team.id, seasonType: 2),
          provider: provider,
        ),
      );
    }
    final seen = <String>{};
    return [
      for (final payload in payloads)
        for (final game in parseSchedule(payload, league: league, team: team))
          if (seen.add(game.id)) game,
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// A csapat legutóbbi befejezett mérkőzései (legfeljebb [limit], a
  /// legújabb elöl), [resultsCacheLifetime] ideig lemezes gyorsítótárból.
  Future<List<EspnCompletedGame>> recentResults(
    EspnLeague league,
    EspnTeam team, {
    int limit = 10,
    bool forceRefresh = false,
  }) async => (await seasonResults(
    league,
    team,
    forceRefresh: forceRefresh,
  )).take(limit).toList(growable: false);

  /// A csapat összes befejezett mérkőzése az aktuális (vagy a [season])
  /// szezonban, a legújabb elöl. Az aktuális szezon [resultsCacheLifetime],
  /// egy korábbi szezon alapszakasza 7 napig jön gyorsítótárból.
  Future<List<EspnCompletedGame>> seasonResults(
    EspnLeague league,
    EspnTeam team, {
    int? season,
    bool forceRefresh = false,
  }) async => (await _cache.getOrFetch<List<EspnCompletedGame>>(
    season == null
        ? 'results_${league.league}_${team.id}'
        : 'results_${league.league}_${team.id}_$season',
    ttl: season == null ? resultsCacheLifetime : const Duration(days: 7),
    forceRefresh: forceRefresh,
    fetch: () async {
      final payload = await _http.getJson(
        scheduleUri(
          league,
          team.id,
          season: season,
          seasonType: season == null ? null : 2,
        ),
        provider: provider,
      );
      return parseCompletedGames(payload, league: league, team: team);
    },
    encode: (value) => {
      'games': [for (final game in value) game.toJson()],
    },
    decode: (json) => [
      for (final raw in jsonList(jsonMap(json)['games']))
        if (EspnCompletedGame.fromJson(raw) case final game?) game,
    ],
  )).value;

  /// Egy menetrend-válasz befejezett mérkőzései a [team] szemszögéből, a
  /// legújabb elöl. A törölt / elhalasztott meccsek kimaradnak.
  static List<EspnCompletedGame> parseCompletedGames(
    Map<String, dynamic> payload, {
    required EspnLeague league,
    required EspnTeam team,
  }) {
    bool isOwn(Map<String, dynamic> competitor) {
      final raw = jsonMap(competitor['team']);
      final id = jsonString(raw['id']) ?? jsonString(competitor['id']);
      if (id != null && team.id.isNotEmpty) return id == team.id;
      return normalizeAthleteName('${raw['displayName'] ?? ''}') ==
          normalizeAthleteName(team.displayName);
    }

    String scoreOf(Map<String, dynamic>? competitor) {
      final raw = competitor?['score'];
      if (raw is Map) {
        final display = jsonString(raw['displayValue']);
        if (display != null) return display;
        final value = raw['value'];
        if (value is num) return value.round().toString();
        return '';
      }
      if (raw is num) return raw.round().toString();
      return jsonString(raw) ?? '';
    }

    final games = <EspnCompletedGame>[];
    for (final event in jsonMapList(payload['events'])) {
      final competitions = jsonMapList(event['competitions']);
      if (competitions.isEmpty) continue;
      final competition = competitions.first;
      final statusType = jsonMap(jsonMap(competition['status'])['type']);
      final completed =
          statusType['completed'] == true ||
          jsonString(statusType['state']) == 'post';
      if (!completed) continue;
      final name = jsonString(statusType['name']) ?? '';
      if (name.contains('CANCELED') || name.contains('POSTPONED')) continue;
      final start = DateTime.tryParse(
        jsonString(competition['date']) ?? jsonString(event['date']) ?? '',
      );
      if (start == null) continue;
      final competitors = jsonMapList(competition['competitors']);
      final own = competitors.where(isOwn).firstOrNull;
      if (own == null) continue;
      final other = competitors.where((c) => !identical(c, own)).firstOrNull;
      final ownScore = scoreOf(own);
      final otherScore = scoreOf(other);
      var outcome = '';
      if (own['winner'] == true) {
        outcome = 'win';
      } else if (other?['winner'] == true) {
        outcome = 'loss';
      } else {
        final a = num.tryParse(ownScore);
        final b = num.tryParse(otherScore);
        if (a != null && b != null) {
          outcome = a > b
              ? 'win'
              : a < b
              ? 'loss'
              : 'draw';
        }
      }
      final opponent = jsonMap(other?['team']);
      games.add(
        EspnCompletedGame(
          id:
              jsonString(event['id']) ??
              jsonString(competition['id']) ??
              start.toUtc().toIso8601String(),
          start: start.toLocal(),
          opponent:
              jsonString(opponent['displayName']) ??
              jsonString(opponent['name']) ??
              '',
          ownScore: ownScore,
          opponentScore: otherScore,
          outcome: outcome,
          homeAway: switch (jsonString(own['homeAway'])) {
            'home' => 'home',
            'away' => 'away',
            _ => null,
          },
        ),
      );
    }
    games.sort((a, b) => b.start.compareTo(a.start));
    return games;
  }

  /// A csapatlista (`sports[].leagues[].teams[].team`) közül a névhez illő.
  /// Elfogadja a teljes nevet („Denver Nuggets”), a rövidítést („DEN”), a
  /// becenevet („Nuggets”) és a város + becenév alakot.
  static EspnTeam? findTeamIn(Map<String, dynamic> payload, String teamName) {
    final expected = normalizeAthleteName(teamName);
    if (expected.isEmpty) return null;
    final teams = <Map<String, dynamic>>[
      for (final sport in jsonMapList(payload['sports']))
        for (final league in jsonMapList(sport['leagues']))
          for (final entry in jsonMapList(league['teams']))
            jsonMap(entry['team']),
    ];
    EspnTeam toTeam(Map<String, dynamic> team) => EspnTeam(
      id: jsonString(team['id']) ?? '',
      displayName: jsonString(team['displayName']) ?? teamName,
      abbreviation: jsonString(team['abbreviation']) ?? '',
    );
    List<String> namesOf(Map<String, dynamic> team) => [
      for (final key in const ['displayName', 'abbreviation', 'slug'])
        if (jsonString(team[key]) case final String value) value,
      '${team['location'] ?? ''} ${team['name'] ?? ''}',
    ];
    // Először pontos egyezés a teljes névre vagy a rövidítésre…
    for (final team in teams) {
      if (jsonString(team['id']) == null) continue;
      if (namesOf(team).any(
        (name) => normalizeAthleteName(name.replaceAll('-', ' ')) == expected,
      )) {
        return toTeam(team);
      }
    }
    // …majd a becenévre („Nuggets”, „Fever”).
    for (final team in teams) {
      if (jsonString(team['id']) == null) continue;
      final nickname = [
        jsonString(team['name']),
        jsonString(team['shortDisplayName']),
      ].whereType<String>().map(normalizeAthleteName);
      if (nickname.contains(expected)) return toTeam(team);
    }
    return null;
  }

  /// Egy menetrend- vagy scoreboard-válasz (`events[]`) még le nem játszott
  /// mérkőzései a [team] szemszögéből. A befejezett és törölt meccsek
  /// kimaradnak; a zajlók `live: true` jelzéssel maradnak.
  static List<EspnScheduledGame> parseSchedule(
    Map<String, dynamic> payload, {
    required EspnLeague league,
    required EspnTeam team,
  }) => parseEvents(
    payload,
    competitionLabel: (event) =>
        '${league.label} · ${_phaseLabel(jsonMap(event['seasonType']))}'
        '${_weekLabel(jsonMap(event['week']))}',
    isOwnTeam: (competitor) {
      final raw = jsonMap(competitor['team']);
      final id = jsonString(raw['id']) ?? jsonString(competitor['id']);
      if (id != null && team.id.isNotEmpty) return id == team.id;
      return normalizeAthleteName('${raw['displayName'] ?? ''}') ==
          normalizeAthleteName(team.displayName);
    },
  );

  /// Általános ESPN `events[]` feldolgozó (menetrend és scoreboard is).
  static List<EspnScheduledGame> parseEvents(
    Map<String, dynamic> payload, {
    required String Function(Map<String, dynamic> event) competitionLabel,
    required bool Function(Map<String, dynamic> competitor) isOwnTeam,
  }) {
    final games = <EspnScheduledGame>[];
    for (final event in jsonMapList(payload['events'])) {
      final competitions = jsonMapList(event['competitions']);
      if (competitions.isEmpty) continue;
      final competition = competitions.first;
      final statusType = jsonMap(jsonMap(competition['status'])['type']);
      final state = jsonString(statusType['state']) ?? 'pre';
      if (state == 'post' || statusType['completed'] == true) continue;
      final name = jsonString(statusType['name']) ?? '';
      if (name.contains('CANCELED') || name.contains('POSTPONED')) continue;
      final start = DateTime.tryParse(
        jsonString(competition['date']) ?? jsonString(event['date']) ?? '',
      );
      if (start == null) continue;
      final competitors = jsonMapList(competition['competitors']);
      final own = competitors.where(isOwnTeam).firstOrNull;
      if (own == null) continue;
      final other = competitors.where((c) => !identical(c, own)).firstOrNull;
      String teamName(Map<String, dynamic>? competitor) {
        final raw = jsonMap(competitor?['team']);
        return jsonString(raw['displayName']) ??
            jsonString(raw['name']) ??
            'Ismeretlen';
      }

      final home = competitors
          .where((c) => jsonString(c['homeAway']) == 'home')
          .firstOrNull;
      final away = competitors
          .where((c) => jsonString(c['homeAway']) == 'away')
          .firstOrNull;
      final venue = jsonMap(competition['venue']);
      final address = jsonMap(venue['address']);
      final venueName = [
        jsonString(venue['fullName']),
        jsonString(address['city']),
      ].whereType<String>().join(', ');
      final id =
          jsonString(event['id']) ??
          jsonString(competition['id']) ??
          '${start.toUtc().toIso8601String()}-${teamName(other)}';
      games.add(
        EspnScheduledGame(
          id: id,
          start: start.toLocal(),
          home: teamName(home ?? own),
          away: teamName(away ?? other),
          opponent: other == null ? '' : teamName(other),
          competition: competitionLabel(event),
          homeAway: switch (jsonString(own['homeAway'])) {
            'home' => 'home',
            'away' => 'away',
            _ => null,
          },
          venue: venueName.isEmpty ? null : venueName,
          url: _gameUrl(event),
          timeKnown:
              event['timeValid'] != false && competition['timeValid'] != false,
          live: state == 'in',
        ),
      );
    }
    games.sort((a, b) => a.start.compareTo(b.start));
    return games;
  }

  static String _phaseLabel(Map<String, dynamic> seasonType) =>
      switch (jsonIntOrNull(seasonType['type'])) {
        1 => 'Felkészülési mérkőzés',
        2 => 'Alapszakasz',
        3 => 'Rájátszás',
        4 => 'Szezonon kívül',
        _ => jsonString(seasonType['name']) ?? 'Mérkőzés',
      };

  static String _weekLabel(Map<String, dynamic> week) {
    final number = jsonIntOrNull(week['number']);
    return number == null ? '' : ' · $number. hét';
  }

  /// A „summary”/„desktop” jelölésű, https-es ESPN-link.
  static String? _gameUrl(Map<String, dynamic> event) {
    String? fallback;
    for (final link in jsonMapList(event['links'])) {
      final href = jsonString(link['href']);
      if (href == null || !href.startsWith('https://')) continue;
      final rel = jsonList(link['rel']).map((value) => '$value').toSet();
      if (rel.contains('summary') && rel.contains('desktop')) return href;
      fallback ??= href;
    }
    return fallback;
  }
}
