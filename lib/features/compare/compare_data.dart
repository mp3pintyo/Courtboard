/// Két azonos sportágú sportoló szezonösszesítőjének összehasonlítása:
/// mérőszám-definíciók, normalizálás a radardiagramhoz, „jobb érték”
/// döntés és a meglévő repositorykra épülő adatforrás.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/football_season.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/shared/format.dart';

/// Egy összehasonlítható mérőszám.
///
/// A normalizálás a [min]–[max] tartomány szerint történik (0–1 közé
/// szorítva); a határok ligánkénti *referencia-értékek*: nagyjából egy
/// kiemelkedő szezon szintje, nem rekordok. Így a radar a sportolót a
/// ligához méri, nem csak a másik sportolóhoz. A [higherIsBetter] hamis a
/// „kevesebb a jobb” mutatóknál (eladott labda, lapok, ranglista-helyezés):
/// ilyenkor a normalizált érték is fordított (1 = legjobb).
class CompareMetric {
  const CompareMetric({
    required this.id,
    required this.label,
    required this.max,
    this.shortLabel,
    this.min = 0,
    this.higherIsBetter = true,
    this.digits = 1,
    this.percent = false,
    this.radar = true,
  });

  final String id;
  final String label;

  /// Rövid felirat a radar tengelyéhez; alapból a [label].
  final String? shortLabel;
  final double min;
  final double max;
  final bool higherIsBetter;
  final int digits;
  final bool percent;

  /// Szerepel-e a radardiagramon (a meccsszám például nem).
  final bool radar;

  String get axisLabel => shortLabel ?? label;

  String format(double? value) => value == null
      ? '—'
      : percent
      ? formatPercent(value, digits: digits)
      : digits == 0
      ? formatInt(value)
      : formatDecimal(value, digits: digits);
}

/// A sportágak összehasonlítható mérőszámai és referencia-tartományai.
///
/// * **NBA**: 35 pont, 15 lepattanó, 12 assziszt, 2,5 labdaszerzés,
///   0–5 eladott labda (fordított), 30–70% mezőnyszázalék, 40 perc, 82 meccs.
/// * **WNBA**: 28 pont, 12 lepattanó, 9 assziszt, 2,5 labdaszerzés,
///   0–5 eladott labda, 30–65% mezőnyszázalék, 38 perc, 44 meccs.
/// * **Foci**: 6,0–8,5 értékelés, 38 meccs, 30 gól, 15 gólpassz,
///   0–12 sárga lap (fordított).
/// * **Tenisz**: 1–200. hely (fordított), 12 000 ranglistapont.
/// * **NFL** (ESPN-meccsnapló, meccsenként): 320 passzolt, 110 futott és
///   110 elkapott yard, 3 touchdown, 0–1,5 interception (fordított),
///   10 szerelés, 17 meccs. Csak a mindkét játékosnál létező mutató kerül
///   a radarra (egy irányító és egy elkapó így is összevethető).
///
/// A darts nincs benne: ahhoz nincs szezonösszesítő forrás.
abstract final class CompareMetrics {
  static const nba = [
    CompareMetric(
      id: 'games',
      label: 'Mérkőzés',
      max: 82,
      digits: 0,
      radar: false,
    ),
    CompareMetric(
      id: 'minutes',
      label: 'Perc / meccs',
      shortLabel: 'PERC',
      max: 40,
    ),
    CompareMetric(
      id: 'points',
      label: 'Pont / meccs',
      shortLabel: 'PONT',
      max: 35,
    ),
    CompareMetric(
      id: 'rebounds',
      label: 'Lepattanó / meccs',
      shortLabel: 'LEP',
      max: 15,
    ),
    CompareMetric(
      id: 'assists',
      label: 'Assziszt / meccs',
      shortLabel: 'AST',
      max: 12,
    ),
    CompareMetric(
      id: 'steals',
      label: 'Labdaszerzés / meccs',
      shortLabel: 'STL',
      max: 2.5,
    ),
    CompareMetric(
      id: 'turnovers',
      label: 'Eladott labda / meccs',
      shortLabel: 'TOV',
      max: 5,
      higherIsBetter: false,
    ),
    CompareMetric(
      id: 'fieldGoal',
      label: 'Mezőny%',
      shortLabel: 'FG%',
      min: 30,
      max: 70,
      percent: true,
    ),
  ];

