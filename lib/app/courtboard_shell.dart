/// Az alkalmazás kerete: oldalsáv / fiók, frissítés-sáv, billentyűparancsok
/// és a router ágai ([StatefulNavigationShell]).
///
/// Az állapot providerekben él: `appControllerProvider` (felhasználói
/// adatok, beállítások), `activityControllerProvider` (kiemelések,
/// hírfolyam, naptár) és `desktopCoordinatorProvider` (tálca, értesítések,
/// háttérfigyelő). A navigáció a routeré ([AppLocation]); a shell a
/// műveleteit ([ShellActions]) a [ShellScope]-on át adja az oldalaknak.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:courtboard/app/app_location.dart';
import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/app/navigation.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/app/shortcuts.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:courtboard/data/providers.dart';
import 'package:courtboard/domain/athlete.dart';
import 'package:courtboard/features/athletes/add_athlete_dialog.dart';
import 'package:courtboard/features/athletes/delete_athlete_dialog.dart';
import 'package:courtboard/features/settings/updates.dart';
import 'package:courtboard/features/videos/add_video_dialog.dart';
import 'package:courtboard/shared/common_ui.dart';
import 'package:courtboard/shared/components.dart';
import 'package:courtboard/shared/theme/courtboard_theme.dart';

/// A shell műveletei az oldalak számára (navigáció és közös párbeszéd-
/// ablakok). A navigáció mindig a routeren át történik.
abstract interface class ShellActions {
  /// Az aktuális útvonal.
  AppLocation get location;

  /// Ugrás egy menüpontra (oldalsáv, Ctrl+1…9, hivatkozások).
  void open(AppPage page);

  /// A sportoló profilja (`/sportolok/<id>?from=<kiemelt menüpont>`).
  void openProfile(Athlete athlete);

  /// Vissza a profilból a kiinduló menüpontra.
  void closeProfile();

  /// Az Összehasonlítás oldal a sportolóval előre kiválasztva.
  void openCompare(Athlete athlete);

  /// Az Összehasonlítás kiválasztásának rögzítése az útvonalban.
  void compareSelectionChanged(String? left, String? right);

  /// „Kitűzés” / „Kitűzés megszüntetése” (visszajelzéssel).
  void togglePin(Athlete athlete);

  /// Új sportoló (Ctrl+N).
  Future<void> addAthlete();

  /// Sportoló törlése megerősítéssel.
  Future<void> confirmDeleteAthlete(Athlete athlete);

  /// Videó hozzáadása a sportolóhoz.
  Future<void> addVideo(Athlete athlete);
}

/// A [ShellActions] elérhetővé tétele az oldalak számára.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.actions, required super.child});

  final ShellActions actions;

  /// A shell műveletei (függőség nélkül: a műveletobjektum állandó).
  static ShellActions of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'Nincs ShellScope a widgetfában.');
    return scope!.actions;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      !identical(actions, oldWidget.actions);
}

class CourtboardShell extends ConsumerStatefulWidget {
  const CourtboardShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  /// A router ágai (IndexedStack): minden menüpont saját navigátorral.
  final StatefulNavigationShell navigationShell;

  /// Az aktuális útvonal.
  final AppLocation location;

  @override
  ConsumerState<CourtboardShell> createState() => _CourtboardShellState();
}

