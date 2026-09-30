import 'package:flutter/foundation.dart' show visibleForTesting;

import 'athlete_names.dart';
import 'espn_schedule.dart';
import 'football_names.dart';
import 'friendly_error.dart';
import 'http_service.dart';
import 'json_file_cache.dart';
import 'json_util.dart';
import 'upcoming_events.dart';

/// Egy mérkőzés állapota a scoreboardon.
enum LiveGameState { scheduled, live, finished }

/// Az egyik csapat a scoreboardon.
class LiveTeam {
  const LiveTeam({
    required this.name,
    this.abbreviation = '',
    this.shortName = '',
    this.score = '',
    this.id = '',
  });

  final String name;
  final String abbreviation;

  /// Becenév („Nuggets”) vagy rövid név, ha a forrás adja.
  final String shortName;

  /// Pontszám szövegként; kezdés előtt üres.
  final String score;

  /// A forrás saját csapatazonosítója (ESPN-nél az ESPN-azonosító).
  final String id;

  Map<String, Object?> toJson() => {
    'name': name,
    'abbreviation': abbreviation,
    'shortName': shortName,
    'score': score,
    'id': id,
  };

  static LiveTeam fromJson(Object? json) {
    final map = jsonMap(json);
    return LiveTeam(
      name: jsonString(map['name']) ?? '',
      abbreviation: jsonString(map['abbreviation']) ?? '',
      shortName: jsonString(map['shortName']) ?? '',
      score: jsonString(map['score']) ?? '',
      id: jsonString(map['id']) ?? '',
    );
  }
}

/// Egy mérkőzés a (napi) scoreboardról.
class LiveGame {
  const LiveGame({
    required this.id,
    required this.sport,
    required this.source,
    required this.state,
    required this.home,
    required this.away,
    required this.start,
    this.status = '',
    this.espnEventId,
    this.espnLeague,
    this.url,
  });

  final String id;

  /// Courtboard sportág-címke (`NBA`, `WNBA`, `NFL`, `Foci`).
  final String sport;

  /// Az adatforrás neve (`NBA CDN` vagy `ESPN`).
  final String source;
  final LiveGameState state;
  final LiveTeam home;
  final LiveTeam away;
  final DateTime start;

  /// Magyar állapotfelirat („3. negyed · 5:32”, „63. perc”, „Vége”).
  final String status;

  /// ESPN-mérkőzésazonosító (a foci-idővonalhoz), ha ismert.
  final String? espnEventId;

  /// ESPN ligakód az összefoglalóhoz (`esp.w.1`, `all`).
  final String? espnLeague;
  final String? url;

  bool get isLive => state == LiveGameState.live;
  bool get isFinished => state == LiveGameState.finished;

  /// „DEN 84–79 UTA” jellegű rövid sor (hazai elöl).
  String get scoreLine {
    String label(LiveTeam team) =>
        team.abbreviation.isNotEmpty ? team.abbreviation : team.name;
    if (home.score.isEmpty || away.score.isEmpty) {
      return '${label(away)} @ ${label(home)}';
    }
    return '${label(home)} ${home.score}–${away.score} ${label(away)}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sport': sport,
    'source': source,
    'state': state.name,
    'home': home.toJson(),
    'away': away.toJson(),
    'start': start.toUtc().toIso8601String(),
    'status': status,
    'espnEventId': espnEventId,
    'espnLeague': espnLeague,
    'url': url,
  };

  static LiveGame? fromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonString(map['id']);
    final start = DateTime.tryParse(jsonString(map['start']) ?? '');
    if (id == null || start == null) return null;
    return LiveGame(
      id: id,
      sport: jsonString(map['sport']) ?? '',
      source: jsonString(map['source']) ?? '',
      state:
          LiveGameState.values
              .where((value) => value.name == jsonString(map['state']))
              .firstOrNull ??
          LiveGameState.scheduled,
      home: LiveTeam.fromJson(map['home']),
      away: LiveTeam.fromJson(map['away']),
      start: start.toLocal(),
      status: jsonString(map['status']) ?? '',
      espnEventId: jsonString(map['espnEventId']),
      espnLeague: jsonString(map['espnLeague']),
      url: jsonString(map['url']),
    );
  }
}

