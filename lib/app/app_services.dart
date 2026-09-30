/// Az alkalmazás indításkor összeállított platformszolgáltatásai és
/// tesztcsatlakozói egy helyen.
///
/// A `main` (vagy egy widgetteszt a [CourtboardApp]-on keresztül) hozza
/// létre; a widgetfában nem közvetlenül, hanem Riverpod-providereken át
/// érhetők el (lásd `lib/app/providers.dart` és [AppServices.overrides]).
/// Amit itt nem adnak meg, azt az alapértelmezett provider hozza létre.
library;

import 'dart:io';

import 'package:flutter_riverpod/misc.dart';

import 'package:courtboard/data/api_key_store.dart';
import 'package:courtboard/data/athlete_highlights.dart';
import 'package:courtboard/data/athlete_watcher.dart';
import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/news.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/playlist_store.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/data/upcoming_events.dart';
import 'package:courtboard/data/update_checker.dart';
import 'package:courtboard/desktop/desktop_integration.dart';
import 'package:courtboard/desktop/startup_registration.dart';
import 'package:courtboard/features/compare/compare_data.dart';

class AppServices {
  AppServices({
    this.stateStore,
    File? playlistFile,
    ApiKeyStore? apiKeyStore,
    this.appVersion,
    this.updateChecker,
    this.upcomingEvents,
    this.desktop,
    this.notificationService,
    this.startupRegistration,
    this.watcherSource,
    this.watcherMemoryStore,
    this.compareSource,
    this.newsRepository,
    this.highlightStore,
    this.http,
  }) : playlistStore = playlistFile == null
           ? null
           : PlaylistStore(playlistFile),
       apiKeyStore = apiKeyStore ?? ApiKeyStore();

  /// Az állapot mentésének helye; `null` esetén (például widget-tesztben)
  /// az alkalmazás semmit nem ír a lemezre.
  final LocalStateStore? stateStore;

  /// A saját videólista tárolója; `null` esetén nincs betöltés és mentés.
  final PlaylistStore? playlistStore;

  /// Az appban módosított API-kulcsok mentési helye (Windows biztonságos
  /// tároló).
  final ApiKeyStore apiKeyStore;

  /// A futó alkalmazás verziója (`0.14.0`); `null`, ha nem ismert.
  final String? appVersion;

  /// A GitHub-kiadások figyelője; `null` esetén nincs frissítés-ellenőrzés.
  final UpdateChecker? updateChecker;

  /// A naptár eseményvezérlője (tesztekhez); `null` esetén a provider hozza
  /// létre (és szabadítja fel). A kívülről kapottat a hívó szabadítja fel.
  final UpcomingEventsController? upcomingEvents;

  /// Ablak, tálcaikon és bezárás kezelése; `null` esetén ezek kimaradnak.
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

  /// Az Összehasonlítás oldal szezonadat-forrása (tesztekhez); `null`
  /// esetén a repositorykra épülő [RepositoryCompareSource].
  final CompareDataSource? compareSource;

  /// Hírforrások és hírarchívum (tesztekhez); `null` esetén a provider
  /// hozza létre (és zárja le).
  final NewsRepository? newsRepository;

  /// A kiemelések tárolója; `null` esetén [AthleteHighlightStore.shared].
  final AthleteHighlightStore? highlightStore;

  /// A közös HTTP-réteg; `null` esetén [HttpService.shared].
  final HttpService? http;

  /// Az adatréteg providereinek felülírásai a megadott szolgáltatásokkal
  /// (a meg nem adottak az alapértelmezett providert használják).
  List<Override> get overrides => [
    notificationServiceProvider.overrideWithValue(notificationService),
    if (http case final http?) httpServiceProvider.overrideWithValue(http),
    if (highlightStore case final store?)
      highlightStoreProvider.overrideWithValue(store),
    if (newsRepository case final news?)
      newsRepositoryProvider.overrideWithValue(news),
    if (compareSource case final source?)
      compareSourceProvider.overrideWithValue(source),
    if (upcomingEvents case final controller?)
      upcomingEventsControllerProvider.overrideWithValue(controller),
  ];
}
