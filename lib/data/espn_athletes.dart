import 'package:courtboard/data/athlete_names.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/file_util.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/json_util.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

/// Egy ESPN-sportoló a keresőből (`apis/common/v3/search`).
class EspnAthleteRef {
  const EspnAthleteRef({
    required this.id,
    required this.displayName,
    required this.league,
    this.team = '',
    this.teamAbbreviation = '',
    this.position = '',
    this.jersey = '',
  });

  final String id;
  final String displayName;
  final EspnLeague league;
  final String team;
  final String teamAbbreviation;
  final String position;
  final String jersey;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'league': league.name,
    'team': team,
    'teamAbbreviation': teamAbbreviation,
    'position': position,
    'jersey': jersey,
  };

  static EspnAthleteRef? fromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonString(map['id']);
    final league = EspnLeague.values
        .where((value) => value.name == jsonString(map['league']))
        .firstOrNull;
    if (id == null || league == null) return null;
    return EspnAthleteRef(
      id: id,
      displayName: jsonString(map['displayName']) ?? '',
      league: league,
      team: jsonString(map['team']) ?? '',
      teamAbbreviation: jsonString(map['teamAbbreviation']) ?? '',
      position: jsonString(map['position']) ?? '',
      jersey: jsonString(map['jersey']) ?? '',
    );
  }
}

/// A meccsnapló szakasza (az ESPN `seasonTypes[].displayName` alapján).
enum EspnSeasonPhase {
  regular('Alapszakasz'),
  postseason('Rájátszás'),
  preseason('Felkészülés'),
  other('Mérkőzés');

  const EspnSeasonPhase(this.label);
  final String label;

  static EspnSeasonPhase parse(String value) {
    final text = value.toLowerCase();
    if (text.contains('preseason')) return EspnSeasonPhase.preseason;
    if (text.contains('postseason') || text.contains('playoff')) {
      return EspnSeasonPhase.postseason;
    }
    if (text.contains('regular')) return EspnSeasonPhase.regular;
    return EspnSeasonPhase.other;
  }
}

/// Egy mérkőzés a játékos ESPN-meccsnaplójából.
class EspnGameLogEntry {
  const EspnGameLogEntry({
    required this.eventId,
    required this.date,
    required this.opponent,
    required this.stats,
    this.opponentAbbreviation = '',
    this.homeAway,
    this.result = '',
    this.teamScore = '',
    this.opponentScore = '',
    this.phase = EspnSeasonPhase.regular,
    this.note = '',
  });

  final String eventId;

  /// Kezdés helyi időben.
  final DateTime date;
  final String opponent;
  final String opponentAbbreviation;

  /// `home` / `away`, ha ismert.
  final String? homeAway;

  /// `W` / `L` / `T` vagy üres.
  final String result;
  final String teamScore;
  final String opponentScore;
  final EspnSeasonPhase phase;

  /// Például „West 1st Round - Game 6”.
  final String note;

  /// Statisztika-név (`points`, `passingYards`…) → nyers szöveges érték.
  final Map<String, String> stats;

  /// `WIN` / `LOSS` / `DRAW` vagy üres (a [MatchOutcome.parse] érti).
  String get outcome => switch (result.toUpperCase()) {
    'W' => 'WIN',
    'L' => 'LOSS',
    'T' || 'D' => 'DRAW',
    _ => '',
  };

  /// „118–104” (saját pontszám elöl), vagy üres.
  String get score => teamScore.isEmpty || opponentScore.isEmpty
      ? ''
      : '$teamScore–$opponentScore';

  /// Számérték („1,244” és „57.9” is); „11-19” jellegű párnál `null`.
  double? stat(String name) {
    final raw = stats[name]?.replaceAll(',', '').trim();
    if (raw == null || raw.isEmpty || raw == '-' || raw == '--') return null;
    return double.tryParse(raw);
  }

  /// „11-19” → (11, 19); hiányzó vagy hibás értéknél `null`.
  (int, int)? madeAttempted(String name) {
    final parts = stats[name]?.split('-');
    if (parts == null || parts.length != 2) return null;
    final made = int.tryParse(parts[0].trim());
    final attempted = int.tryParse(parts[1].trim());
    return made == null || attempted == null ? null : (made, attempted);
  }