  static const wnba = [
    CompareMetric(
      id: 'games',
      label: 'Mérkőzés',
      max: 44,
      digits: 0,
      radar: false,
    ),
    CompareMetric(
      id: 'minutes',
      label: 'Perc / meccs',
      shortLabel: 'PERC',
      max: 38,
    ),
    CompareMetric(
      id: 'points',
      label: 'Pont / meccs',
      shortLabel: 'PONT',
      max: 28,
    ),
    CompareMetric(
      id: 'rebounds',
      label: 'Lepattanó / meccs',
      shortLabel: 'LEP',
      max: 12,
    ),
    CompareMetric(
      id: 'assists',
      label: 'Assziszt / meccs',
      shortLabel: 'AST',
      max: 9,
    ),
    CompareMetric(
      id: 'steals',
      label: 'Labdaszerzés / meccs',
      shortLabel: 'STL',
      max: 2.5,
    ),
    CompareMetric(
      id: 'turnovers',
      label: 'Eladott labda / meccs',
      shortLabel: 'TOV',
      max: 5,
      higherIsBetter: false,
    ),
    CompareMetric(
      id: 'fieldGoal',
      label: 'Mezőny%',
      shortLabel: 'FG%',
      min: 30,
      max: 65,
      percent: true,
    ),
  ];

  static const football = [
    CompareMetric(
      id: 'rating',
      label: 'Értékelés átlag',
      shortLabel: 'ÉRTÉKELÉS',
      min: 6,
      max: 8.5,
      digits: 2,
    ),
    CompareMetric(
      id: 'appearances',
      label: 'Mérkőzés',
      shortLabel: 'MECCS',
      max: 38,
      digits: 0,
    ),
    CompareMetric(
      id: 'goals',
      label: 'Gól',
      shortLabel: 'GÓL',
      max: 30,
      digits: 0,
    ),
    CompareMetric(
      id: 'assists',
      label: 'Gólpassz',
      shortLabel: 'GÓLPASSZ',
      max: 15,
      digits: 0,
    ),
    CompareMetric(
      id: 'yellowCards',
      label: 'Sárga lap',
      shortLabel: 'LAPOK',
      max: 12,
      digits: 0,
      higherIsBetter: false,
    ),
  ];

  static const tennis = [
    CompareMetric(
      id: 'ranking',
      label: 'Ranglista-helyezés',
      shortLabel: 'HELYEZÉS',
      min: 1,
      max: 200,
      digits: 0,
      higherIsBetter: false,
    ),
    CompareMetric(
      id: 'rankingPoints',
      label: 'Ranglistapont',
      shortLabel: 'PONT',
      max: 12000,
      digits: 0,
    ),
  ];

  static const nfl = [
    CompareMetric(
      id: 'games',
      label: 'Mérkőzés',
      max: 17,
      digits: 0,
      radar: false,
    ),
    CompareMetric(
      id: 'passingYards',
      label: 'Passzolt yard / meccs',
      shortLabel: 'PASSZ YD',
      max: 320,
    ),
    CompareMetric(
      id: 'rushingYards',
      label: 'Futott yard / meccs',
      shortLabel: 'FUTÁS YD',
      max: 110,
    ),
    CompareMetric(
      id: 'receivingYards',
      label: 'Elkapott yard / meccs',
      shortLabel: 'ELKAPÁS YD',
      max: 110,
    ),
    CompareMetric(
      id: 'touchdowns',
      label: 'Touchdown / meccs',
      shortLabel: 'TD',
      max: 3,
      digits: 2,
    ),
    CompareMetric(
      id: 'interceptions',
      label: 'Interception / meccs',
      shortLabel: 'INT',
      max: 1.5,
      digits: 2,
      higherIsBetter: false,
    ),
    CompareMetric(
      id: 'tackles',
      label: 'Szerelés / meccs',
      shortLabel: 'SZERELÉS',
      max: 10,
    ),
  ];