/// Egy követett sportoló csapatának mérkőzése a scoreboardon.
class AthleteLiveGame {
  const AthleteLiveGame({
    required this.athleteName,
    required this.game,
    required this.ownIsHome,
  });

  final String athleteName;
  final LiveGame game;

  /// Igaz, ha a sportoló csapata a hazai.
  final bool ownIsHome;

  LiveTeam get own => ownIsHome ? game.home : game.away;
  LiveTeam get opponent => ownIsHome ? game.away : game.home;

  /// „84–79” (saját pontszám elöl), vagy üres.
  String get score => own.score.isEmpty || opponent.score.isEmpty
      ? ''
      : '${own.score}–${opponent.score}';

  /// `win` / `loss` / `draw` a befejezett meccsnél, különben üres.
  String get outcome {
    if (!game.isFinished) return '';
    final a = num.tryParse(own.score);
    final b = num.tryParse(opponent.score);
    if (a == null || b == null) return '';
    return a > b
        ? 'win'
        : a < b
        ? 'loss'
        : 'draw';
  }

  /// Stabil kulcs a figyelőnek.
  String get key => '${game.source}:${game.id}';
}

/// Egy scoreboard-lekérés eredménye.
class LiveBoard {
  const LiveBoard({
    required this.feed,
    required this.games,
    required this.source,
    this.note,
    this.fetchedAt,
    this.fromCache = false,
  });

  final LiveFeed feed;
  final List<LiveGame> games;

  /// A ténylegesen használt forrás (`NBA CDN` / `ESPN`).
  final String source;

  /// Nem végzetes megjegyzés (például: „NBA CDN nem érhető el, ESPN-tartalék”).
  final String? note;
  final DateTime? fetchedAt;
  final bool fromCache;
}

/// A figyelt scoreboardok.
enum LiveFeed {
  nba('NBA', 'basketball/nba'),
  wnba('WNBA', 'basketball/wnba'),
  nfl('NFL', 'football/nfl'),
  soccer('Foci', 'soccer/all'),
  ligaF('Foci', 'soccer/esp.w.1');

  const LiveFeed(this.sport, this.espnPath);
  final String sport;
  final String espnPath;

  /// A sportoló sportágához tartozó scoreboard.
  static LiveFeed? forTarget(UpcomingEventsTarget target) =>
      switch (target.sport) {
        'NBA' => LiveFeed.nba,
        'WNBA' => LiveFeed.wnba,
        'NFL' => LiveFeed.nfl,
        'Foci' when target.isLigaF => LiveFeed.ligaF,
        'Foci' => LiveFeed.soccer,
        _ => null,
      };

  EspnLeague? get espnLeague => switch (this) {
    LiveFeed.nba => EspnLeague.nba,
    LiveFeed.wnba => EspnLeague.wnba,
    LiveFeed.nfl => EspnLeague.nfl,
    _ => null,
  };
}

/// A követett sportolók élő (és a mai befejezett) mérkőzései.
class LiveScoresResult {
  const LiveScoresResult({
    this.games = const [],
    this.sources = const {},
    this.errors = const {},
    this.notes = const [],
  });

  final List<AthleteLiveGame> games;

  /// Scoreboard → a ténylegesen használt forrás.
  final Map<LiveFeed, String> sources;

  /// Scoreboard → felhasználóbarát hibaüzenet.
  final Map<LiveFeed, String> errors;
  final List<String> notes;

  List<AthleteLiveGame> get live => [
    for (final game in games)
      if (game.game.isLive) game,
  ];

  List<AthleteLiveGame> get finished => [
    for (final game in games)
      if (game.game.isFinished) game,
  ];

  List<AthleteLiveGame> forAthlete(String name) => [
    for (final game in games)
      if (game.athleteName == name) game,
  ];

  bool get hasLive => games.any((game) => game.game.isLive);

  /// Van-e ma még kezdődő (vagy zajló) mérkőzés — a lekérdezés
  /// gyakoriságához.
  bool get hasPending => games.any((game) => !game.game.isFinished);
}