  Map<String, Object?> toJson() => {
    'id': eventId,
    'date': date.toUtc().toIso8601String(),
    'opponent': opponent,
    'opponentAbbreviation': opponentAbbreviation,
    'homeAway': homeAway,
    'result': result,
    'teamScore': teamScore,
    'opponentScore': opponentScore,
    'phase': phase.name,
    'note': note,
    'stats': stats,
  };

  static EspnGameLogEntry? fromJson(Object? json) {
    final map = jsonMap(json);
    final id = jsonString(map['id']);
    final date = DateTime.tryParse(jsonString(map['date']) ?? '');
    if (id == null || date == null) return null;
    return EspnGameLogEntry(
      eventId: id,
      date: date.toLocal(),
      opponent: jsonString(map['opponent']) ?? '',
      opponentAbbreviation: jsonString(map['opponentAbbreviation']) ?? '',
      homeAway: jsonString(map['homeAway']),
      result: jsonString(map['result']) ?? '',
      teamScore: jsonString(map['teamScore']) ?? '',
      opponentScore: jsonString(map['opponentScore']) ?? '',
      phase:
          EspnSeasonPhase.values
              .where((value) => value.name == jsonString(map['phase']))
              .firstOrNull ??
          EspnSeasonPhase.other,
      note: jsonString(map['note']) ?? '',
      stats: {
        for (final MapEntry(:key, :value) in jsonMap(map['stats']).entries)
          key: '$value',
      },
    );
  }
}

/// Egy játékos ESPN-meccsnaplója egy szezonra.
class EspnGameLog {
  const EspnGameLog({
    required this.athlete,
    required this.games,
    this.season = '',
    this.names = const [],
    this.labels = const [],
    this.regularSeasonAverages = const {},
    this.regularSeasonTotals = const {},
    this.fetchedAt,
    this.fromCache = false,
    this.stale = false,
  });

  final EspnAthleteRef athlete;

  /// A mérkőzések (felkészülési meccsek nélkül), a legújabb elöl.
  final List<EspnGameLogEntry> games;

  /// A szezon felirata („2025-26”, „2026”).
  final String season;

  /// A statisztika-oszlopok belső nevei és rövid feliratai.
  final List<String> names;
  final List<String> labels;

  /// Az alapszakasz összesítő sorai (`avg` / `total`), név szerint.
  final Map<String, double> regularSeasonAverages;
  final Map<String, double> regularSeasonTotals;

  final DateTime? fetchedAt;
  final bool fromCache;
  final bool stale;

  /// Az alapszakasz mérkőzései.
  List<EspnGameLogEntry> get regularSeason => [
    for (final game in games)
      if (game.phase == EspnSeasonPhase.regular) game,
  ];

  bool hasStat(String name) => names.contains(name);

  /// Meccsenkénti alapszakasz-átlag: az ESPN `avg` sorából, különben az
  /// összesítő / meccsszám, végül a naplóból számolva.
  double? perGame(String name) {
    final average = regularSeasonAverages[name];
    if (average != null) return average;
    final games = regularSeason.isEmpty ? this.games : regularSeason;
    if (games.isEmpty) return null;
    final total = regularSeasonTotals[name];
    // Arány jellegű oszlop (százalék, rating, átlag): az összesítő sorban
    // is már a szezonérték szerepel.
    if (total != null && _isRatio(name)) return total;
    if (total != null && regularSeason.isNotEmpty) {
      return total / regularSeason.length;
    }
    final values = [for (final game in games) ?game.stat(name)];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static bool _isRatio(String name) =>
      name.endsWith('Pct') ||
      name.contains('Rating') ||
      name.contains('QBR') ||
      name.startsWith('yardsPer') ||
      name.startsWith('long') ||
      name.startsWith('avg');

  /// Alapszakasz-összesítő (a `total` sorból, különben a naplóból).
  double? total(String name) {
    final total = regularSeasonTotals[name];
    if (total != null) return total;
    final values = [for (final game in regularSeason) ?game.stat(name)];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b);
  }

  EspnGameLog withFreshness(CachedValue<Object?> cached) => EspnGameLog(
    athlete: athlete,
    games: games,
    season: season,
    names: names,
    labels: labels,
    regularSeasonAverages: regularSeasonAverages,
    regularSeasonTotals: regularSeasonTotals,
    fetchedAt: cached.fetchedAt,
    fromCache: cached.fromCache,
    stale: cached.stale,
  );

