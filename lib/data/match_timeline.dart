import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';

/// Egy idővonal-esemény típusa.
enum TimelineEventType {
  goal,
  penaltyGoal,
  ownGoal,
  yellowCard,
  redCard,
  substitution,
  other;

  bool get isGoal =>
      this == TimelineEventType.goal ||
      this == TimelineEventType.penaltyGoal ||
      this == TimelineEventType.ownGoal;

  /// Magyar felirat a képernyőolvasónak és a jelmagyarázathoz.
  String get label => switch (this) {
    TimelineEventType.goal => 'Gól',
    TimelineEventType.penaltyGoal => 'Gól (büntetőből)',
    TimelineEventType.ownGoal => 'Öngól',
    TimelineEventType.yellowCard => 'Sárga lap',
    TimelineEventType.redCard => 'Piros lap',
    TimelineEventType.substitution => 'Csere',
    TimelineEventType.other => 'Esemény',
  };
}

/// Egy mérkőzésesemény (gól, lap, csere) perccel.
class TimelineEvent {
  const TimelineEvent({
    required this.type,
    required this.minute,
    required this.sortKey,
    this.player = '',
    this.secondaryPlayer = '',
    this.team = '',
    this.home,
    this.score = '',
    this.assist = '',
  });

  final TimelineEventType type;

  /// Megjelenített perc („63'”, „90+1'”).
  final String minute;

  /// Rendezési kulcs (másodperc vagy perc).
  final double sortKey;

  /// Gólszerző / lapot kapó / beálló játékos.
  final String player;

  /// Cserénél a lecserélt játékos.
  final String secondaryPlayer;
  final String team;

  /// Igaz: hazai csapat eseménye, hamis: vendég, `null`: ismeretlen.
  final bool? home;

  /// Gólnál az állás a gól után („2–1”), ha a forrás adja.
  final String score;

  /// Gólnál a gólpasszt adó játékos, ha a forrás adja (öngólnál soha).
  final String assist;

  /// Ugyanez az esemény a gól utáni állással.
  TimelineEvent withScore(String value) => TimelineEvent(
    type: type,
    minute: minute,
    sortKey: sortKey,
    player: player,
    secondaryPlayer: secondaryPlayer,
    team: team,
    home: home,
    score: value,
    assist: assist,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'minute': minute,
    'sort': sortKey,
    'player': player,
    'secondary': secondaryPlayer,
    'team': team,
    'home': home,
    'score': score,
    if (assist.isNotEmpty) 'assist': assist,
  };

  static TimelineEvent? fromJson(Object? json) {
    final map = jsonMap(json);
    final type = TimelineEventType.values
        .where((value) => value.name == jsonString(map['type']))
        .firstOrNull;
    if (type == null) return null;
    final home = map['home'];
    return TimelineEvent(
      type: type,
      minute: jsonString(map['minute']) ?? '',
      sortKey: jsonDoubleOrNull(map['sort']) ?? 0,
      player: jsonString(map['player']) ?? '',
      secondaryPlayer: jsonString(map['secondary']) ?? '',
      team: jsonString(map['team']) ?? '',
      home: home is bool ? home : null,
      score: jsonString(map['score']) ?? '',
      assist: jsonString(map['assist']) ?? '',
    );
  }
}

/// Egy játékos meccsstatisztikája az ESPN-összefoglaló `rosters` részéből:
/// saját gólok (öngól nélkül), gólpasszok és öngólok.
class MatchPlayerStats {
  const MatchPlayerStats({
    required this.name,
    this.home,
    this.goals = 0,
    this.assists = 0,
    this.ownGoals = 0,
  });

  final String name;

  /// Igaz: hazai csapat játékosa, hamis: vendég, `null`: ismeretlen.
  final bool? home;
  final int goals;
  final int assists;
  final int ownGoals;

  Map<String, Object?> toJson() => {
    'name': name,
    'home': home,
    'goals': goals,
    'assists': assists,
    'ownGoals': ownGoals,
  };

  static MatchPlayerStats? fromJson(Object? json) {
    final map = jsonMap(json);
    final name = jsonString(map['name']);
    if (name == null || name.isEmpty) return null;
    final home = map['home'];
    return MatchPlayerStats(
      name: name,
      home: home is bool ? home : null,
      goals: jsonIntOrNull(map['goals']) ?? 0,
      assists: jsonIntOrNull(map['assists']) ?? 0,
      ownGoals: jsonIntOrNull(map['ownGoals']) ?? 0,
    );
  }
}

