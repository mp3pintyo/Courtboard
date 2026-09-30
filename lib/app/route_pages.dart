/// Az útvonalak oldalai: a providerekből (állapot, repositoryk) és a
/// shell műveleteiből ([ShellScope]) állítják össze a funkciók
/// megjelenítő widgetjeit. A funkciók így nem ismerik a routert.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:courtboard/app/app_location.dart';
import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/app/courtboard_shell.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/domain/athlete_targets.dart';
import 'package:courtboard/features/athletes/athlete_directory_page.dart';
import 'package:courtboard/features/calendar/calendar_page.dart';
import 'package:courtboard/features/compare/compare_data.dart';
import 'package:courtboard/features/compare/compare_page.dart';
import 'package:courtboard/features/dashboard/dashboard_page.dart';
import 'package:courtboard/features/data_sources/data_sources_page.dart';
import 'package:courtboard/features/follow_feed/follow_feed_page.dart';
import 'package:courtboard/features/news/news_page.dart';
import 'package:courtboard/features/profile/profile_page.dart';
import 'package:courtboard/features/settings/desktop_settings.dart';
import 'package:courtboard/features/settings/settings_page.dart';
import 'package:courtboard/features/videos/video_library_page.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// Egy menüpont oldala (a router ágának gyökérútvonala).
class RoutePage extends StatelessWidget {
  const RoutePage({super.key, required this.page, required this.state});

  final AppPage page;
  final GoRouterState state;

  @override
  Widget build(BuildContext context) => switch (page) {
    AppPage.overview => const _OverviewRoute(),
    AppPage.athletes => const _AthletesRoute(),
    AppPage.calendar => const _CalendarRoute(),
    AppPage.news => const _NewsRoute(),
    AppPage.videos => const _VideosRoute(),
    AppPage.feed => const _FeedRoute(),
    AppPage.compare => _CompareRoute(
      left: state.uri.queryParameters['a'],
      right: state.uri.queryParameters['b'],
    ),
    AppPage.dataSources => const _DataSourcesRoute(),
    AppPage.settings => const _SettingsRoute(),
  };
}

class _OverviewRoute extends ConsumerWidget {
  const _OverviewRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final activity = ref.watch(activityControllerProvider);
    final shell = ShellScope.of(context);
    final athletes = app.athletes;
    return DashboardPage(
      athletes: athletes,
      highlights: activity.highlights,
      sort: app.overviewSort,
      onOpenSettings: () => shell.open(AppPage.settings),
      onOpen: shell.openProfile,
      onAddAthlete: () => unawaited(shell.addAthlete()),
      onOpenNews: () => shell.open(AppPage.news),
      onOpenVideos: () => shell.open(AppPage.videos),
      pinned: app.pinned.toSet(),
      onTogglePin: shell.togglePin,
      onCompare: shell.openCompare,
      feed: activity.feedItems(),
      onOpenFeed: () => shell.open(AppPage.feed),
      liveTargets: calendarTargets(athletes),
    );
  }
}

class _AthletesRoute extends ConsumerWidget {
  const _AthletesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final shell = ShellScope.of(context);
    return AthleteDirectoryPage(
      athletes: app.athletes,
      sort: app.athleteSort,
      onOpen: shell.openProfile,
      onAdd: () => unawaited(shell.addAthlete()),
      onReorder: app.reorderAthletes,
    );
  }
}

/// A sportoló profilja (`/sportolok/:athleteId`). Ha a sportoló közben
/// megszűnt (törlés), üres helyet ad (a shell már visszanavigált).
class ProfileRoutePage extends ConsumerWidget {
  const ProfileRoutePage({super.key, required this.athleteId, this.origin});

  final String athleteId;

  /// A menüpont, ahonnan a profilt megnyitották (`from=`).
  final AppPage? origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final athlete = app.athleteById(athleteId);
    if (athlete == null) return const SizedBox.shrink();
    final shell = ShellScope.of(context);
    return ProfilePage(
      key: ValueKey(athlete.name),
      athlete: athlete,
      backLabel: (origin ?? AppPage.athletes).backLabel,
      videos: app.playlist.forAthlete(athlete.name),
      note: app.noteFor(athlete),
      alertEnabled: app.alertEnabled(athlete),
      onBack: shell.closeProfile,
      onToggleClip: app.removeVideo,
      onAddVideo: () => unawaited(shell.addVideo(athlete)),
      onDelete: () => unawaited(shell.confirmDeleteAthlete(athlete)),
      onSaveNote: app.setNote,
      onToggleAlert: app.toggleAlert,
      pinned: app.isPinned(athlete),
      onTogglePin: () => shell.togglePin(athlete),
      onCompare: () => shell.openCompare(athlete),
    );
  }
}

class _CalendarRoute extends ConsumerWidget {
  const _CalendarRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(
      appControllerProvider.select((app) => app.athletes),
    );
    return CalendarPage(
      athletes: athletes,
      controller: ref.watch(upcomingEventsControllerProvider),
      config: ref.watch(apiConfigProvider),
    );
  }
}