  // -------------------------------------------------------------------------
  // Átalakítás a meglévő modellekre (tartalékforrásként)
  // -------------------------------------------------------------------------

  /// NBA / WNBA meccsek a Basketball Reference modelljében (a legújabb elöl).
  List<NbaGameLog> toNbaGameLogs({int? limit}) {
    final result = <NbaGameLog>[];
    for (final game in games) {
      final fieldGoals = game.madeAttempted(
        'fieldGoalsMade-fieldGoalsAttempted',
      );
      result.add(
        NbaGameLog(
          date: game.date,
          opponent: game.opponent,
          outcome: game.outcome,
          location: game.homeAway == 'away' ? 'AWAY' : 'HOME',
          minutes: game.stat('minutes') ?? 0,
          points: (game.stat('points') ?? 0).round(),
          rebounds: (game.stat('totalRebounds') ?? 0).round(),
          assists: (game.stat('assists') ?? 0).round(),
          steals: (game.stat('steals') ?? 0).round(),
          blocks: (game.stat('blocks') ?? 0).round(),
          turnovers: (game.stat('turnovers') ?? 0).round(),
          fieldGoalsMade: fieldGoals?.$1 ?? 0,
          fieldGoalsAttempted: fieldGoals?.$2 ?? 0,
          score: game.score.isEmpty ? null : game.score,
        ),
      );
      if (limit != null && result.length >= limit) break;
    }
    return result;
  }

  /// WNBA meccsek a wehoop modelljében (a legújabb elöl).
  List<WnbaGameLog> toWnbaGameLogs() => [
    for (final game in games)
      WnbaGameLog(
        gameId: game.eventId,
        athleteId: athlete.id,
        date: game.date,
        team: athlete.team,
        opponent: game.opponent,
        teamScore: int.tryParse(game.teamScore) ?? 0,
        opponentScore: int.tryParse(game.opponentScore) ?? 0,
        result: WnbaResult.fromProvider(game.result),
        points: (game.stat('points') ?? 0).round(),
        rebounds: (game.stat('totalRebounds') ?? 0).round(),
        assists: (game.stat('assists') ?? 0).round(),
        steals: (game.stat('steals') ?? 0).round(),
        blocks: (game.stat('blocks') ?? 0).round(),
        minutes: game.stat('minutes') ?? 0,
        headshotUrl: '',
        turnovers: (game.stat('turnovers') ?? 0).round(),
        fieldGoalsMade:
            game.madeAttempted('fieldGoalsMade-fieldGoalsAttempted')?.$1 ?? 0,
        fieldGoalsAttempted:
            game.madeAttempted('fieldGoalsMade-fieldGoalsAttempted')?.$2 ?? 0,
        seasonType: game.phase == EspnSeasonPhase.postseason
            ? 'postseason'
            : 'regular',
      ),
  ];

  /// Kosárlabda-szezonösszesítő az alapszakasz sorából; `null`, ha nincs
  /// alapszakasz-meccs.
  BasketballSeasonStat? toBasketballSeasonStat() {
    final regular = regularSeason;
    if (regular.isEmpty) return null;
    final stat = BasketballSeasonStat(
      league: athlete.league.label,
      season: season,
      team: athlete.team,
      source: 'ESPN',
      games: regular.length,
      minutesPerGame: perGame('minutes'),
      pointsPerGame: perGame('points'),
      reboundsPerGame: perGame('totalRebounds'),
      assistsPerGame: perGame('assists'),
      stealsPerGame: perGame('steals'),
      turnoversPerGame: perGame('turnovers'),
      fieldGoalPercentage: perGame('fieldGoalPct'),
    );
    return stat.hasUsefulData ? stat : null;
  }

  Map<String, Object?> toJson() => {
    'athlete': athlete.toJson(),
    'season': season,
    'names': names,
    'labels': labels,
    'avg': regularSeasonAverages,
    'total': regularSeasonTotals,
    'games': [for (final game in games) game.toJson()],
  };