/// Egy mérkőzés idővonala.
class MatchTimeline {
  const MatchTimeline({
    required this.events,
    this.home = '',
    this.away = '',
    this.homeScore = '',
    this.awayScore = '',
    this.finished = false,
    this.status = '',
    this.source = 'ESPN',
    this.players = const [],
    this.hasPlayerStats = false,
  });

  /// Időrendben.
  final List<TimelineEvent> events;
  final String home;
  final String away;
  final String homeScore;
  final String awayScore;

  /// Igaz, ha a mérkőzés véget ért (a gyorsítótár ekkor végleges).
  final bool finished;
  final String status;
  final String source;

  /// A gólt, gólpasszt vagy öngólt szerző játékosok meccsstatisztikája
  /// (az ESPN `rosters` részéből); a többiek nem kerülnek bele.
  final List<MatchPlayerStats> players;

  /// Igaz, ha a forrás teljes játékoskeretet adott statisztikával: ekkor a
  /// [players]-ben nem szereplő játékos biztosan nem szerzett gólt/gólpasszt.
  final bool hasPlayerStats;

  Map<String, Object?> toJson() => {
    'home': home,
    'away': away,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'finished': finished,
    'status': status,
    'source': source,
    'events': [for (final event in events) event.toJson()],
    if (hasPlayerStats) 'hasPlayerStats': true,
    if (players.isNotEmpty)
      'players': [for (final player in players) player.toJson()],
  };

  static MatchTimeline fromJson(Object? json) {
    final map = jsonMap(json);
    if (map['events'] is! List) throw const FormatException('events');
    return MatchTimeline(
      home: jsonString(map['home']) ?? '',
      away: jsonString(map['away']) ?? '',
      homeScore: jsonString(map['homeScore']) ?? '',
      awayScore: jsonString(map['awayScore']) ?? '',
      finished: map['finished'] == true,
      status: jsonString(map['status']) ?? '',
      source: jsonString(map['source']) ?? 'ESPN',
      events: [
        for (final raw in jsonList(map['events']))
          if (TimelineEvent.fromJson(raw) case final event?) event,
      ],
      hasPlayerStats: map['hasPlayerStats'] == true,
      players: [
        for (final raw in jsonList(map['players']))
          if (MatchPlayerStats.fromJson(raw) case final player?) player,
      ],
    );
  }
}

/// Egy ESPN-mérkőzés azonosítója az összefoglalóhoz.
class EspnMatchRef {
  const EspnMatchRef({required this.eventId, this.league = 'all'});

  final String eventId;

  /// ESPN foci-ligakód (`esp.w.1`, `eng.1`); ismeretlennél `all`.
  final String league;

  @override
  bool operator ==(Object other) =>
      other is EspnMatchRef &&
      other.eventId == eventId &&
      other.league == league;

  @override
  int get hashCode => Object.hash(eventId, league);
}

/// ESPN foci-mérkőzésösszefoglaló (`site/v2/sports/soccer/{liga}/summary`)
/// idővonala: gólok, lapok és cserék perccel.
///
/// A befejezett mérkőzés idővonala végleges, ezért „örökre” (10 évig) a
/// gyorsítótárban marad; a még zajló meccsé csak [liveCacheLifetime] (60 mp)
/// ideig.
class MatchTimelineRepository {
  MatchTimelineRepository({HttpService? http, this._cacheStorage, this._clock})
    : _http = http ?? HttpService.shared;

  final HttpService _http;
  final CacheStorage? _cacheStorage;
  final DateTime Function()? _clock;

  static const provider = 'ESPN';
  static const liveCacheLifetime = Duration(seconds: 60);
  static const finalCacheLifetime = Duration(days: 3650);

  JsonFileCache get _cache =>
      JsonFileCache('match_timeline', storage: _cacheStorage, clock: _clock);

  static Uri summaryUri(EspnMatchRef match) => Uri.https(
    'site.api.espn.com',
    '/apis/site/v2/sports/soccer/${match.league}/summary',
    {'event': match.eventId},
  );