/// Élő eredmények kulcs nélkül:
///
/// * NBA: `cdn.nba.com/.../todaysScoreboard_00.json` (a szerver kb. 10 mp-es
///   gyorsítótárral dolgozik); ha nem elérhető (például HTTP 403), az ESPN
///   NBA-scoreboardja a tartalék.
/// * WNBA, NFL, foci: ESPN `site/v2/sports/{sport}/{liga}/scoreboard` (a foci
///   `soccer/all` napi összesítője, Liga F-hez `esp.w.1`).
///
/// A scoreboardok [cacheLifetime] (alapból 45 mp) ideig gyorsítótárból
/// jönnek, így a nyitóoldal, a profil és a háttérfigyelő együtt sem kér
/// gyakrabban. Hálózati hibánál a régebbi lista is visszajöhet.
class LiveScoresRepository {
  LiveScoresRepository({
    HttpService? http,
    this._cacheStorage,
    this.cacheLifetime = const Duration(seconds: 45),
    EspnScheduleRepository? schedule,
  }) : _http = http ?? HttpService.shared,
       _scheduleOverride = schedule;

  final HttpService _http;
  final CacheStorage? _cacheStorage;
  final Duration cacheLifetime;
  final EspnScheduleRepository? _scheduleOverride;
  late final EspnScheduleRepository _schedule =
      _scheduleOverride ??
      EspnScheduleRepository(http: _http, cacheStorage: _cacheStorage);

  static const nbaCdnProvider = 'NBA CDN';
  static const espnProvider = 'ESPN';

  static final nbaCdnUri = Uri.https(
    'cdn.nba.com',
    '/static/json/liveData/scoreboard/todaysScoreboard_00.json',
  );

  static Uri espnScoreboardUri(LiveFeed feed) => Uri.https(
    'site.api.espn.com',
    '/apis/site/v2/sports/${feed.espnPath}/scoreboard',
    feed == LiveFeed.soccer ? {'limit': '300'} : null,
  );

  JsonFileCache get _cache =>
      JsonFileCache('live_scores', storage: _cacheStorage);

  /// Egy scoreboard (gyorsítótárral).
  Future<LiveBoard> board(LiveFeed feed, {bool force = false}) async {
    final cached = await _cache.getOrFetch<LiveBoard>(
      'board_${feed.name}',
      ttl: cacheLifetime,
      forceRefresh: force,
      fetch: () => _download(feed),
      encode: (board) => {
        'source': board.source,
        'note': board.note,
        'games': [for (final game in board.games) game.toJson()],
      },
      decode: (json) {
        final map = jsonMap(json);
        return LiveBoard(
          feed: feed,
          source: jsonString(map['source']) ?? espnProvider,
          note: jsonString(map['note']),
          games: [
            for (final raw in jsonList(map['games']))
              if (LiveGame.fromJson(raw) case final game?) game,
          ],
        );
      },
    );
    return LiveBoard(
      feed: feed,
      games: cached.value.games,
      source: cached.value.source,
      note: cached.value.note,
      fetchedAt: cached.fetchedAt,
      fromCache: cached.fromCache,
    );
  }

  /// Az NBA CDN legutóbbi hibája után ennyi ideig egyből az ESPN-t kérdezzük
  /// (egyes hálózatokról a CDN tartósan HTTP 403-at ad).
  static const nbaCdnBackoff = Duration(minutes: 30);
  static DateTime? _nbaCdnBlockedUntil;

