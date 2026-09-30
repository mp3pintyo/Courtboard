/// A profil sportolónkénti aszinkron adatai Riverpod-providerként
/// (családok a sportoló szerint kulcsolva, `autoDispose`: a profil
/// bezárásával felszabadulnak).
///
/// A frissíthető adatkártyák [CardDataNotifier]-ek: az első betöltés a
/// gyorsítótár szabályai szerint, a [CardDataNotifier.refresh] (frissítés
/// gomb, „Újra”, Ctrl+R) kényszerítve tölt. A providert `ref.invalidate`-tel
/// is újra lehet építeni (gyorsítótárból).
///
/// Ahol a forrásnak nincs kényszerített (gyorsítótárat megkerülő)
/// betöltése, a kártya egyszerű `FutureProvider.family`, és a frissítés
/// `ref.invalidate`. Az API-kulcstól függő kártyák a kulcsot `select`-tel
/// figyelik: csak annak változásakor töltenek újra (0.14.0 előtt a
/// `DataSourceCard.reloadKey` ugyanezt tette).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_data_players.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/wehoop_wnba.dart';
import 'package:courtboard/domain/sport.dart';
import 'package:courtboard/features/profile/profile_common.dart';
import 'package:courtboard/shared/components.dart';

/// A sportoló közelgő eseményei (a naptár 6 órás gyorsítótárából) — a
/// profil „Következő mérkőzés” sora.
final nextEventsProvider = FutureProvider.autoDispose
    .family<AthleteEventsResult, UpcomingEventsTarget>(
      (ref, target) => ref
          .read(upcomingEventsRepositoryProvider)
          .fetchFor(target, config: ref.read(apiConfigProvider)),
      name: 'nextEventsProvider',
    );

/// Egy frissíthető adatkártya betöltője.
abstract class CardDataNotifier<T> extends AsyncNotifier<T> {
  /// Az adat betöltése; [force] esetén a gyorsítótár megkerülésével.
  Future<T> fetch({required bool force});

  /// Az újratöltést kiváltó beállítások (például egy API-kulcs) figyelése;
  /// változáskor a provider újraépül és gyorsítótárból tölt.
  void watchDependencies() {}

  @override
  Future<T> build() {
    watchDependencies();
    return fetch(force: false);
  }

  /// Kényszerített újratöltés (a kártya közben a betöltési helyőrzőt
  /// mutatja).
  Future<void> refresh() async {
    state = AsyncLoading<T>();
    final next = await AsyncValue.guard(() => fetch(force: true));
    if (ref.mounted) state = next;
  }
}

// ---------------------------------------------------------------------------
// NBA
// ---------------------------------------------------------------------------

/// NBA-szezonösszesítő: Basketball Reference, tartalékként az ESPN
/// meccsnaplójából számolt alapszakasz.
final nbaSeasonSummaryProvider = AsyncNotifierProvider.autoDispose
    .family<NbaSeasonSummaryNotifier, BasketballSeasonStat?, String>(
      NbaSeasonSummaryNotifier.new,
      name: 'nbaSeasonSummaryProvider',
    );

class NbaSeasonSummaryNotifier extends CardDataNotifier<BasketballSeasonStat?> {
  NbaSeasonSummaryNotifier(this.athleteName);

  final String athleteName;

  @override
  Future<BasketballSeasonStat?> fetch({required bool force}) async =>
      (await nbaSeasonSummaryWithFallback(
        athleteName,
        forceRefresh: force,
        reference: ref.read(basketballReferenceRepositoryProvider),
        espn: ref.read(espnAthleteRepositoryProvider),
      ))?.value;
}

// ---------------------------------------------------------------------------
// NFL
// ---------------------------------------------------------------------------

/// NFL-játékos meccsnaplója (ESPN, 6 órás gyorsítótár).
final nflGameLogProvider = AsyncNotifierProvider.autoDispose
    .family<NflGameLogNotifier, EspnGameLog?, String>(
      NflGameLogNotifier.new,
      name: 'nflGameLogProvider',
    );

class NflGameLogNotifier extends CardDataNotifier<EspnGameLog?> {
  NflGameLogNotifier(this.athleteName);

  final String athleteName;

  @override
  Future<EspnGameLog?> fetch({required bool force}) => withHighlights(
    athleteName,
    ref
        .read(espnAthleteRepositoryProvider)
        .gameLog(athleteName, EspnLeague.nfl, forceRefresh: force),
    (log) => [
      for (final game in log?.games.take(8) ?? const <EspnGameLogEntry>[])
        highlightEvent(
          game.date,
          game.opponent,
          MatchOutcome.parse(game.outcome),
          game.score.isEmpty ? null : game.score,
        ),
    ],
    store: ref.read(highlightStoreProvider),
  );
}