  static EspnGameLog fromJson(Object? json) {
    final map = jsonMap(json);
    final athlete = EspnAthleteRef.fromJson(map['athlete']);
    if (athlete == null) throw const FormatException('athlete');
    Map<String, double> numbers(Object? raw) => {
      for (final MapEntry(:key, :value) in jsonMap(raw).entries)
        if (value is num) key: value.toDouble(),
    };
    return EspnGameLog(
      athlete: athlete,
      season: jsonString(map['season']) ?? '',
      names: [for (final name in jsonList(map['names'])) '$name'],
      labels: [for (final label in jsonList(map['labels'])) '$label'],
      regularSeasonAverages: numbers(map['avg']),
      regularSeasonTotals: numbers(map['total']),
      games: [
        for (final raw in jsonList(map['games']))
          if (EspnGameLogEntry.fromJson(raw) case final game?) game,
      ],
    );
  }
}

/// ESPN nyilvános sportolói végpontjai (kulcs nélkül): keresés és
/// meccsnapló NBA-, WNBA- és NFL-játékosokhoz.
///
/// * Keresés: `site.web.api.espn.com/apis/common/v3/search` — a találatot
///   szigorú névegyezéssel ([findAthleteByName]) és a liga szerint szűrjük,
///   soha nem az első találatot adjuk vissza. 7 napig gyorsítótárazva
///   (a sikertelen keresés 24 óráig).
/// * Meccsnapló: `.../apis/common/v3/sports/{sport}/{league}/athletes/{id}/gamelog`
///   — [dataCacheLifetime] (6 óra) lemezes gyorsítótárral; hibánál a régebbi
///   napló jön vissza.
///
/// A kérések a közös „ESPN” keretből (percenként 30) fogynak.
class EspnAthleteRepository {
  EspnAthleteRepository({HttpService? http, this._cacheStorage})
    : _http = http ?? HttpService.shared;

  final HttpService _http;
  final CacheStorage? _cacheStorage;

  static const provider = 'ESPN';
  static const searchCacheLifetime = Duration(days: 7);
  static const missCacheLifetime = Duration(hours: 24);
  static const dataCacheLifetime = Duration(hours: 6);

  JsonFileCache get _cache =>
      JsonFileCache('espn_athletes', storage: _cacheStorage);

  static Uri searchUri(String name) => Uri.https(
    'site.web.api.espn.com',
    '/apis/common/v3/search',
    {'query': name, 'limit': '10', 'type': 'player'},
  );

  static Uri gameLogUri(EspnLeague league, String athleteId) => Uri.https(
    'site.web.api.espn.com',
    '/apis/common/v3/sports/${league.sport}/${league.league}/athletes/$athleteId/gamelog',
  );

  /// A névhez és ligához illő ESPN-sportoló, vagy `null`.
  Future<EspnAthleteRef?> findAthlete(
    String name,
    EspnLeague league, {
    bool forceRefresh = false,
  }) async => (await _cache.getOrFetch<EspnAthleteRef?>(
    'search_${league.league}_${cacheSlug(name)}',
    ttl: searchCacheLifetime,
    missTtl: missCacheLifetime,
    forceRefresh: forceRefresh,
    fetch: () async => parseSearch(
      await _http.getJson(searchUri(name), provider: provider),
      name,
      league,
    ),
    encode: (value) => value?.toJson(),
    decode: (json) => json == null ? null : EspnAthleteRef.fromJson(json),
  )).value;

  /// A játékos meccsnaplója; `null`, ha az ESPN nem ismeri a játékost.
  Future<EspnGameLog?> gameLog(
    String name,
    EspnLeague league, {
    bool forceRefresh = false,
  }) async {
    final athlete = await findAthlete(name, league);
    if (athlete == null) return null;
    final cached = await _cache.getOrFetch<EspnGameLog>(
      'gamelog_${league.league}_${athlete.id}',
      ttl: dataCacheLifetime,
      forceRefresh: forceRefresh,
      fetch: () async => parseGameLog(
        await _http.getJson(gameLogUri(league, athlete.id), provider: provider),
        athlete,
      ),
      encode: (value) => value.toJson(),
      decode: EspnGameLog.fromJson,
    );
    return cached.value.withFreshness(cached);
  }