  Future<MatchTimeline> timeline(
    EspnMatchRef match, {
    bool forceRefresh = false,
  }) async => (await _cache.getOrFetch<MatchTimeline>(
    // `v2`: 0.16.0 óta a gólpassz és a játékosstatisztika is benne van (a
    // régi, végleges bejegyzésekből ez hiányozna).
    'summary_v2_${match.league}_${match.eventId}',
    ttl: finalCacheLifetime,
    // A nem befejezett meccs „hiányként” csak 60 mp-ig érvényes.
    isMiss: (value) => !value.finished,
    missTtl: liveCacheLifetime,
    forceRefresh: forceRefresh,
    fetch: () async => parseEspnSummary(
      await _http.getJson(summaryUri(match), provider: provider),
    ),
    encode: (value) => value.toJson(),
    decode: MatchTimeline.fromJson,
  )).value;

  /// Az ESPN `summary` válasza: a `keyEvents[]` (tartalékként a
  /// `header.competitions[0].details[]`) gól-, lap- és cseresorai. A gólnál
  /// a résztvevők sorrendje: gólszerző, gólpasszt adó. A `rosters[]`
  /// játékosstatisztikájából (`totalGoals`, `goalAssists`, `ownGoals`) a
  /// pontot szerző játékosok kerülnek a [MatchTimeline.players]-be.
  static MatchTimeline parseEspnSummary(Map<String, dynamic> payload) {
    final competition = jsonMapList(
      jsonMap(payload['header'])['competitions'],
    ).firstOrNull;
    final competitors = jsonMapList(competition?['competitors']);
    Map<String, dynamic>? side(String homeAway) => competitors
        .where((c) => jsonString(c['homeAway']) == homeAway)
        .firstOrNull;
    final home = side('home');
    final away = side('away');
    String teamName(Map<String, dynamic>? competitor) =>
        jsonString(jsonMap(competitor?['team'])['displayName']) ?? '';
    String teamId(Map<String, dynamic>? competitor) =>
        jsonString(jsonMap(competitor?['team'])['id']) ??
        jsonString(competitor?['id']) ??
        '';
    final homeId = teamId(home);
    final awayId = teamId(away);
    final statusType = jsonMap(jsonMap(competition?['status'])['type']);
    final finished =
        statusType['completed'] == true ||
        jsonString(statusType['state']) == 'post';

    final keyEvents = jsonMapList(payload['keyEvents']);
    final source = keyEvents.isNotEmpty
        ? keyEvents
        : jsonMapList(competition?['details']);
    final events = <TimelineEvent>[];
    for (final raw in source) {
      final typeInfo = jsonMap(raw['type']);
      final typeKey =
          '${jsonString(typeInfo['type']) ?? ''} '
                  '${jsonString(typeInfo['text']) ?? ''}'
              .toLowerCase();
      TimelineEventType? type;
      if (raw['ownGoal'] == true ||
          typeKey.contains('own goal') ||
          typeKey.contains('own-goal')) {
        type = TimelineEventType.ownGoal;
      } else if (typeKey.contains('penalty') &&
          (raw['scoringPlay'] == true || typeKey.contains('goal')) &&
          !typeKey.contains('miss') &&
          !typeKey.contains('saved')) {
        type = TimelineEventType.penaltyGoal;
      } else if (raw['scoringPlay'] == true || typeKey.contains('goal')) {
        type = TimelineEventType.goal;
      } else if (raw['redCard'] == true || typeKey.contains('red')) {
        type = TimelineEventType.redCard;
      } else if (raw['yellowCard'] == true || typeKey.contains('yellow')) {
        type = TimelineEventType.yellowCard;
      } else if (typeKey.contains('substitution')) {
        type = TimelineEventType.substitution;
      }
      // Kezdő / félidő / vége jelzések és egyéb sorok kimaradnak.
      if (type == null) continue;
      if (type.isGoal &&
          raw['penaltyKick'] == true &&
          type != TimelineEventType.ownGoal) {
        type = TimelineEventType.penaltyGoal;
      }
      final clock = jsonMap(raw['clock']);
      final minute = jsonString(clock['displayValue']) ?? '';
      final seconds = jsonDoubleOrNull(clock['value']);
      final participants = [
        for (final participant in jsonMapList(raw['participants']))
          jsonString(jsonMap(participant['athlete'])['displayName']) ?? '',
      ].where((name) => name.isNotEmpty).toList();
      final team = jsonMap(raw['team']);
      final id = jsonString(team['id']);
      events.add(
        TimelineEvent(
          type: type,
          minute: minute,
          sortKey: seconds ?? _minuteValue(minute) * 60,
          player: participants.firstOrNull ?? '',
          secondaryPlayer: type == TimelineEventType.substitution
              ? participants.skip(1).firstOrNull ?? ''
              : '',
          assist: type.isGoal && type != TimelineEventType.ownGoal
              ? participants.skip(1).firstOrNull ?? ''
              : '',
          team: jsonString(team['displayName']) ?? '',
          home: id == null
              ? null
              : id == homeId
              ? true
              : id == awayId
              ? false
              : null,
        ),
      );
    }
    events.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    // Állás a gólok után (öngól a másik csapatnak számít: az ESPN a
    // javára írt csapatot adja meg a `team` mezőben).
    var homeGoals = 0;
    var awayGoals = 0;
    final withScore = [
      for (final event in events)
        if (event.type.isGoal && event.home != null)
          () {
            if (event.home!) {
              homeGoals++;
            } else {
              awayGoals++;
            }
            return event.withScore('$homeGoals–$awayGoals');
          }()
        else
          event,
    ];
    String score(Map<String, dynamic>? competitor) {
      final raw = competitor?['score'];
      if (raw is Map) return jsonString(raw['displayValue']) ?? '';
      return jsonString(raw) ?? '';
    }

    final (players, hasPlayerStats) = _parseRosters(
      jsonMapList(payload['rosters']),
      homeId: homeId,
      awayId: awayId,
    );
    return MatchTimeline(
      events: withScore,
      home: teamName(home),
      away: teamName(away),
      homeScore: score(home),
      awayScore: score(away),
      finished: finished,
      status: jsonString(statusType['shortDetail']) ?? '',
      players: players,
      hasPlayerStats: hasPlayerStats,
    );
  }

