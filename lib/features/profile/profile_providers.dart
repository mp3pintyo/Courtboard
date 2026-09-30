/// A profil sportolónkénti aszinkron adatai Riverpod-providerként
/// (családok a sportoló szerint kulcsolva, `autoDispose`: a profil
/// bezárásával felszabadulnak).
///
/// A frissíthető adatkártyák [CardDataNotifier]-ek: az első betöltés a
/// gyorsítótár szabályai szerint, a [CardDataNotifier.refresh] (frissítés
/// gomb, „Újra”, Ctrl+R) kényszerítve tölt. A providert `ref.invalidate`-tel
/// is újra lehet építeni (gyorsítótárból).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/basketball_season.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/upcoming_events.dart';
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

  @override
  Future<T> build() => fetch(force: false);

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
