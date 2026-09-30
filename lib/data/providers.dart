/// Az adatréteg Riverpod-providerei: HTTP, gyorsítótárak, repositoryk és a
/// naptár eseményvezérlője.
///
/// Az alapértékek a közös példányokra épülnek ([HttpService.shared],
/// [CacheStorage.shared] …), így az app és a tesztek ugyanazt kapják, mint
/// a 0.13.0 előtt. A `ProviderScope` `overrides` listájával bármelyik
/// cserélhető (például hamis HTTP-réteg vagy repository egy widgettesztben).
///
/// Az API-kulcsoktól függő repositoryk az [apiConfigProvider]-t figyelik:
/// kulcsmentéskor új példány készül. Az alkalmazás az [apiConfigProvider]-t
/// az `AppController` aktuális konfigurációjára köti (lásd
/// `lib/app/providers.dart`).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_athletes.dart';
import 'package:courtboard/data/espn_schedule.dart';
import 'package:courtboard/data/espn_soccer_team.dart';
import 'package:courtboard/data/football_data.dart';
import 'package:courtboard/data/football_data_players.dart';
import 'package:courtboard/data/football_season_repository.dart';
import 'package:courtboard/data/head_to_head.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/live_scores.dart';
import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/match_timeline.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/openligadb.dart';
import 'package:courtboard/data/ranking_history.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

// ---------------------------------------------------------------------------
// Infrastruktúra
// ---------------------------------------------------------------------------

/// A közös HTTP-réteg (kéréskorlát, kvótaszámláló, újrapróbálás).
final httpServiceProvider = Provider<HttpService>(
  (ref) => HttpService.shared,
  name: 'httpServiceProvider',
);

/// A lemezes JSON-gyorsítótár tárolója.
final cacheStorageProvider = Provider<CacheStorage>(
  (ref) => CacheStorage.shared,
  name: 'cacheStorageProvider',
);

/// A profil adatkártyái által mentett kiemelések (nyitólap, Követés).
final highlightStoreProvider = Provider<AthleteHighlightStore>(
  (ref) => AthleteHighlightStore.shared,
  name: 'highlightStoreProvider',
);

/// A teniszezők helyben gyűjtött ranglista-története.
final rankingHistoryStoreProvider = Provider<RankingHistoryStore>(
  (ref) => RankingHistoryStore.shared,
  name: 'rankingHistoryStoreProvider',
);

/// Az aktuális API-kulcsokkal összeállított konfiguráció. Alapból a
/// környezeti változókból; az alkalmazásban az `AppController`-é.
final apiConfigProvider = Provider<SportsApiConfig>(
  (ref) => SportsApiConfig.fromEnvironment(),
  name: 'apiConfigProvider',
);

/// A kulcsos szolgáltatók kliense az aktuális konfigurációval.
final sportsApiClientProvider = Provider<SportsApiClient>((ref) {
  final client = SportsApiClient(
    config: ref.watch(apiConfigProvider),
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  );
  ref.onDispose(client.close);
  return client;
}, name: 'sportsApiClientProvider');

/// Asztali értesítések; `null` esetén nincs értesítés (és háttérfigyelő).
final notificationServiceProvider = Provider<NotificationService?>(
  (ref) => null,
  name: 'notificationServiceProvider',
);

/// Hírforrások és a helyi hírarchívum.
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final repository = NewsRepository(
    provider: RssNewsProvider(http: ref.watch(httpServiceProvider)),
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
}, name: 'newsRepositoryProvider');

// ---------------------------------------------------------------------------
// Kulcs nélküli repositoryk
// ---------------------------------------------------------------------------

final espnAthleteRepositoryProvider = Provider<EspnAthleteRepository>(
  (ref) => EspnAthleteRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'espnAthleteRepositoryProvider',
);

final espnScheduleRepositoryProvider = Provider<EspnScheduleRepository>(
  (ref) => EspnScheduleRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'espnScheduleRepositoryProvider',
);

final liveScoresRepositoryProvider = Provider<LiveScoresRepository>(
  (ref) => LiveScoresRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
    schedule: ref.watch(espnScheduleRepositoryProvider),
  ),
  name: 'liveScoresRepositoryProvider',
);

final matchTimelineRepositoryProvider = Provider<MatchTimelineRepository>(
  (ref) => MatchTimelineRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'matchTimelineRepositoryProvider',
);

final headToHeadRepositoryProvider = Provider<HeadToHeadRepository>(
  (ref) => HeadToHeadRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'headToHeadRepositoryProvider',
);

final upcomingEventsRepositoryProvider = Provider<UpcomingEventsRepository>(
  (ref) => UpcomingEventsRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'upcomingEventsRepositoryProvider',
);

final basketballReferenceRepositoryProvider =
    Provider<BasketballReferenceRepository>(
      (ref) => BasketballReferenceRepository(
        http: ref.watch(httpServiceProvider),
        cacheStorage: ref.watch(cacheStorageProvider),
      ),
      name: 'basketballReferenceRepositoryProvider',
    );