  Future<LiveBoard> _download(LiveFeed feed) async {
    final blockedUntil = _nbaCdnBlockedUntil;
    final cdnBlocked =
        blockedUntil != null && DateTime.now().isBefore(blockedUntil);
    if (feed == LiveFeed.nba && !cdnBlocked) {
      try {
        final payload = await _http.getJson(
          nbaCdnUri,
          provider: nbaCdnProvider,
          headers: const {
            'Accept': 'application/json',
            'Referer': 'https://www.nba.com/',
          },
        );
        return LiveBoard(
          feed: feed,
          games: parseNbaCdnScoreboard(payload),
          source: nbaCdnProvider,
        );
      } catch (error) {
        _nbaCdnBlockedUntil = DateTime.now().add(nbaCdnBackoff);
        final payload = await _http.getJson(
          espnScoreboardUri(feed),
          provider: espnProvider,
        );
        return LiveBoard(
          feed: feed,
          games: parseEspnScoreboard(payload, feed),
          source: espnProvider,
          note:
              'NBA CDN: ${friendlyError(error)} Az ESPN-scoreboard a tartalék.',
        );
      }
    }
    final payload = await _http.getJson(
      espnScoreboardUri(feed),
      provider: espnProvider,
    );
    return LiveBoard(
      feed: feed,
      games: parseEspnScoreboard(payload, feed),
      source: espnProvider,
      note: feed == LiveFeed.nba
          ? 'Az NBA CDN nemrég nem volt elérhető; az ESPN-scoreboard a tartalék.'
          : null,
    );
  }

  /// Tesztekhez: az NBA CDN-tiltás törlése.
  @visibleForTesting
  static void resetNbaCdnBackoff() => _nbaCdnBlockedUntil = null;

  /// A [targets] csapatainak mai mérkőzései (élő, befejezett és még
  /// kezdődő). Soha nem dob: a scoreboardonkénti hiba az eredményben jön.
  Future<LiveScoresResult> forTargets(
    List<UpcomingEventsTarget> targets, {
    bool force = false,
  }) async {
    final byFeed = <LiveFeed, List<UpcomingEventsTarget>>{};
    for (final target in targets) {
      final feed = LiveFeed.forTarget(target);
      final team = target.team.trim();
      if (feed == null ||
          team.isEmpty ||
          team.toLowerCase() == 'nincs megadva') {
        continue;
      }
      byFeed.putIfAbsent(feed, () => []).add(target);
    }
    final games = <AthleteLiveGame>[];
    final sources = <LiveFeed, String>{};
    final errors = <LiveFeed, String>{};
    final notes = <String>[];
    await Future.wait([
      for (final MapEntry(key: feed, value: feedTargets) in byFeed.entries)
        () async {
          try {
            final board = await this.board(feed, force: force);
            sources[feed] = board.source;
            if (board.note != null) notes.add(board.note!);
            for (final target in feedTargets) {
              final team = await _resolveTeam(feed, target.team);
              for (final game in board.games) {
                final side = matchTeamSide(game, feed, target, team);
                if (side == null) continue;
                games.add(
                  AthleteLiveGame(
                    athleteName: target.name,
                    game: game,
                    ownIsHome: side,
                  ),
                );
              }
            }
          } catch (error) {
            errors[feed] = friendlyError(error);
          }
        }(),
    ]);
    games.sort((a, b) {
      int rank(AthleteLiveGame game) => switch (game.game.state) {
        LiveGameState.live => 0,
        LiveGameState.finished => 1,
        LiveGameState.scheduled => 2,
      };
      final byState = rank(a).compareTo(rank(b));
      return byState != 0 ? byState : a.game.start.compareTo(b.game.start);
    });
    return LiveScoresResult(
      games: games,
      sources: sources,
      errors: errors,
      notes: notes,
    );
  }

  Future<EspnTeam?> _resolveTeam(LiveFeed feed, String teamName) async {
    final league = feed.espnLeague;
    if (league == null) return null;
    try {
      return await _schedule.findTeam(league, teamName);
    } catch (_) {
      // Csapatlista nélkül névegyezéssel keresünk.
      return null;
    }
  }