class _CourtboardShellState extends ConsumerState<CourtboardShell>
    implements ShellActions {
  StreamSubscription<String>? _messages;
  StreamSubscription<String>? _desktopMessages;
  StreamSubscription<NotificationActivation>? _notificationClicks;

  /// Billentyűparancsok jelzései a látható oldal felé.
  final CourtboardCommands _commands = CourtboardCommands();

  /// A shell fókuszcsomópontja: a billentyűparancsok innen indulnak akkor
  /// is, ha az oldalon semmi nincs fókuszban.
  final FocusNode _shellFocus = FocusNode(debugLabel: 'courtboard-shell');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ModalRoute<Object?>? _route;

  @override
  AppLocation get location => widget.location;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appControllerProvider);
    final desktop = ref.read(desktopCoordinatorProvider);
    _messages = app.messages.listen(_showSnack);
    _desktopMessages = desktop.messages.listen(_showSnack);
    _notificationClicks = desktop.notificationOpened.listen(
      _onNotificationOpened,
    );
    unawaited(app.loadPlaylist());
    ref.read(activityControllerProvider).start();
    FocusManager.instance.addListener(_keepShellFocus);
    if (app.autoUpdateCheck && app.updateChecker != null) {
      unawaited(app.checkForUpdates());
    }
    desktop.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(covariant CourtboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.location;
    final after = widget.location;
    if (before.page != after.page || before.athleteId != after.athleteId) {
      // A rejtett ágban maradt mezőről a fókusz visszakerül a shellre (az
      // oldal nem szűnik meg, csak láthatatlan lesz).
      _shellFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepShellFocus);
    _shellFocus.dispose();
    _commands.dispose();
    unawaited(_messages?.cancel());
    unawaited(_desktopMessages?.cancel());
    unawaited(_notificationClicks?.cancel());
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Navigáció
  // ---------------------------------------------------------------------------

  GoRouter get _router => GoRouter.of(context);

  /// Egy menüpont ága. A Sportolók ágban a profil is él, ezért oda mindig a
  /// lista útvonalával lépünk (a profil bezárul, a lista állapota marad);
  /// a többi ág a legutóbbi helyén folytatódik (például az Összehasonlítás
  /// kiválasztása).
  void _goTo(AppPage page) {
    if (page == AppPage.athletes) {
      _router.go(page.path);
    } else {
      widget.navigationShell.goBranch(page.index);
    }
  }

  @override
  void open(AppPage page) {
    final wasProfile = location.isProfile;
    _goTo(page);
    final activity = ref.read(activityControllerProvider);
    if (wasProfile || page == AppPage.overview) {
      unawaited(activity.loadHighlights());
    }
    // A Hírek oldalon közben érkezett cikkek a hírfolyamba is bekerülnek.
    if (page == AppPage.overview || page == AppPage.feed) {
      unawaited(activity.loadFeedNews());
    }
  }

  @override
  void openProfile(Athlete athlete) => _router.go(
    AppLocation.profilePath(athlete.id, from: location.highlighted),
  );

  /// Vissza a profilból; a kiemelések újraolvasása, hogy a profilon most
  /// betöltött eredmény az Áttekintésen is megjelenjen.
  @override
  void closeProfile() {
    if (!location.isProfile) return;
    _goTo(location.highlighted);
    unawaited(ref.read(activityControllerProvider).loadHighlights());
  }

  @override
  void openCompare(Athlete athlete) {
    _router.go(AppLocation.comparePath(left: athlete.id));
    // Ugyanaz a hatás, mint a menüpontnál (a kiemelések frissülnek).
    unawaited(ref.read(activityControllerProvider).loadHighlights());
  }

  @override
  void compareSelectionChanged(String? left, String? right) {
    if (location.page != AppPage.compare) return;
    _router.go(AppLocation.comparePath(left: left, right: right));
  }

  /// Értesítésre kattintva: a sportoló profilja (hírösszesítőnél a Hírek).
  void _onNotificationOpened(NotificationActivation activation) {
    if (!mounted) return;
    if (activation.action == NotificationAction.openNews) {
      open(AppPage.news);
      return;
    }
    final notification = activation.notification;
    final name = notification.athleteName;
    final athlete = name == null
        ? null
        : ref.read(appControllerProvider).athleteNamed(name);
    if (athlete != null) {
      openProfile(athlete);
    } else if (notification.kind == CourtboardNotificationKind.news) {
      open(AppPage.news);
    }
  }

  // ---------------------------------------------------------------------------
  // Műveletek
  // ---------------------------------------------------------------------------

  @override
  void togglePin(Athlete athlete) {
    final pinned = ref.read(appControllerProvider).togglePin(athlete);
    _showSnack(
      pinned
          ? '${athlete.name} kitűzve: a nyitóoldalon elöl jelenik meg.'
          : '${athlete.name} kitűzése megszűnt.',
    );
  }

  @override
  Future<void> addAthlete() async {
    final app = ref.read(appControllerProvider);
    final resolveImage = ref.read(profileImageResolverProvider);
    final athlete = await AddAthleteDialog.show(
      context,
      existingNames: app.athleteNames,
      resolveImage: resolveImage,
    );
    if (athlete == null || !mounted) return;
    app.addCustomAthlete(athlete);
  }

  @override
  Future<void> confirmDeleteAthlete(Athlete athlete) =>
      DeleteAthleteDialog.show(
        context,
        athlete: athlete,
        onConfirm: () {
          ref.read(appControllerProvider).removeAthlete(athlete);
          closeProfile();
        },
      );

  @override
  Future<void> addVideo(Athlete athlete) => AddVideoDialog.show(
    context,
    athleteName: athlete.name,
    onSave: ref.read(appControllerProvider).addVideo,
  );

  // ---------------------------------------------------------------------------
  // Billentyűparancsok
  // ---------------------------------------------------------------------------

  /// Ha a fókusz „elveszik” (például egy fókuszban lévő mező eltűnik egy
  /// oldalváltáskor), visszakerül a shellre, így a billentyűparancsok mindig
  /// működnek. Nyitott párbeszédablaknál (nem aktuális útvonal) nem nyúl hozzá.
  void _keepShellFocus() {
    if (!mounted || !(_route?.isCurrent ?? true)) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        (primary == _shellFocus || primary.ancestors.contains(_shellFocus))) {
      return;
    }
    // Csak akkor vesszük vissza, ha a fókusz egy őscsomóponton (gyökér vagy
    // útvonal-hatókör) ragadt, nem egy másik widget saját mezőjén.
    if (primary != null && !_shellFocus.ancestors.contains(primary)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_route?.isCurrent ?? true)) return;
      final current = FocusManager.instance.primaryFocus;
      if (current == null || _shellFocus.ancestors.contains(current)) {
        _shellFocus.requestFocus();
      }
    });
  }

  /// Van-e keresőmező a látható oldalon (Ctrl+F).
  bool get _pageHasSearch => !location.isProfile && location.page.hasSearch;

  void _focusSearch() {
    if (_pageHasSearch && _commands.hasSearchHandler) {
      _commands.requestSearchFocus();
      return;
    }
    // Keresőmező nélküli oldalról az Áttekintés keresőjére ugrunk.
    open(AppPage.overview);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _commands.requestSearchFocus(),
    );
  }

  void _refreshPage() {
    if (_commands.hasRefreshHandler) {
      _commands.requestRefresh();
    } else {
      unawaited(ref.read(activityControllerProvider).loadHighlights());
    }
  }

  Map<Type, Action<Intent>> get _actions => {
    ShellFocusSearchIntent: CallbackAction<ShellFocusSearchIntent>(
      onInvoke: (_) {
        _focusSearch();
        return null;
      },
    ),
    ShellBackIntent: ShellAction<ShellBackIntent>(
      enabled: () => location.isProfile,
      onInvoke: closeProfile,
    ),
    ShellRefreshIntent: CallbackAction<ShellRefreshIntent>(
      onInvoke: (_) {
        _refreshPage();
        return null;
      },
    ),
    ShellNavigateIntent: CallbackAction<ShellNavigateIntent>(
      onInvoke: (intent) {
        open(intent.page);
        return null;
      },
    ),
    ShellAddAthleteIntent: CallbackAction<ShellAddAthleteIntent>(
      onInvoke: (_) {
        unawaited(addAthlete());
        return null;
      },
    ),
  };

  // ---------------------------------------------------------------------------
  // Felépítés
  // ---------------------------------------------------------------------------

  /// A látható oldal címe (keskeny ablak felső sávjához).
  String _pageTitle(WidgetRef ref) {
    final id = location.athleteId;
    if (id == null) return location.page.label;
    return ref.watch(
          appControllerProvider.select((app) => app.athleteById(id)?.name),
        ) ??
        location.highlighted.label;
  }

  @override
  Widget build(BuildContext context) {
    final railCollapsed = ref.watch(
      appControllerProvider.select((app) => app.railCollapsed),
    );
    final width = MediaQuery.sizeOf(context).width;
    final mode = ShellLayout.modeFor(width, collapsed: railCollapsed);
    final canToggle = width >= ShellLayout.fullRailBreakpoint;
    final active = location.highlighted;
    void selectFromDrawer(AppPage page) {
      _scaffoldKey.currentState?.closeDrawer();
      open(page);
    }

    return ShellScope(
      actions: this,
      child: CourtboardCommandScope(
        commands: _commands,
        child: Shortcuts(
          shortcuts: shellShortcuts,
          child: Actions(
            actions: _actions,
            child: Focus(
              focusNode: _shellFocus,
              autofocus: true,
              child: Scaffold(
                key: _scaffoldKey,
                drawer: mode == RailMode.drawer
                    ? Drawer(
                        width: 264,
                        backgroundColor: context.cb.ink,
                        child: SideRail(
                          active: active,
                          width: double.infinity,
                          onSelect: selectFromDrawer,
                        ),
                      )
                    : null,
                body: SafeArea(
                  child: Row(
                    // A tartalom mindig kitölti a teljes magasságot (rövid
                    // oldalnál sem kerül függőlegesen középre).
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mode != RailMode.drawer)
                        SideRail(
                          // A profil megnyitásakor a kiinduló menüpont marad
                          // kiemelve.
                          active: active,
                          compact: mode == RailMode.compact,
                          onToggle: canToggle
                              ? ref.read(appControllerProvider).toggleRail
                              : null,
                          onSelect: open,
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (mode == RailMode.drawer)
                              CompactTopBar(
                                title: _pageTitle(ref),
                                onMenu: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                              ),
                            const _UpdateBannerSlot(),
                            Expanded(
                              child: ContentFrame(
                                child: widget.navigationShell,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A „Új verzió érhető el” sáv (csak elérhető frissítésnél).
class _UpdateBannerSlot extends ConsumerWidget {
  const _UpdateBannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final updateResult = app.updateResult;
    if (updateResult == null || !app.showUpdateBanner) {
      return const SizedBox.shrink();
    }
    return UpdateBanner(
      result: updateResult,
      onDownload: () => unawaited(
        openExternalUrl(
          context,
          updateResult.latest?.htmlUrl ?? app.updateChecker!.releasesPage,
        ),
      ),
      onDismiss: app.dismissUpdateBanner,
    );
  }
}