  /// A sportág mérőszámai; üres lista, ha a sportág nem hasonlítható össze.
  static List<CompareMetric> forSport(Sport sport) => switch (sport) {
    Sport.nba => nba,
    Sport.wnba => wnba,
    Sport.football => football,
    Sport.tennis => tennis,
    Sport.nfl => nfl,
    Sport.darts => const [],
  };
}

/// Igaz, ha a sportághoz van szezonösszesítő forrás.
bool sportSupportsComparison(Sport sport) =>
    CompareMetrics.forSport(sport).isNotEmpty;

/// Egy sportoló összehasonlítható szezonadatai.
class AthleteSeasonSnapshot {
  const AthleteSeasonSnapshot({
    required this.athleteName,
    required this.sport,
    required this.values,
    this.season = '',
    this.team = '',
    this.source = '',
  });

  final String athleteName;
  final Sport sport;

  /// Mérőszám-azonosító → érték (a hiányzó érték `null` vagy nincs benne).
  final Map<String, double?> values;
  final String season;
  final String team;
  final String source;

  double? operator [](String id) => values[id];

  bool get hasData => values.values.any((value) => value != null);
}

/// Melyik oldal a jobb egy mérőszámban.
enum CompareWinner { left, right, tie, none }

/// A jobb érték eldöntése a mérőszám iránya szerint; hiányzó adatnál
/// `none`, a kijelzett pontosságon belüli egyezésnél `tie`.
CompareWinner compareMetric(CompareMetric metric, double? left, double? right) {
  if (left == null || right == null) return CompareWinner.none;
  final precision = 0.5 / _pow10(metric.digits);
  if ((left - right).abs() < precision) return CompareWinner.tie;
  final leftBetter = metric.higherIsBetter ? left > right : left < right;
  return leftBetter ? CompareWinner.left : CompareWinner.right;
}

double _pow10(int digits) {
  var result = 1.0;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}

/// 0–1 közötti érték a radarhoz a referencia-tartomány szerint (fordított
/// mutatónál 1 = legjobb); hiányzó adatnál 0.
double normalizeMetric(CompareMetric metric, double? value) {
  if (value == null) return 0;
  final range = metric.max - metric.min;
  if (range <= 0) return 0;
  final ratio = ((value - metric.min) / range).clamp(0.0, 1.0);
  return metric.higherIsBetter ? ratio : 1 - ratio;
}

/// A radar tengelyei: a radaron szereplő mérőszámok, amelyeknél mindkét
/// sportolónak van értéke.
List<CompareMetric> radarMetrics(
  List<CompareMetric> metrics,
  AthleteSeasonSnapshot left,
  AthleteSeasonSnapshot right,
) => [
  for (final metric in metrics)
    if (metric.radar && left[metric.id] != null && right[metric.id] != null)
      metric,
];

/// „Nikola Jokić 5 mutatóban, Luka Dončić 2 mutatóban jobb.”
String compareSummary(
  List<CompareMetric> metrics,
  AthleteSeasonSnapshot left,
  AthleteSeasonSnapshot right,
) {
  var leftWins = 0;
  var rightWins = 0;
  for (final metric in metrics) {
    switch (compareMetric(metric, left[metric.id], right[metric.id])) {
      case CompareWinner.left:
        leftWins++;
      case CompareWinner.right:
        rightWins++;
      case CompareWinner.tie:
      case CompareWinner.none:
        break;
    }
  }
  return '${left.athleteName} $leftWins mutatóban, '
      '${right.athleteName} $rightWins mutatóban jobb.';
}