  /// A keresőválasz (`items[]`) közül a ligához és a névhez illő játékos.
  static EspnAthleteRef? parseSearch(
    Map<String, dynamic> payload,
    String name,
    EspnLeague league,
  ) {
    final candidates = [
      for (final item in jsonMapList(payload['items']))
        if ((jsonString(item['type']) ?? 'player') == 'player' &&
            jsonString(item['sport']) == league.sport &&
            jsonString(item['league']) == league.league &&
            jsonString(item['id']) != null)
          item,
    ];
    final match = findAthleteByName(
      candidates,
      name,
      (item) => jsonString(item['displayName']) ?? '',
    );
    if (match == null) return null;
    final team = jsonMapList(match['teamRelationships']).firstOrNull;
    return EspnAthleteRef(
      id: jsonString(match['id'])!,
      displayName: jsonString(match['displayName']) ?? name,
      league: league,
      team: jsonString(team?['displayName']) ?? '',
      teamAbbreviation:
          jsonString(jsonMap(team?['core'])['abbreviation']) ?? '',
      position: switch (match['position']) {
        final Map<String, dynamic> position =>
          jsonString(position['abbreviation']) ??
              jsonString(position['displayName']) ??
              '',
        final Object? other => other is String ? other : '',
      },
      jersey: jsonString(match['jersey']) ?? '',
    );
  }

  /// Az ESPN `gamelog` válasza: a `seasonTypes[].categories[].events[]`
  /// sorai a felső szintű `names` oszlopai szerint, a meccsadatok az
  /// `events` térképből. A felkészülési meccsek kimaradnak.
  static EspnGameLog parseGameLog(
    Map<String, dynamic> payload,
    EspnAthleteRef athlete,
  ) {
    final names = [for (final name in jsonList(payload['names'])) '$name'];
    final labels = [for (final label in jsonList(payload['labels'])) '$label'];
    final events = jsonMap(payload['events']);
    final games = <EspnGameLogEntry>[];
    final seen = <String>{};
    final averages = <String, double>{};
    final totals = <String, double>{};
    var season = '';

    Map<String, double> row(List<Object?> values) => {
      for (var i = 0; i < values.length && i < names.length; i++)
        if (double.tryParse('${values[i]}'.replaceAll(',', '')) case final v?)
          names[i]: v,
    };

    for (final seasonType in jsonMapList(payload['seasonTypes'])) {
      final title = jsonString(seasonType['displayName']) ?? '';
      final phase = EspnSeasonPhase.parse(title);
      if (season.isEmpty) {
        season = title.split(' ').first;
      }
      if (phase == EspnSeasonPhase.regular) {
        for (final summary in jsonMapList(
          jsonMap(seasonType['summary'])['stats'],
        )) {
          final type = jsonString(summary['type']);
          final values = jsonList(summary['stats']);
          if (type == 'avg') averages.addAll(row(values));
          if (type == 'total') totals.addAll(row(values));
        }
      }
      if (phase == EspnSeasonPhase.preseason) continue;
      for (final category in jsonMapList(seasonType['categories'])) {
        for (final line in jsonMapList(category['events'])) {
          final id = jsonString(line['eventId']);
          if (id == null || !seen.add(id)) continue;
          final event = jsonMap(events[id]);
          final date = DateTime.tryParse(jsonString(event['gameDate']) ?? '');
          if (date == null) continue;
          final values = jsonList(line['stats']);
          final away = jsonString(event['atVs']) == '@';
          final homeScore = jsonString(event['homeTeamScore']) ?? '';
          final awayScore = jsonString(event['awayTeamScore']) ?? '';
          final opponent = jsonMap(event['opponent']);
          games.add(
            EspnGameLogEntry(
              eventId: id,
              date: date.toLocal(),
              opponent:
                  jsonString(opponent['displayName']) ??
                  jsonString(opponent['abbreviation']) ??
                  '',
              opponentAbbreviation: jsonString(opponent['abbreviation']) ?? '',
              homeAway: away ? 'away' : 'home',
              result: jsonString(event['gameResult']) ?? '',
              teamScore: away ? awayScore : homeScore,
              opponentScore: away ? homeScore : awayScore,
              phase: phase,
              note: jsonString(event['eventNote']) ?? '',
              stats: {
                for (var i = 0; i < values.length && i < names.length; i++)
                  names[i]: '${values[i]}',
              },
            ),
          );
        }
      }
    }
    games.sort((a, b) => b.date.compareTo(a.date));
    // A játékos aktuális csapata a legfrissebb meccsből, ha a keresés nem adta.
    final teamFromLog = games.isEmpty
        ? null
        : jsonString(
            jsonMap(
              jsonMap(events[games.first.eventId])['team'],
            )['displayName'],
          );
    return EspnGameLog(
      athlete: athlete.team.isNotEmpty || teamFromLog == null
          ? athlete
          : EspnAthleteRef(
              id: athlete.id,
              displayName: athlete.displayName,
              league: athlete.league,
              team: teamFromLog,
              teamAbbreviation: athlete.teamAbbreviation,
              position: athlete.position,
              jersey: athlete.jersey,
            ),
      games: games,
      season: season,
      names: names,
      labels: labels,
      regularSeasonAverages: averages,
      regularSeasonTotals: totals,
    );
  }
}