  /// Igaz: a követett csapat hazai, hamis: vendég, `null`: nem az ő meccse.
  static bool? matchTeamSide(
    LiveGame game,
    LiveFeed feed,
    UpcomingEventsTarget target,
    EspnTeam? espnTeam,
  ) {
    bool matches(LiveTeam team) {
      switch (feed) {
        case LiveFeed.soccer:
          return footballTeamNamesMatch(target.team, team.name) ||
              (team.shortName.isNotEmpty &&
                  footballTeamNamesMatch(target.team, team.shortName));
        case LiveFeed.ligaF:
          final key = _womenTeamKey(
            target.team.isEmpty ? 'Barcelona' : target.team,
          );
          final name = _womenTeamKey(team.name);
          return name.isNotEmpty &&
              (name.contains(key) ||
                  key.contains(name) ||
                  (target.isLigaF && name.contains('barcelona')));
        case LiveFeed.nba:
        case LiveFeed.wnba:
        case LiveFeed.nfl:
          if (espnTeam != null) {
            if (game.source == espnProvider &&
                team.id.isNotEmpty &&
                espnTeam.id.isNotEmpty) {
              return team.id == espnTeam.id;
            }
            final expected = normalizeAthleteName(espnTeam.displayName);
            if (normalizeAthleteName(team.name) == expected) return true;
            if (team.abbreviation.isNotEmpty &&
                team.abbreviation.toUpperCase() ==
                    espnTeam.abbreviation.toUpperCase()) {
              return true;
            }
            return team.shortName.isNotEmpty &&
                expected.endsWith(' ${normalizeAthleteName(team.shortName)}');
          }
          final expected = normalizeAthleteName(target.team);
          return normalizeAthleteName(team.name) == expected ||
              (team.shortName.isNotEmpty &&
                  normalizeAthleteName(team.shortName) == expected) ||
              team.abbreviation.toLowerCase() == expected;
      }
    }

    if (matches(game.home)) return true;
    if (matches(game.away)) return false;
    return null;
  }

  // -------------------------------------------------------------------------
  // Feldolgozók
  // -------------------------------------------------------------------------

  /// NBA CDN `todaysScoreboard_00.json`: `scoreboard.games[]`, a
  /// `gameStatus` 1 = kezdés előtt, 2 = zajlik, 3 = vége.
  static List<LiveGame> parseNbaCdnScoreboard(Map<String, dynamic> payload) {
    final games = <LiveGame>[];
    for (final raw in jsonMapList(jsonMap(payload['scoreboard'])['games'])) {
      final id = jsonString(raw['gameId']);
      final start = DateTime.tryParse(jsonString(raw['gameTimeUTC']) ?? '');
      if (id == null || start == null) continue;
      final state = switch (jsonIntOrNull(raw['gameStatus'])) {
        2 => LiveGameState.live,
        3 => LiveGameState.finished,
        _ => LiveGameState.scheduled,
      };
      LiveTeam team(Object? json) {
        final map = jsonMap(json);
        final city = jsonString(map['teamCity']) ?? '';
        final name = jsonString(map['teamName']) ?? '';
        return LiveTeam(
          name: '$city $name'.trim(),
          shortName: name,
          abbreviation: jsonString(map['teamTricode']) ?? '',
          score: state == LiveGameState.scheduled
              ? ''
              : '${jsonIntOrNull(map['score']) ?? jsonString(map['score']) ?? ''}',
          id: jsonString(map['teamId']) ?? '',
        );
      }

      final period = jsonIntOrNull(raw['period']) ?? 0;
      final clock = _isoClock(jsonString(raw['gameClock']) ?? '');
      final statusText = jsonString(raw['gameStatusText']) ?? '';
      games.add(
        LiveGame(
          id: id,
          sport: 'NBA',
          source: nbaCdnProvider,
          state: state,
          home: team(raw['homeTeam']),
          away: team(raw['awayTeam']),
          start: start.toLocal(),
          status: switch (state) {
            LiveGameState.finished => 'Vége',
            LiveGameState.scheduled => 'Kezdés előtt',
            LiveGameState.live =>
              statusText.toLowerCase().contains('half')
                  ? 'Félidő'
                  : basketballPeriodLabel(period, clock),
          },
          url: 'https://www.nba.com/game/$id',
        ),
      );
    }
    games.sort((a, b) => a.start.compareTo(b.start));
    return games;
  }