// ---------------------------------------------------------------------------
// Szezonadatokból pillanatkép
// ---------------------------------------------------------------------------

AthleteSeasonSnapshot snapshotFromBasketball(
  String athleteName,
  BasketballSeasonStat stat,
) => AthleteSeasonSnapshot(
  athleteName: athleteName,
  sport: stat.league == Sport.wnba.jsonValue ? Sport.wnba : Sport.nba,
  season: stat.season,
  team: stat.team,
  source: stat.source,
  values: {
    'games': stat.games.toDouble(),
    'minutes': stat.minutesPerGame,
    'points': stat.pointsPerGame,
    'rebounds': stat.reboundsPerGame,
    'assists': stat.assistsPerGame,
    'steals': stat.stealsPerGame,
    'turnovers': stat.turnoversPerGame,
    'fieldGoal': stat.fieldGoalPercentage,
  },
);

AthleteSeasonSnapshot? snapshotFromWnbaGames(
  String athleteName,
  List<WnbaGameLog> games, {
  String source = 'SportsDataverse / wehoop',
}) {
  if (games.isEmpty) return null;
  final summary = WnbaSeasonSummary.fromGames(games);
  return AthleteSeasonSnapshot(
    athleteName: athleteName,
    sport: Sport.wnba,
    season: '${games.first.date.year}',
    team: games.first.team,
    source: source,
    values: {
      'games': summary.games.toDouble(),
      'minutes': summary.minutesPerGame,
      'points': summary.pointsPerGame,
      'rebounds': summary.reboundsPerGame,
      'assists': summary.assistsPerGame,
      'steals': summary.stealsPerGame,
      'turnovers': summary.turnoversPerGame,
      'fieldGoal': summary.fieldGoalPercentage,
    },
  );
}

AthleteSeasonSnapshot snapshotFromFootball(
  String athleteName,
  FootballSeasonStat stat,
) => AthleteSeasonSnapshot(
  athleteName: athleteName,
  sport: Sport.football,
  season: stat.season,
  team: stat.team,
  source: stat.source,
  values: {
    'rating': stat.rating,
    'appearances': stat.appearances?.toDouble(),
    'goals': stat.goals?.toDouble(),
    'assists': stat.assists?.toDouble(),
    'yellowCards': stat.yellowCards?.toDouble(),
  },
);

/// NFL-játékos meccsenkénti alapszakasz-átlagai az ESPN-meccsnaplóból; a
/// naplóban nem szereplő kategória (például egy irányító elkapásai) `null`.
AthleteSeasonSnapshot? snapshotFromNflGameLog(
  String athleteName,
  EspnGameLog log,
) {
  final games = log.regularSeason.isEmpty ? log.games : log.regularSeason;
  if (games.isEmpty) return null;
  double? perGame(String name) => log.hasStat(name) ? log.perGame(name) : null;
  final touchdownNames = [
    'passingTouchdowns',
    'rushingTouchdowns',
    'receivingTouchdowns',
  ].where(log.hasStat).toList();
  final touchdowns = touchdownNames.isEmpty
      ? null
      : touchdownNames
            .map((name) => log.perGame(name) ?? 0)
            .reduce((a, b) => a + b);
  return AthleteSeasonSnapshot(
    athleteName: athleteName,
    sport: Sport.nfl,
    season: log.season,
    team: log.athlete.team,
    source: 'ESPN',
    values: {
      'games': games.length.toDouble(),
      'passingYards': perGame('passingYards'),
      'rushingYards': perGame('rushingYards'),
      'receivingYards': perGame('receivingYards'),
      'touchdowns': touchdowns,
      'interceptions': perGame('interceptions'),
      'tackles': perGame('totalTackles'),
    },
  );
}

