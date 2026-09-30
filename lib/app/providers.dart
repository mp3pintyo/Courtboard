/// Az alkalmazásszintű Riverpod-providerek: az indítási adatok, a platform-
/// szolgáltatások, az állapotvezérlők (`AppController`,
/// `ActivityController`, `DesktopCoordinator`) és az adatréteg
/// providereinek alkalmazáshoz kötése ([courtboardOverrides]).
///
/// Az adatréteg providerei (HTTP, gyorsítótárak, repositoryk, naptár-
/// vezérlő) a `lib/data/providers.dart`-ban élnek; a router a
/// `lib/app/router.dart`-ban.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:courtboard/app/activity_controller.dart';
import 'package:courtboard/app/app_controller.dart';
import 'package:courtboard/app/app_services.dart';
import 'package:courtboard/app/desktop_coordinator.dart';
import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';

/// Az indítás előtt egyszer betöltött adatok.
class AppLaunchState {
  const AppLaunchState({
    this.initialState = const CourtboardLocalState(),
    this.apiKeys = const {},
    this.secureStorageAvailable = true,
    this.initialLocation = '/',
  });

  /// A mentett helyi állapot.
  final CourtboardLocalState initialState;

  /// A biztonságos tárolóból (vagy annak hibájakor a régi állapotfájlból)
  /// betöltött API-kulcsok; a környezeti változókat felülírják.
  final Map<ApiKeyId, String> apiKeys;

  /// Hamis, ha indításkor a biztonságos tároló nem volt elérhető.
  final bool secureStorageAvailable;

  /// A kezdő útvonal (alapból az Áttekintés).
  final String initialLocation;
}

// ---------------------------------------------------------------------------
// Indítás és platformszolgáltatások
// ---------------------------------------------------------------------------

/// Az indításkor összeállított szolgáltatások (lásd [courtboardOverrides]).
final appServicesProvider = Provider<AppServices>(
  (ref) => AppServices(),
  name: 'appServicesProvider',
);

/// Az indítás előtt betöltött állapot és kulcsok.
final appLaunchProvider = Provider<AppLaunchState>(
  (ref) => const AppLaunchState(),
  name: 'appLaunchProvider',
);

/// A futó alkalmazás verziója (`0.15.0`); `null`, ha nem ismert.
final appVersionProvider = Provider<String?>(
  (ref) => ref.watch(appServicesProvider).appVersion,
  name: 'appVersionProvider',
);

/// A GitHub-kiadások figyelője; `null` esetén nincs frissítés-ellenőrzés.
final updateCheckerProvider = Provider<UpdateChecker?>(
  (ref) => ref.watch(appServicesProvider).updateChecker,
  name: 'updateCheckerProvider',
);

/// Ablak, tálcaikon és bezárás kezelése; `null` esetén ezek kimaradnak.
final desktopIntegrationProvider = Provider<DesktopIntegration?>(
  (ref) => ref.watch(appServicesProvider).desktop,
  name: 'desktopIntegrationProvider',
);

/// „Indítás a Windows-zal”; `null` esetén a kapcsoló letiltott.
final startupRegistrationProvider = Provider<StartupRegistration?>(
  (ref) => ref.watch(appServicesProvider).startupRegistration,
  name: 'startupRegistrationProvider',
);

/// A háttérfigyelő adatforrása: a meglévő repositorykra épül (a kulcsokat
/// minden futáskor frissen olvassa).
final watcherSourceProvider = Provider<WatcherDataSource>(
  (ref) =>
      ref.watch(appServicesProvider).watcherSource ??
      RepositoryWatcherSource(
        config: () => ref.read(apiConfigProvider),
        news: ref.watch(newsRepositoryProvider),
        upcoming: ref.watch(upcomingEventsRepositoryProvider),
        espn: ref.watch(espnScheduleRepositoryProvider),
        live: ref.watch(liveScoresRepositoryProvider),
        espnSoccer: ref.watch(espnSoccerTeamRepositoryProvider),
        highlights: ref.watch(highlightStoreProvider),
      ),
  name: 'watcherSourceProvider',
);

/// A háttérfigyelő emlékezete; `null` esetén a gyorsítótár.
final watcherMemoryStoreProvider = Provider<WatcherMemoryStore?>(
  (ref) => ref.watch(appServicesProvider).watcherMemoryStore,
  name: 'watcherMemoryStoreProvider',
);

// ---------------------------------------------------------------------------
// Állapotvezérlők
// ---------------------------------------------------------------------------

/// A felhasználói állapot (sportolók, beállítások, kulcsok, videólista) és
/// annak mentése. `ref.watch(appControllerProvider)` minden változáskor
/// újraépít; szűkebb figyeléshez `select`.
final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final services = ref.watch(appServicesProvider);
  final launch = ref.watch(appLaunchProvider);
  return AppController(
    initialState: launch.initialState,
    stateStore: services.stateStore,
    playlistStore: services.playlistStore,
    apiKeyStore: services.apiKeyStore,
    apiKeys: launch.apiKeys,
    secureStorageAvailable: launch.secureStorageAvailable,
    updateChecker: services.updateChecker,
  );
}, name: 'appControllerProvider');

/// Kiemelések, hírfolyam és naptár (nyitólap, Követés).
final activityControllerProvider = ChangeNotifierProvider<ActivityController>(
  (ref) => ActivityController(
    app: ref.watch(appControllerProvider.notifier),
    highlightStore: ref.watch(highlightStoreProvider),
    news: ref.watch(newsRepositoryProvider),
    upcoming: ref.watch(upcomingEventsControllerProvider),
  ),
  name: 'activityControllerProvider',
);

/// Tálca, ablak, Windows-indítás, értesítések és a háttérfigyelő.
final desktopCoordinatorProvider = ChangeNotifierProvider<DesktopCoordinator>(
  (ref) => DesktopCoordinator(
    app: ref.watch(appControllerProvider.notifier),
    activity: ref.watch(activityControllerProvider.notifier),
    watcherSource: ref.watch(watcherSourceProvider),
    notifications: ref.watch(notificationServiceProvider),
    desktop: ref.watch(desktopIntegrationProvider),
    startupRegistration: ref.watch(startupRegistrationProvider),
    watcherMemoryStore: ref.watch(watcherMemoryStoreProvider),
  ),
  name: 'desktopCoordinatorProvider',
);

// ---------------------------------------------------------------------------
// Összekötés
// ---------------------------------------------------------------------------

/// Az alkalmazás `ProviderScope`-jának felülírásai: a [services] és a
/// [launch] adatai, az API-konfiguráció az [AppController]-ből, és a
/// szolgáltatásokban megadott adatréteg-példányok.
List<Override> courtboardOverrides({
  required AppServices services,
  AppLaunchState launch = const AppLaunchState(),
}) => [
  appServicesProvider.overrideWithValue(services),
  appLaunchProvider.overrideWithValue(launch),
  apiConfigProvider.overrideWith(
    (ref) => ref.watch(appControllerProvider.select((app) => app.apiConfig)),
  ),
  ...services.overrides,
];

/// Az automatikus újrapróbálás kikapcsolása: a hibát az adatkártya mutatja
/// „Újra” gombbal (a szolgáltatói kvóták védelmében sem próbálkozunk
/// magunktól).
Duration? noAutomaticRetry(int retryCount, Object error) => null;