  /// A `rosters[].roster[]` sorai közül azok, akik gólt, gólpasszt vagy
  /// öngólt szereztek; a második érték igaz, ha a keret statisztikával
  /// érkezett (legalább egy sorban van `totalGoals` vagy `goalAssists`).
  static (List<MatchPlayerStats>, bool) _parseRosters(
    List<Map<String, dynamic>> rosters, {
    required String homeId,
    required String awayId,
  }) {
    final players = <MatchPlayerStats>[];
    var hasStats = false;
    for (final roster in rosters) {
      final side = jsonString(roster['homeAway']);
      final teamId = jsonString(jsonMap(roster['team'])['id']);
      final bool? home = switch (side) {
        'home' => true,
        'away' => false,
        _ =>
          teamId == null || teamId.isEmpty
              ? null
              : teamId == homeId
              ? true
              : teamId == awayId
              ? false
              : null,
      };
      for (final entry in jsonMapList(roster['roster'])) {
        final athlete = jsonMap(entry['athlete']);
        final name =
            jsonString(athlete['displayName']) ??
            jsonString(athlete['fullName']) ??
            '';
        final stats = <String, int>{
          for (final stat in jsonMapList(entry['stats']))
            if (jsonString(stat['name']) case final key?)
              key: (jsonDoubleOrNull(stat['value']) ?? 0).round(),
        };
        if (stats.containsKey('totalGoals') ||
            stats.containsKey('goalAssists')) {
          hasStats = true;
        }
        final goals = stats['totalGoals'] ?? 0;
        final assists = stats['goalAssists'] ?? 0;
        final ownGoals = stats['ownGoals'] ?? 0;
        if (name.isEmpty || goals + assists + ownGoals == 0) continue;
        players.add(
          MatchPlayerStats(
            name: name,
            home: home,
            goals: goals,
            assists: assists,
            ownGoals: ownGoals,
          ),
        );
      }
    }
    return (players, hasStats);
  }
}

/// „90'+1'” → 90.1, „63'” → 63.
double _minuteValue(String minute) {
  final parts = RegExp(r'\d+').allMatches(minute).map((m) => m[0]!).toList();
  if (parts.isEmpty) return 0;
  final base = double.parse(parts.first);
  return parts.length > 1 ? base + double.parse(parts[1]) / 100 : base;
}