/// Egy NFL-sportoló csapatának legutóbbi befejezett mérkőzései (ESPN).
final nflTeamFormProvider = AsyncNotifierProvider.autoDispose
    .family<
      NflTeamFormNotifier,
      List<EspnCompletedGame>,
      ({String athlete, String team})
    >(NflTeamFormNotifier.new, name: 'nflTeamFormProvider');

class NflTeamFormNotifier extends CardDataNotifier<List<EspnCompletedGame>> {
  NflTeamFormNotifier(this.request);

  final ({String athlete, String team}) request;

  Future<List<EspnCompletedGame>> _load({required bool force}) async {
    final repository = ref.read(espnScheduleRepositoryProvider);
    final team = await repository.findTeam(EspnLeague.nfl, request.team);
    if (team == null) {
      throw StateError(
        'Az ESPN nem ismeri ezt az NFL-csapatot: ${request.team}',
      );
    }
    return repository.recentResults(
      EspnLeague.nfl,
      team,
      limit: 8,
      forceRefresh: force,
    );
  }

  @override
  Future<List<EspnCompletedGame>> fetch({required bool force}) =>
      withHighlights(
        request.athlete,
        _load(force: force),
        (games) => [
          for (final game in games)
            highlightEvent(
              game.start,
              game.opponent,
              MatchOutcome.parse(game.outcome),
              game.score.isEmpty ? null : game.score,
            ),
        ],
        store: ref.read(highlightStoreProvider),
      );
}

// ---------------------------------------------------------------------------
// Foci (ESPN-bajnokság, például Liga F)
// ---------------------------------------------------------------------------

/// Egy focicsapat legutóbbi bajnoki eredményei az ESPN-ből.
final espnSoccerTeamGamesProvider = AsyncNotifierProvider.autoDispose
    .family<
      EspnSoccerTeamGamesNotifier,
      List<EspnSoccerGame>,
      ({String athlete, EspnSoccerTeam team})
    >(EspnSoccerTeamGamesNotifier.new, name: 'espnSoccerTeamGamesProvider');

class EspnSoccerTeamGamesNotifier
    extends CardDataNotifier<List<EspnSoccerGame>> {
  EspnSoccerTeamGamesNotifier(this.request);

  final ({String athlete, EspnSoccerTeam team}) request;

  @override
  Future<List<EspnSoccerGame>> fetch({required bool force}) => withHighlights(
    request.athlete,
    ref.read(espnSoccerTeamRepositoryProvider).recentGames(request.team),
    (games) => [
      for (final game in games)
        highlightEvent(
          game.date,
          game.opponent,
          MatchOutcome.parse(game.result),
          game.score,
        ),
    ],
    store: ref.read(highlightStoreProvider),
  );
}

// ---------------------------------------------------------------------------
// NBA / NFL / foci: API-Sports és az egyesített NBA-játékosadat
// ---------------------------------------------------------------------------

/// Az NBA-profil élő adatai: az egyesített játékosadat (meccsnaplóval) és —
/// a formagörbe átlagvonalához — a szezonösszesítő, ha elérhető. A
/// szezonösszesítő ugyanabból a gyorsítótárból jön, mint a „Szezon
/// összesítő” kártyáé (az egyidejű kérést a gyorsítótár összevonja).
class NbaProfileBundle {
  const NbaProfileBundle(this.data, this.season);
  final UnifiedAthleteData data;
  final BasketballSeasonStat? season;
}

/// A „Játékosadatok” kártya kérése: sportág, sportoló és csapat.
typedef ApiSportsRequest = ({Sport sport, String athlete, String team});

/// API-Sports (foci: a csapat legutóbbi meccsei, NFL: játékos) vagy NBA-nál
/// az egyesített játékosadat ([NbaProfileBundle]). Az API-Sports és a
/// balldontlie kulcs változásakor újratölt.
final apiSportsCardProvider = FutureProvider.autoDispose
    .family<Object, ApiSportsRequest>((ref, request) {
      ref.watch(
        apiConfigProvider.select(
          (config) => (config.apiSportsKey, config.balldontlieKey),
        ),
      );
      return withHighlights(
        request.athlete,
        _loadApiSports(ref, request),
        (data) => switch (data) {
          final List<ApiSportsGame> games => [
            for (final game in games)
              highlightEvent(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.result),
                game.score,
              ),
          ],
          final NbaProfileBundle bundle => [
            for (final game in bundle.data.games)
              highlightEvent(
                game.date,
                game.opponent,
                MatchOutcome.parse(game.outcome),
                game.score,
              ),
          ],
          _ => const <HighlightEvent>[],
        },
        store: ref.read(highlightStoreProvider),
      );
    }, name: 'apiSportsCardProvider');