  /// ESPN `scoreboard` (`events[]`).
  static List<LiveGame> parseEspnScoreboard(
    Map<String, dynamic> payload,
    LiveFeed feed,
  ) {
    final games = <LiveGame>[];
    for (final event in jsonMapList(payload['events'])) {
      final competition = jsonMapList(event['competitions']).firstOrNull;
      if (competition == null) continue;
      final id = jsonString(event['id']) ?? jsonString(competition['id']);
      final start = DateTime.tryParse(
        jsonString(competition['date']) ?? jsonString(event['date']) ?? '',
      );
      if (id == null || start == null) continue;
      final status = jsonMap(competition['status']);
      final type = jsonMap(status['type']);
      final name = jsonString(type['name']) ?? '';
      if (name.contains('CANCELED') || name.contains('POSTPONED')) continue;
      final stateText = jsonString(type['state']) ?? 'pre';
      final state = type['completed'] == true || stateText == 'post'
          ? LiveGameState.finished
          : stateText == 'in'
          ? LiveGameState.live
          : LiveGameState.scheduled;
      final competitors = jsonMapList(competition['competitors']);
      LiveTeam team(String side) {
        final competitor =
            competitors
                .where((c) => jsonString(c['homeAway']) == side)
                .firstOrNull ??
            (side == 'home' ? competitors.firstOrNull : competitors.lastOrNull);
        final raw = jsonMap(competitor?['team']);
        final scoreRaw = competitor?['score'];
        final score = scoreRaw is Map
            ? jsonString(scoreRaw['displayValue']) ?? ''
            : jsonString(scoreRaw) ?? '';
        return LiveTeam(
          name:
              jsonString(raw['displayName']) ??
              jsonString(raw['name']) ??
              'Ismeretlen',
          shortName:
              jsonString(raw['shortDisplayName']) ??
              jsonString(raw['name']) ??
              '',
          abbreviation: jsonString(raw['abbreviation']) ?? '',
          score: state == LiveGameState.scheduled ? '' : score,
          id: jsonString(raw['id']) ?? jsonString(competitor?['id']) ?? '',
        );
      }

      final period = jsonIntOrNull(status['period']) ?? 0;
      final clock = jsonString(status['displayClock']) ?? '';
      final soccer = feed == LiveFeed.soccer || feed == LiveFeed.ligaF;
      String statusLabel() {
        if (state == LiveGameState.finished) return 'Vége';
        if (state == LiveGameState.scheduled) return 'Kezdés előtt';
        if (name.contains('HALFTIME')) return 'Félidő';
        if (soccer) return soccerMinuteLabel(clock);
        return basketballPeriodLabel(
          period,
          clock,
          regulation: 4,
          overtimeLabel: feed == LiveFeed.nfl ? 'hosszabbítás' : null,
        );
      }

      String? url;
      for (final link in jsonMapList(event['links'])) {
        final href = jsonString(link['href']);
        if (href != null && href.startsWith('https://')) {
          url = href;
          break;
        }
      }
      games.add(
        LiveGame(
          id: id,
          sport: feed.sport,
          source: espnProvider,
          state: state,
          home: team('home'),
          away: team('away'),
          start: start.toLocal(),
          status: statusLabel(),
          espnEventId: soccer ? id : null,
          espnLeague: soccer ? feed.espnPath.split('/').last : null,
          url: url,
        ),
      );
    }
    games.sort((a, b) => a.start.compareTo(b.start));
    return games;
  }
}

/// „PT05M32.00S” → „5:32”; értelmezhetetlennél üres.
String _isoClock(String value) {
  final match = RegExp(r'PT(\d+)M(\d+)(?:\.\d+)?S').firstMatch(value);
  if (match == null) return '';
  final minutes = int.parse(match[1]!);
  final seconds = int.parse(match[2]!);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// „3. negyed · 5:32”; a rendes játékidő után „1. hosszabbítás · 2:10”.
String basketballPeriodLabel(
  int period,
  String clock, {
  int regulation = 4,
  String? overtimeLabel,
}) {
  if (period <= 0) return 'Élő';
  final label = period <= regulation
      ? '$period. negyed'
      : overtimeLabel ?? '${period - regulation}. hosszabbítás';
  final time = clock.trim();
  return time.isEmpty || time == '0.0' ? label : '$label · $time';
}

/// „63'” → „63. perc”; „90'+2'” → „90+2. perc”.
String soccerMinuteLabel(String clock) {
  final text = clock.replaceAll("'", '').trim();
  if (text.isEmpty) return 'Élő';
  return '$text. perc';
}

String _womenTeamKey(String value) => normalizeAthleteName(
  value,
).replaceAll('femeni', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