// ---------------------------------------------------------------------------
// NFL: szerepkör szerinti fő mutató
// ---------------------------------------------------------------------------

/// Az NFL-játékos meccsenkénti fő mutatója a szerepköre szerint.
enum NflFormStat {
  passingYards('passingYards', 'passzolt yard', 'PASSZ YD'),
  rushingYards('rushingYards', 'futott yard', 'FUTÁS YD'),
  receivingYards('receivingYards', 'elkapott yard', 'ELKAPÁS YD'),
  tackles('totalTackles', 'szerelés', 'SZERELÉS');

  const NflFormStat(this.statName, this.unit, this.code);
  final String statName;
  final String unit;
  final String code;

  /// A pozícióhoz illő mutató, ha a napló tartalmazza; különben az első
  /// elérhető.
  static NflFormStat? pick(EspnGameLog log) {
    final position = log.athlete.position.toUpperCase();
    final preferred = switch (position) {
      'QB' => NflFormStat.passingYards,
      'RB' || 'FB' => NflFormStat.rushingYards,
      'WR' || 'TE' => NflFormStat.receivingYards,
      _ => null,
    };
    if (preferred != null && log.hasStat(preferred.statName)) return preferred;
    for (final stat in NflFormStat.values) {
      if (log.hasStat(stat.statName)) return stat;
    }
    return null;
  }
}

/// Az NFL-szezonösszesítő sorai a naplóban szereplő kategóriák szerint:
/// (felirat, érték-szöveg) párok; hiányzó kategória nem kerül bele.
List<(String, double?, int)> nflSeasonLines(EspnGameLog log) => [
  (
    'MÉRKŐZÉS',
    log.regularSeason.isEmpty
        ? log.games.length.toDouble()
        : log.regularSeason.length.toDouble(),
    0,
  ),
  if (log.hasStat('passingYards')) ...[
    ('PASSZOLT YARD', log.total('passingYards'), 0),
    ('PASSZ TD', log.total('passingTouchdowns'), 0),
    ('INTERCEPTION', log.total('interceptions'), 0),
    ('PASSZ%', log.perGame('completionPct'), 1),
    ('QB RATING', log.perGame('QBRating'), 1),
  ],
  if (log.hasStat('rushingYards')) ...[
    ('FUTOTT YARD', log.total('rushingYards'), 0),
    ('FUTÓ TD', log.total('rushingTouchdowns'), 0),
  ],
  if (log.hasStat('receivingYards')) ...[
    ('ELKAPÁS', log.total('receptions'), 0),
    ('ELKAPOTT YARD', log.total('receivingYards'), 0),
    ('ELKAPÓ TD', log.total('receivingTouchdowns'), 0),
  ],
  if (log.hasStat('totalTackles')) ...[
    ('SZERELÉS', log.total('totalTackles'), 0),
    ('SACK', log.total('sacks'), 1),
  ],
];