class _NewsRoute extends ConsumerWidget {
  const _NewsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(
      appControllerProvider.select((app) => app.athletes),
    );
    return NewsPage(
      athletes: [
        for (final athlete in athletes)
          NewsAthleteRef(name: athlete.name, sport: athlete.sport.jsonValue),
      ],
    );
  }
}

class _VideosRoute extends ConsumerWidget {
  const _VideosRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final shell = ShellScope.of(context);
    return VideoLibraryPage(
      athletes: app.athletes,
      playlist: app.playlist,
      onOpenAthlete: shell.openProfile,
      onRemoveVideo: app.removeVideo,
      onOpenAthletes: () => shell.open(AppPage.athletes),
    );
  }
}

class _FeedRoute extends ConsumerWidget {
  const _FeedRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final activity = ref.watch(activityControllerProvider);
    final shell = ShellScope.of(context);
    return FollowFeedPage(
      items: activity.feedItems(),
      athletes: app.athletes,
      onOpenAthlete: shell.openProfile,
      onRefresh: activity.refreshFeed,
    );
  }
}

/// Összehasonlítás (`/osszehasonlitas?a=<id>&b=<id>`): a kiválasztás az
/// útvonalban él.
class _CompareRoute extends ConsumerWidget {
  const _CompareRoute({this.left, this.right});

  /// A bal és a jobb oldali sportoló azonosítója ([Athlete.id]).
  final String? left;
  final String? right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final shell = ShellScope.of(context);
    String? nameOf(String? id) => id == null ? null : app.athleteById(id)?.name;
    String? idOf(String? name) =>
        name == null ? null : app.athleteNamed(name)?.id;
    return ComparePage(
      athletes: app.athletes,
      config: ref.watch(apiConfigProvider),
      source: ref.watch(compareSourceProvider),
      initialAthlete: nameOf(left),
      initialOpponent: nameOf(right),
      onOpenAthlete: shell.openProfile,
      onSelectionChanged: (left, right) =>
          shell.compareSelectionChanged(idOf(left), idOf(right)),
    );
  }
}

class _DataSourcesRoute extends ConsumerWidget {
  const _DataSourcesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    return DataSourcesPage(
      config: app.apiConfig,
      secureStorageAvailable: app.secureStorageAvailable,
      onSaveKey: (id, value) => unawaited(app.saveApiKey(id, value)),
    );
  }
}

class _SettingsRoute extends ConsumerWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final desktop = ref.watch(desktopCoordinatorProvider);
    final notifications = ref.watch(notificationServiceProvider);
    final startup = ref.watch(startupRegistrationProvider);
    final integration = ref.watch(desktopIntegrationProvider);
    final paused = app.notificationsPaused;
    final startupSupported = desktop.startupSupported;
    return SettingsPage(
      theme: app.theme,
      themeMode: app.themeMode,
      onThemeModeChanged: app.setThemeMode,
      overviewSort: app.overviewSort,
      athleteSort: app.athleteSort,
      onThemeChanged: app.setTheme,
      onOverviewSortChanged: app.setOverviewSort,
      onAthleteSortChanged: app.setAthleteSort,
      appVersion: ref.watch(appVersionProvider),
      autoUpdateCheck: app.autoUpdateCheck,
      onAutoUpdateCheckChanged: app.setAutoUpdateCheck,
      updateResult: app.updateResult,
      onCheckUpdatesNow: app.updateChecker == null
          ? null
          : () => app.checkForUpdates(force: true),
      notificationSettings: NotificationSettingsCard(
        settings: app.notificationSettings,
        onChanged: app.setNotificationSettings,
        alertAthleteCount: app.alertAthletes.length,
        serviceDescription: notifications?.available == true
            ? notifications!.description
            : null,
        pausedUntil: paused ? app.notificationsPausedUntil : null,
        onResume: paused ? app.toggleNotificationPause : null,
        onTest: notifications == null ? null : desktop.sendTestNotification,
      ),
      desktopSettings: DesktopSettingsCard(
        closeToTray: app.closeToTray,
        onCloseToTrayChanged: integration?.trayAvailable == true
            ? app.setCloseToTray
            : null,
        launchAtStartup: desktop.launchAtStartup,
        onLaunchAtStartupChanged: startupSupported
            ? (value) => unawaited(desktop.setLaunchAtStartup(value))
            : null,
        startMinimized: app.startMinimized,
        onStartMinimizedChanged: startupSupported
            ? (value) => unawaited(desktop.setStartMinimized(value))
            : null,
        startupUnavailableReason: startup != null && !startup.supported
            ? startup.unsupportedReason
            : null,
        desktopAvailable: integration != null,
      ),
    );
  }
}

/// Ismeretlen útvonal (nem fordulhat elő a felületről): üres vászon és
/// ugrás az Áttekintésre.
class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.cb.canvas,
    child: Center(
      child: TextButton(
        onPressed: () =>
            GoRouter.of(context).go(AppLocation.overview.page.path),
        child: const Text('Vissza az Áttekintésre'),
      ),
    ),
  );
}