/// A wehoop-szezonfájl (a feldolgozott CSV a memóriában marad, ezért a
/// közös példány).
final wnbaWehoopRepositoryProvider = Provider<WnbaWehoopRepository>(
  (ref) => WnbaWehoopRepository.shared,
  name: 'wnbaWehoopRepositoryProvider',
);

final openLigaDbRepositoryProvider = Provider<OpenLigaDbRepository>(
  (ref) => OpenLigaDbRepository(
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'openLigaDbRepositoryProvider',
);

/// Egy focicsapat bajnoki eredményei az ESPN-ből (például Liga F).
final espnSoccerTeamRepositoryProvider = Provider<EspnSoccerTeamRepository>(
  (ref) => EspnSoccerTeamRepository(ref.watch(sportsApiClientProvider)),
  name: 'espnSoccerTeamRepositoryProvider',
);

// ---------------------------------------------------------------------------
// Kulcsos (konfigurációfüggő) repositoryk
// ---------------------------------------------------------------------------

final apiSportsRepositoryProvider = Provider<ApiSportsRepository>(
  (ref) => ApiSportsRepository(
    ref.watch(apiConfigProvider).apiSportsKey,
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'apiSportsRepositoryProvider',
);

final multiProviderAthleteRepositoryProvider =
    Provider<MultiProviderAthleteRepository>(
      (ref) => MultiProviderAthleteRepository(
        ref.watch(apiConfigProvider),
        http: ref.watch(httpServiceProvider),
        cacheStorage: ref.watch(cacheStorageProvider),
      ),
      name: 'multiProviderAthleteRepositoryProvider',
    );

final dartsRepositoryProvider = Provider<DartsRepository>(
  (ref) => DartsRepository(
    ref.watch(apiConfigProvider),
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'dartsRepositoryProvider',
);

final footballSeasonRepositoryProvider = Provider<FootballSeasonRepository>(
  (ref) => FootballSeasonRepository(
    ref.watch(apiConfigProvider),
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'footballSeasonRepositoryProvider',
);

final footballDataRepositoryProvider = Provider<FootballDataRepository>(
  (ref) => FootballDataRepository(
    ref.watch(sportsApiClientProvider),
    openLiga: ref.watch(openLigaDbRepositoryProvider),
  ),
  name: 'footballDataRepositoryProvider',
);

final footballDataPlayerRepositoryProvider =
    Provider<FootballDataPlayerRepository>(
      (ref) => FootballDataPlayerRepository(
        ref.watch(sportsApiClientProvider),
        cacheStorage: ref.watch(cacheStorageProvider),
      ),
      name: 'footballDataPlayerRepositoryProvider',
    );

final tennisRepositoryProvider = Provider<TennisRepository>(
  (ref) => TennisRepository(
    ref.watch(apiConfigProvider),
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'tennisRepositoryProvider',
);

final wnbaRapidApiRepositoryProvider = Provider<WnbaRapidApiRepository>(
  (ref) => WnbaRapidApiRepository(
    ref.watch(apiConfigProvider),
    wehoop: ref.watch(wnbaWehoopRepositoryProvider),
    http: ref.watch(httpServiceProvider),
    cacheStorage: ref.watch(cacheStorageProvider),
  ),
  name: 'wnbaRapidApiRepositoryProvider',
);

// ---------------------------------------------------------------------------
// Vezérlők és segédek
// ---------------------------------------------------------------------------

/// A naptár eseményvezérlője (oldalváltáskor és a nyitólap „Mai fókusz”
/// blokkjához is megmarad). Egyszerű provider: a vezérlő a betöltés közben
/// (akár egy widget életciklusában) is jelez, ezért a figyelők közvetlenül
/// iratkoznak fel rá (`addListener` / `ListenableBuilder`).
final upcomingEventsControllerProvider = Provider<UpcomingEventsController>((
  ref,
) {
  final controller = UpcomingEventsController(
    repository: ref.watch(upcomingEventsRepositoryProvider),
    highlightStore: ref.watch(highlightStoreProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
}, name: 'upcomingEventsControllerProvider');

/// Profilkép keresése egy új sportolóhoz; hiba vagy időtúllépés esetén
/// `null` (monogram jelenik meg).
final profileImageResolverProvider =
    Provider<Future<String?> Function(String name)>(
      (ref) => (name) async {
        final client = SportsApiClient(
          config: ref.read(apiConfigProvider),
          http: ref.read(httpServiceProvider),
          cacheStorage: ref.read(cacheStorageProvider),
        );
        try {
          return await client
              .resolveProfileImage(name)
              .timeout(const Duration(seconds: 25));
        } catch (_) {
          return null;
        } finally {
          client.close();
        }
      },
      name: 'profileImageResolverProvider',
    );