AthleteSeasonSnapshot snapshotFromTennis(
  String athleteName,
  TennisPlayer player,
) => AthleteSeasonSnapshot(
  athleteName: athleteName,
  sport: Sport.tennis,
  season: player.tour?.toUpperCase() ?? '',
  source: 'Live Tennis API',
  values: {
    'ranking': player.ranking?.toDouble(),
    'rankingPoints': player.rankingPoints?.toDouble(),
  },
);

// ---------------------------------------------------------------------------
// Adatforrás
// ---------------------------------------------------------------------------

/// Egy sportoló összehasonlításhoz szükséges szezonadatai.
abstract interface class CompareDataSource {
  /// `null`, ha a forrás nem adott (értelmezhető) szezonadatot.
  Future<AthleteSeasonSnapshot?> load({
    required String name,
    required Sport sport,
    required String team,
    required SportsApiConfig config,
    bool force = false,
  });
}

/// Az Összehasonlítás oldal szezonadat-forrása (tesztben felülírható).
final compareSourceProvider = Provider<CompareDataSource>(
  (ref) => RepositoryCompareSource(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
    espn: ref.watch(espnAthleteRepositoryProvider),
    reference: ref.watch(basketballReferenceRepositoryProvider),
    wehoop: ref.watch(wnbaWehoopRepositoryProvider),
  ),
  name: 'compareSourceProvider',
);

/// A profiloldal meglévő repositoryjaira épülő forrás: ugyanazokat a
/// gyorsítótárakat és kéréskorlátokat használja (a profil és az
/// összehasonlítás egymás gyorsítótárából is dolgozhat).
class RepositoryCompareSource implements CompareDataSource {
  const RepositoryCompareSource({
    this.http,
    this.cacheStorage,
    this.espn,
    this.reference,
    this.wehoop,
  });

  /// A közös HTTP-réteg; `null` esetén [HttpService.shared].
  final HttpService? http;

  /// A gyorsítótár; `null` esetén [CacheStorage.shared].
  final CacheStorage? cacheStorage;
  final EspnAthleteRepository? espn;
  final BasketballReferenceRepository? reference;
  final WnbaWehoopRepository? wehoop;

  EspnAthleteRepository get _espn =>
      espn ?? EspnAthleteRepository(http: http, cacheStorage: cacheStorage);

  @override
  Future<AthleteSeasonSnapshot?> load({
    required String name,
    required Sport sport,
    required String team,
    required SportsApiConfig config,
    bool force = false,
  }) async {
    switch (sport) {
      case Sport.nba:
        // Basketball Reference, hibánál / hiánynál az ESPN-meccsnaplóból.
        final stat = (await nbaSeasonSummaryWithFallback(
          name,
          forceRefresh: force,
          reference: reference,
          espn: _espn,
        ))?.value;
        return stat == null ? null : snapshotFromBasketball(name, stat);
      case Sport.wnba:
        final result = await wnbaGamesWithFallback(
          name,
          wehoop: wehoop,
          espn: _espn,
        );
        return snapshotFromWnbaGames(name, result.games, source: result.source);
      case Sport.nfl:
        final log = await _espn.gameLog(
          name,
          EspnLeague.nfl,
          forceRefresh: force,
        );
        return log == null ? null : snapshotFromNflGameLog(name, log);
      case Sport.football:
        final result = await FootballSeasonRepository(
          config,
          http: http,
          cacheStorage: cacheStorage,
        ).fetchWithStatus(name, team);
        if (result.stats.isEmpty) {
          if (result.errors.isNotEmpty) {
            throw StateError(result.errors.join('; '));
          }
          return null;
        }
        return snapshotFromFootball(name, result.stats.first);
      case Sport.tennis:
        final data = await TennisRepository(
          config,
          http: http,
          cacheStorage: cacheStorage,
        ).fetch(name, forceRefresh: force);
        return snapshotFromTennis(name, data.player);
      case Sport.darts:
        return null;
    }
  }
}
