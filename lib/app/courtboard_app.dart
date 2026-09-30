/// Az alkalmazás gyökere: `ProviderScope`, téma, lokalizáció és a router.
///
/// A `main` közvetlenül `ProviderScope(overrides: courtboardOverrides(...),
/// child: const CourtboardRoot())`-ot futtat; a [CourtboardApp] ugyanezt
/// állítja össze egyedi paraméterekből (a widgettesztek így egy-egy hamis
/// szolgáltatással indíthatják az appot, további `overrides`-szal).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:courtboard/app/app_services.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/app/router.dart';
import 'package:courtboard/data/api_key_id.dart';
import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/secret_store.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// Az alkalmazás egyedi paraméterekből: [AppServices] és [AppLaunchState]
/// összeállítása, majd `ProviderScope` a [CourtboardRoot] körül.
class CourtboardApp extends StatefulWidget {
  /// A [services] a `main`-ben összeállított szolgáltatások; ha `null`, a
  /// többi (egyedi) paraméterből épül fel egy példány.
  const CourtboardApp({
    super.key,
    this.services,
    this.initialState = const CourtboardLocalState(),
    this.stateStore,
    this.playlistFile,
    this.apiKeys = const {},
    this.apiKeyStore,
    this.secureStorageAvailable = true,
    this.appVersion,
    this.updateChecker,
    this.upcomingEvents,
    this.desktop,
    this.notificationService,
    this.startupRegistration,
    this.watcherSource,
    this.watcherMemoryStore,
    this.compareSource,
    this.initialLocation = '/',
    this.overrides = const [],
  });

  /// Kész szolgáltatás-tároló (lásd [AppServices]); megadásakor az egyedi
  /// szolgáltatásparaméterek figyelmen kívül maradnak.
  final AppServices? services;

  /// Az Összehasonlítás oldal szezonadat-forrása (tesztekhez); `null`
  /// esetén a meglévő repositorykra épülő [RepositoryCompareSource].
  final CompareDataSource? compareSource;

  /// Ablak, tálcaikon és bezárás kezelése; `null` (például widget-tesztben)
  /// esetén ezek a funkciók kimaradnak.
  final DesktopIntegration? desktop;

  /// Asztali értesítések; `null` esetén nincs háttérfigyelő.
  final NotificationService? notificationService;

  /// „Indítás a Windows-zal”; `null` esetén a kapcsoló letiltott.
  final StartupRegistration? startupRegistration;

  /// A háttérfigyelő adatforrása (tesztekhez); `null` esetén a meglévő
  /// repositorykra épülő [RepositoryWatcherSource].
  final WatcherDataSource? watcherSource;

  /// A háttérfigyelő emlékezete (tesztekhez); `null` esetén a gyorsítótár.
  final WatcherMemoryStore? watcherMemoryStore;

  /// A futó alkalmazás verziója (`0.15.0`); `null`, ha nem ismert.
  final String? appVersion;

  /// A GitHub-kiadások figyelője; `null` esetén (például tesztben) nincs
  /// frissítés-ellenőrzés.
  final UpdateChecker? updateChecker;

  /// A naptár eseményvezérlője; `null` esetén a provider hoz létre egyet.
  final UpcomingEventsController? upcomingEvents;

  /// A futtatás előtt egyszer betöltött helyi állapot.
  final CourtboardLocalState initialState;

  /// A biztonságos tárolóból (vagy annak hibájakor a régi állapotfájlból)
  /// betöltött API-kulcsok; a környezeti változókat felülírják.
  final Map<ApiKeyId, String> apiKeys;

  /// Az appban módosított kulcsok mentési helye; `null` esetén a közös
  /// [SecretStore.shared]-re épülő tároló.
  final ApiKeyStore? apiKeyStore;

  /// Hamis, ha indításkor a biztonságos tároló nem volt elérhető.
  final bool secureStorageAvailable;

  /// Az állapot mentésének helye; `null` esetén (például widget-tesztben)
  /// az alkalmazás semmit nem ír a lemezre.
  final LocalStateStore? stateStore;

  /// A saját videólista fájlja; `null` esetén nincs betöltés és mentés.
  final File? playlistFile;

  /// A kezdő útvonal (például `/sportolok/nikola-jokic`).
  final String initialLocation;

  /// További provider-felülírások (tesztekhez), a szolgáltatásokéi után.
  final List<Override> overrides;

  @override
  State<CourtboardApp> createState() => _CourtboardAppState();
}

class _CourtboardAppState extends State<CourtboardApp> {
  late final AppServices _services =
      widget.services ??
      AppServices(
        stateStore: widget.stateStore,
        playlistFile: widget.playlistFile,
        apiKeyStore: widget.apiKeyStore,
        appVersion: widget.appVersion,
        updateChecker: widget.updateChecker,
        upcomingEvents: widget.upcomingEvents,
        desktop: widget.desktop,
        notificationService: widget.notificationService,
        startupRegistration: widget.startupRegistration,
        watcherSource: widget.watcherSource,
        watcherMemoryStore: widget.watcherMemoryStore,
        compareSource: widget.compareSource,
      );

  late final List<Override> _overrides = [
    ...courtboardOverrides(
      services: _services,
      launch: AppLaunchState(
        initialState: widget.initialState,
        apiKeys: widget.apiKeys,
        secureStorageAvailable: widget.secureStorageAvailable,
        initialLocation: widget.initialLocation,
      ),
    ),
    ...widget.overrides,
  ];

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: _overrides,
    retry: noAutomaticRetry,
    child: const CourtboardRoot(),
  );
}

/// A `MaterialApp.router` a témával; a téma változásakor épül újra.
class CourtboardRoot extends ConsumerWidget {
  const CourtboardRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (theme, themeMode) = ref.watch(
      appControllerProvider.select((app) => (app.theme, app.themeMode)),
    );
    final accent = CourtboardAccent.fromStorage(theme);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Courtboard',
      theme: buildCourtboardTheme(accent, Brightness.light),
      darkTheme: buildCourtboardTheme(accent, Brightness.dark),
      themeMode: themeModeFromStorage(themeMode),
      locale: const Locale('hu'),
      supportedLocales: const [Locale('hu')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