Future<Object> _loadApiSports(Ref ref, ApiSportsRequest request) {
  final repo = ref.read(apiSportsRepositoryProvider);
  return switch (request.sport) {
    Sport.football => repo.footballRecent(request.team),
    Sport.nba => _loadNbaBundle(ref, request.athlete),
    _ => repo.nflPlayer(request.athlete),
  };
}

Future<NbaProfileBundle> _loadNbaBundle(Ref ref, String athleteName) async {
  final season = ref
      .read(basketballReferenceRepositoryProvider)
      .seasonSummary(athleteName)
      .then<BasketballSeasonStat?>(
        (value) => value,
        onError: (Object _) => null,
      );
  final data = await ref
      .read(multiProviderAthleteRepositoryProvider)
      .fetchNbaPlayer(athleteName);
  // A Basketball Reference szezonátlaga, tartalékként az ESPN-é.
  return NbaProfileBundle(data, await season ?? data.espnSeason);
}

// ---------------------------------------------------------------------------
// Darts
// ---------------------------------------------------------------------------

/// Darts profil és eredmények (egyesített források); a RapidAPI-kulcs
/// változásakor újratölt.
final dartsProfileProvider = FutureProvider.autoDispose
    .family<DartsProfileData, String>((ref, athleteName) {
      ref.watch(apiConfigProvider.select((config) => config.rapidApiKey));
      return withHighlights(
        athleteName,
        ref.read(dartsRepositoryProvider).fetch(athleteName),
        (data) => [
          for (final result in data.results)
            highlightEvent(
              result.date,
              result.event,
              MatchOutcome.parse(result.detail),
            ),
        ],
        store: ref.read(highlightStoreProvider),
      );
    }, name: 'dartsProfileProvider');

// ---------------------------------------------------------------------------
// Foci (API-Sports szezon, football-data.org)
// ---------------------------------------------------------------------------

/// Egy focista kérése: a sportoló és a csapata.
typedef FootballRequest = ({String athlete, String team});

/// A focista szezonösszesítője (API-Sports, tartalékokkal); az API-Sports
/// kulcs változásakor újratölt.
final footballSeasonProvider = FutureProvider.autoDispose
    .family<FootballSeasonResult, FootballRequest>((ref, request) {
      ref.watch(apiConfigProvider.select((config) => config.apiSportsKey));
      return ref
          .read(footballSeasonRepositoryProvider)
          .fetchWithStatus(request.athlete, request.team);
    }, name: 'footballSeasonProvider');

/// A [FootballResult] a közös eredményjelölésre fordítva.
MatchOutcome footballMatchOutcome(FootballResult result) => switch (result) {
  FootballResult.win => MatchOutcome.win,
  FootballResult.loss => MatchOutcome.loss,
  FootballResult.draw => MatchOutcome.draw,
  FootballResult.unknown => MatchOutcome.upcoming,
};

/// A csapat lejátszott és közelgő mérkőzései (football-data.org és
/// tartalékai); a football-data kulcs változásakor újratölt.
final footballTeamGamesProvider = FutureProvider.autoDispose
    .family<FootballTeamGames, FootballRequest>((ref, request) {
      ref.watch(apiConfigProvider.select((config) => config.footballDataKey));
      return withHighlights(
        request.athlete,
        ref.read(footballDataRepositoryProvider).fetchTeamGames(request.team),
        (data) => [
          for (final game in [...data.recent, ...data.upcoming])
            highlightEvent(
              game.date,
              'vs. ${game.opponent}',
              footballMatchOutcome(game.result),
              game.result == FootballResult.unknown ? null : game.score,
            ),
        ],
        store: ref.read(highlightStoreProvider),
      );
    }, name: 'footballTeamGamesProvider');

/// A játékos football-data.org-profilja (a csapat aktuális keretéből); a
/// football-data kulcs változásakor újratölt.
final footballDataPlayerProvider = FutureProvider.autoDispose
    .family<FootballDataPlayerProfile?, FootballRequest>((ref, request) {
      ref.watch(apiConfigProvider.select((config) => config.footballDataKey));
      return ref
          .read(footballDataPlayerRepositoryProvider)
          .findPlayer(request.athlete, request.team);
    }, name: 'footballDataPlayerProvider');

// ---------------------------------------------------------------------------
// Tenisz
// ---------------------------------------------------------------------------