/// Rövid meccsenkénti összegzés NFL-hez („21/31 · 245 YD · 2 TD · 1 INT”).
/// Ha a passzolt touchdownok külön látszanak (a sor pontszerzés-jelölése
/// mellett), [includePassingTouchdowns] hamis.
String nflGameSummary(
  EspnGameLogEntry game, {
  bool includePassingTouchdowns = true,
}) {
  String n(String name) => (game.stat(name) ?? 0).round().toString();
  final parts = <String>[];
  if (game.stats.containsKey('passingYards')) {
    parts.add(
      '${n('completions')}/${n('passingAttempts')} · ${n('passingYards')} passz yd',
    );
    if (includePassingTouchdowns && (game.stat('passingTouchdowns') ?? 0) > 0) {
      parts.add('${n('passingTouchdowns')} TD');
    }
    if ((game.stat('interceptions') ?? 0) > 0) {
      parts.add('${n('interceptions')} INT');
    }
  }
  if (game.stats.containsKey('rushingYards') &&
      (game.stat('rushingAttempts') ?? 0) > 0) {
    parts.add('${n('rushingAttempts')} futás · ${n('rushingYards')} yd');
  }
  if (game.stats.containsKey('receivingYards') &&
      (game.stat('receptions') ?? 0) > 0) {
    parts.add('${n('receptions')} elkapás · ${n('receivingYards')} yd');
  }
  if (game.stats.containsKey('totalTackles')) {
    parts.add('${n('totalTackles')} szerelés');
  }
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Tartalék-láncok (Basketball Reference / wehoop → ESPN)
// ---------------------------------------------------------------------------

/// NBA-szezonösszesítő: a Basketball Reference-é, ha az nem érhető el vagy
/// nem ad sort, az ESPN meccsnaplójából számolt alapszakasz-összesítő.
Future<CachedValue<BasketballSeasonStat>?> nbaSeasonSummaryWithFallback(
  String athleteName, {
  bool forceRefresh = false,
  BasketballReferenceRepository? reference,
  EspnAthleteRepository? espn,
}) async {
  Object? referenceError;
  StackTrace? referenceStack;
  try {
    final cached = await (reference ?? BasketballReferenceRepository())
        .seasonSummaryCached(athleteName, forceRefresh: forceRefresh);
    if (cached != null) return cached;
  } catch (error, stack) {
    referenceError = error;
    referenceStack = stack;
  }
  try {
    final log = await (espn ?? EspnAthleteRepository()).gameLog(
      athleteName,
      EspnLeague.nba,
      forceRefresh: forceRefresh,
    );
    final stat = log?.toBasketballSeasonStat();
    if (stat != null) {
      return CachedValue(
        stat,
        fetchedAt: log!.fetchedAt ?? DateTime.now(),
        fromCache: log.fromCache,
        stale: log.stale,
      );
    }
  } catch (_) {
    // Ha a tartalék is hibázik, az elsődleges forrás hibája a beszédesebb.
  }
  if (referenceError != null) {
    Error.throwWithStackTrace(referenceError, referenceStack!);
  }
  return null;
}

/// WNBA-meccsnapló a forrásával.
class WnbaGamesResult {
  const WnbaGamesResult(this.games, {required this.source, this.note});
  final List<WnbaGameLog> games;

  /// `SportsDataverse / wehoop` vagy `ESPN`.
  final String source;

  /// Például: a wehoop hibája, ami miatt a tartalék látszik.
  final String? note;
}

/// WNBA-meccsnapló: a wehoop szezonfájlja, ha az nem érhető el vagy üres,
/// az ESPN játékos-meccsnaplója.
Future<WnbaGamesResult> wnbaGamesWithFallback(
  String athleteName, {
  WnbaWehoopRepository? wehoop,
  EspnAthleteRepository? espn,
  bool forceRefresh = false,
}) async {
  Object? wehoopError;
  StackTrace? wehoopStack;
  try {
    final games = await (wehoop ?? WnbaWehoopRepository.shared).recentGames(
      athleteName,
    );
    if (games.isNotEmpty) {
      return WnbaGamesResult(games, source: 'SportsDataverse / wehoop');
    }
  } catch (error, stack) {
    wehoopError = error;
    wehoopStack = stack;
  }
  try {
    final log = await (espn ?? EspnAthleteRepository()).gameLog(
      athleteName,
      EspnLeague.wnba,
      forceRefresh: forceRefresh,
    );
    final games = log?.toWnbaGameLogs() ?? const <WnbaGameLog>[];
    if (games.isNotEmpty) {
      return WnbaGamesResult(
        games,
        source: 'ESPN',
        note: wehoopError == null
            ? 'A wehoop szezonfájljában nincs ilyen játékos; az ESPN meccsnaplója látszik.'
            : 'A wehoop most nem érhető el; az ESPN meccsnaplója látszik.',
      );
    }
  } catch (_) {
    // A wehoop hibája a beszédesebb, ha az is volt.
  }
  if (wehoopError != null) {
    Error.throwWithStackTrace(wehoopError, wehoopStack!);
  }
  return const WnbaGamesResult([], source: 'SportsDataverse / wehoop');
}
