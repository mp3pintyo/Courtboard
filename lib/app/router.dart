/// A `go_router` útvonalai: egy [StatefulShellRoute] a menüpontok ágaival
/// (az oldalsáv a shellben marad, az ágak állapota — görgetés, szűrők —
/// oldalváltáskor megmarad), és a profil a Sportolók ág alatt.
///
/// Az útvonalak táblázatát lásd: [AppLocation]. A lapok átmenet nélkül
/// váltanak (mint a 0.13.0 előtt).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:courtboard/app/app_location.dart';
import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/app/courtboard_shell.dart';
import 'package:courtboard/app/providers.dart';
import 'package:courtboard/app/route_pages.dart';

/// Az alkalmazás routere (a [ProviderScope] élettartamáig).
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.read(appLaunchProvider).initialLocation,
    // Ismeretlen (például közben törölt) sportoló profilja helyett a
    // Sportolók oldal.
    redirect: (context, state) {
      final location = AppLocation.parse(state.uri);
      final id = location.athleteId;
      if (id == null) return null;
      final exists = ref.read(appControllerProvider).athleteById(id) != null;
      return exists ? null : AppPage.athletes.path;
    },
    errorPageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: const UnknownRoutePage(),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) =>
            NoTransitionPage<void>(
              key: state.pageKey,
              child: CourtboardShell(
                navigationShell: navigationShell,
                location: AppLocation.parse(state.uri),
              ),
            ),
        branches: [
          for (final page in AppPage.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: page.path,
                  pageBuilder: (context, state) => NoTransitionPage<void>(
                    key: state.pageKey,
                    child: RoutePage(page: page, state: state),
                  ),
                  routes: [
                    if (page == AppPage.athletes)
                      GoRoute(
                        path: ':athleteId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          key: state.pageKey,
                          child: ProfileRoutePage(
                            athleteId: state.pathParameters['athleteId']!,
                            origin: AppPage.fromSlug(
                              state.uri.queryParameters['from'],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}, name: 'routerProvider');