/// Teniszprofil (Live Tennis API): a profil betöltése, majd a mai
/// ranglista-mérés rögzítése a helyi történetbe (hálózati kérés nélkül).
/// A kulcs változásakor újratölt; kulcs nélkül a kártya nem figyeli.
final tennisProfileProvider = AsyncNotifierProvider.autoDispose
    .family<TennisProfileNotifier, TennisProfileData, String>(
      TennisProfileNotifier.new,
      name: 'tennisProfileProvider',
    );

class TennisProfileNotifier extends CardDataNotifier<TennisProfileData> {
  TennisProfileNotifier(this.athleteName);

  final String athleteName;

  @override
  void watchDependencies() =>
      ref.watch(apiConfigProvider.select((config) => config.liveTennisKey));

  Future<TennisProfileData> _fetchWithHistory({required bool force}) async {
    final data = await ref
        .read(tennisRepositoryProvider)
        .fetch(athleteName, forceRefresh: force);
    final history = await ref
        .read(rankingHistoryStoreProvider)
        .record(
          athleteName,
          ranking: data.player.ranking,
          points: data.player.rankingPoints,
        );
    return TennisProfileData(
      player: data.player,
      liveMatches: data.liveMatches,
      upcomingMatches: data.upcomingMatches,
      fixtures: data.fixtures,
      usage: data.usage,
      fetchedAt: data.fetchedAt,
      fromCache: data.fromCache,
      rankingHistory: history,
    );
  }

  @override
  Future<TennisProfileData> fetch({required bool force}) => withHighlights(
    athleteName,
    _fetchWithHistory(force: force),
    (data) => [
      for (final match in data.upcomingMatches)
        if (match.scheduledTime != null)
          highlightEvent(
            match.scheduledTime!,
            'vs. ${match.opponentOf(data.player)}',
            MatchOutcome.upcoming,
          ),
      for (final fixture in data.fixtures)
        if (fixture.eventDate != null)
          highlightEvent(
            fixture.eventDate!,
            'vs. ${fixture.opponentOf(data.player)}',
            MatchOutcome.upcoming,
          ),
    ],
    store: ref.read(highlightStoreProvider),
  );
}

// ---------------------------------------------------------------------------
// WNBA
// ---------------------------------------------------------------------------

/// WNBA meccsnapló: wehoop box score-ok, tartalékként az ESPN
/// játékos-meccsnaplója.
final wnbaGamesProvider = AsyncNotifierProvider.autoDispose
    .family<WnbaGamesNotifier, WnbaGamesResult, String>(
      WnbaGamesNotifier.new,
      name: 'wnbaGamesProvider',
    );

class WnbaGamesNotifier extends CardDataNotifier<WnbaGamesResult> {
  WnbaGamesNotifier(this.athleteName);

  final String athleteName;

  @override
  Future<WnbaGamesResult> fetch({required bool force}) => withHighlights(
    athleteName,
    wnbaGamesWithFallback(
      athleteName,
      forceRefresh: force,
      wehoop: ref.read(wnbaWehoopRepositoryProvider),
      espn: ref.read(espnAthleteRepositoryProvider),
    ),
    (result) => [
      for (final game in result.games)
        highlightEvent(
          game.date,
          game.opponent,
          switch (game.result) {
            WnbaResult.win => MatchOutcome.win,
            WnbaResult.loss => MatchOutcome.loss,
            WnbaResult.unknown => MatchOutcome.unknown,
          },
          game.teamScore == 0 && game.opponentScore == 0 ? null : game.score,
        ),
    ],
    store: ref.read(highlightStoreProvider),
  );
}

/// Kiegészítő WNBA-meccsnapló a Basketball Reference-ből.
final wnbaBasketballReferenceProvider = FutureProvider.autoDispose
    .family<CachedValue<List<NbaGameLog>>, String>(
      (ref, athleteName) => withHighlights(
        athleteName,
        ref
            .read(basketballReferenceRepositoryProvider)
            .recentGamesCached(athleteName, league: 'wnba'),
        (cached) => [
          for (final game in cached.value)
            highlightEvent(
              game.date,
              game.opponent,
              MatchOutcome.parse(game.outcome),
              game.score,
            ),
        ],
        store: ref.read(highlightStoreProvider),
      ),
      name: 'wnbaBasketballReferenceProvider',
    );

/// WNBA játékosbio és haladó statisztika (RapidAPI, 7 napos gyorsítótár);
/// a RapidAPI-kulcs változásakor újratölt, kulcs nélkül a kártya nem
/// figyeli.
final wnbaRapidProfileProvider = FutureProvider.autoDispose
    .family<WnbaRapidProfile?, String>((ref, athleteName) {
      ref.watch(apiConfigProvider.select((config) => config.rapidApiKey));
      return ref
          .read(wnbaRapidApiRepositoryProvider)
          .playerProfile(athleteName);
    }, name: 'wnbaRapidProfileProvider');
