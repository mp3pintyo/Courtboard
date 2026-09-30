// A go_router útvonalai: billentyűparancsos navigáció, közvetlen útvonal a
// profilra, a „Vissza” felirat a kiinduló menüpontból, az ágak állapotának
// megőrzése, értesítésből nyíló profil és az Összehasonlítás paraméterei.
import 'package:courtboard/app/app_location.dart';
import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/app/courtboard_app.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';
import 'support/fake_desktop.dart';

const _twoNbaPlayers = CourtboardLocalState(
  customAthletes: [
    CustomAthlete(
      name: 'LeBron James',
      sport: 'NBA',
      team: 'Los Angeles Lakers',
    ),
  ],
);

String _backLabel(WidgetTester tester) {
  final button = find.byKey(const Key('profile-back'));
  return tester
      .widget<Text>(find.descendant(of: button, matching: find.byType(Text)))
      .data!;
}

void main() {
  group('AppLocation', () {
    test('parses the route table', () {
      expect(AppLocation.parse(Uri.parse('/')).page, AppPage.overview);
      for (final page in AppPage.values) {
        final location = AppLocation.parse(Uri.parse(page.path));
        expect(location.page, page);
        expect(location.isProfile, isFalse);
      }
      final profile = AppLocation.parse(
        Uri.parse('/sportolok/nikola-jokic?from=kovetes'),
      );
      expect(profile.isProfile, isTrue);
      expect(profile.athleteId, 'nikola-jokic');
      expect(profile.origin, AppPage.feed);
      expect(profile.highlighted, AppPage.feed);
      expect(
        AppLocation.parse(Uri.parse('/sportolok/x')).highlighted,
        AppPage.athletes,
      );
      expect(
        AppLocation.parse(Uri.parse('/ismeretlen')).page,
        AppPage.overview,
      );
    });

    test('builds profile and compare paths', () {
      expect(
        AppLocation.profilePath('nikola-jokic', from: AppPage.overview),
        '/sportolok/nikola-jokic?from=attekintes',
      );
      expect(AppLocation.profilePath('x'), '/sportolok/x');
      expect(AppLocation.comparePath(), '/osszehasonlitas');
      expect(
        AppLocation.comparePath(left: 'a', right: 'b'),
        '/osszehasonlitas?a=a&b=b',
      );
    });

    test('every page has a unique path and shortcut digit', () {
      expect(AppPage.values.map((p) => p.path).toSet(), hasLength(9));
      expect(AppPage.values.map((p) => p.shortcutDigit), [
        1, 2, 3, 4, 5, 6, 7, 8, 9, //
      ]);
      expect(AppPage.fromSlug('naptar'), AppPage.calendar);
      expect(AppPage.fromSlug('nincs'), isNull);
    });
  });

  testWidgets('Ctrl+1…9 navigate through the router branches', (tester) async {
    desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/');

    for (final page in AppPage.values.reversed) {
      await pressKey(
        tester,
        LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + page.index),
        control: true,
        settle: false,
      );
      expect(appLocation(tester), page.path, reason: page.name);
      expect(railActive(tester), page);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a deep route opens the profile with the origin as back label', (
    tester,
  ) async {
    desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(
        initialLocation: '/sportolok/nikola-jokic?from=kovetes',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-hero')), findsOneWidget);
    expect(find.text('Nikola Jokić'), findsWidgets);
    expect(_backLabel(tester), 'Vissza: Követés');
    // A kiinduló menüpont marad kiemelve.
    expect(railActive(tester), AppPage.feed);

    // Esc: vissza a kiinduló ágra.
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(appLocation(tester), AppPage.feed.path);
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    expect(find.byKey(const Key('feed-refresh')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a deep route without origin falls back to the directory', (
    tester,
  ) async {
    desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(initialLocation: '/sportolok/luke-humphries'),
    );
    await tester.pumpAndSettle();
    expect(_backLabel(tester), 'Vissza: Sportolók');
    expect(railActive(tester), AppPage.athletes);

    await tester.tap(find.byKey(const Key('profile-back')));
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok');
    expect(find.byKey(const Key('athlete-directory-search')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unknown athlete id redirects to the directory', (
    tester,
  ) async {
    desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(initialLocation: '/sportolok/nincs-ilyen'),
    );
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok');
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the profile remembers where it was opened from', (tester) async {
    desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    // Az Áttekintés kártyájáról.
    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok/nikola-jokic?from=attekintes');
    expect(_backLabel(tester), 'Vissza: Áttekintés');
    expect(railActive(tester), AppPage.overview);
    await pressKey(tester, LogicalKeyboardKey.arrowLeft, alt: true);
    expect(appLocation(tester), '/');

    // A Sportolók listájáról.
    await pressKey(tester, LogicalKeyboardKey.digit2, control: true);
    await tester.tap(
      find.byKey(const ValueKey('directory-athlete-Saquon Barkley')),
    );
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok/saquon-barkley?from=sportolok');
    expect(_backLabel(tester), 'Vissza: Sportolók');
    expect(railActive(tester), AppPage.athletes);
    await tester.tap(find.byKey(const Key('profile-back')));
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('branch state survives navigation and opening a profile', (
    tester,
  ) async {
    desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    // Szűrő és keresés az Áttekintésen.
    await tester.tap(find.widgetWithText(ChoiceChip, 'NBA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'jok');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('athlete-Nikola Jokić')), findsOneWidget);
    expect(find.byKey(const ValueKey('athlete-Luke Humphries')), findsNothing);

    // Másik ág, majd vissza: a szűrő és a keresés megmaradt.
    await pressKey(
      tester,
      LogicalKeyboardKey.digit3,
      control: true,
      settle: false,
    );
    expect(appLocation(tester), '/naptar');
    await pressKey(tester, LogicalKeyboardKey.digit1, control: true);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'NBA'))
          .selected,
      isTrue,
    );
    expect(find.text('jok'), findsOneWidget);
    expect(find.byKey(const ValueKey('athlete-Luke Humphries')), findsNothing);

    // Profil megnyitása és bezárása után is.
    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(find.text('jok'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'NBA'))
          .selected,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the athletes menu item closes an open profile', (tester) async {
    desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(
        initialLocation: '/sportolok/nikola-jokic?from=sportolok',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-Sportolók')));
    await tester.pumpAndSettle();
    expect(appLocation(tester), '/sportolok');
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    expect(find.byKey(const Key('athlete-directory-search')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a notification click opens /sportolok/<id>', (tester) async {
    desktopView(tester);
    final notifications = FakeNotificationService();
    await tester.pumpWidget(
      CourtboardApp(
        notificationService: notifications,
        watcherSource: FakeWatcherSource(),
        initialState: const CourtboardLocalState(
          alerts: {'Caitlin Clark': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pressKey(
      tester,
      LogicalKeyboardKey.digit4,
      control: true,
      settle: false,
    );
    expect(appLocation(tester), '/hirek');

    notifications.click(
      const CourtboardNotification(
        id: 'x',
        kind: CourtboardNotificationKind.result,
        title: 'Új eredmény',
        body: '',
        athleteName: 'Caitlin Clark',
      ),
    );
    await pumpFrames(tester);
    expect(appLocation(tester), '/sportolok/caitlin-clark?from=hirek');
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);

    // A „Hírek megnyitása” gomb a sportolós értesítésnél is a Hírek oldal.
    notifications.click(
      const CourtboardNotification(
        id: 'z',
        kind: CourtboardNotificationKind.news,
        title: 'Új hír: Caitlin Clark',
        body: '',
        athleteName: 'Caitlin Clark',
      ),
      action: NotificationAction.openNews,
    );
    await pumpFrames(tester);
    expect(appLocation(tester), '/hirek');

    // „Profil megnyitása”: a sportoló útvonala.
    notifications.click(
      const CourtboardNotification(
        id: 'z',
        kind: CourtboardNotificationKind.news,
        title: 'Új hír: Caitlin Clark',
        body: '',
        athleteName: 'Caitlin Clark',
      ),
      action: NotificationAction.openProfile,
    );
    await pumpFrames(tester);
    expect(appLocation(tester), '/sportolok/caitlin-clark?from=hirek');

    // Hírösszesítő sportoló nélkül: a Hírek oldal.
    notifications.click(
      const CourtboardNotification(
        id: 'y',
        kind: CourtboardNotificationKind.news,
        title: '3 új hír',
        body: '',
      ),
    );
    await pumpFrames(tester);
    expect(appLocation(tester), '/hirek');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compare selection lives in the route (a=…&b=…)', (tester) async {
    desktopView(tester);
    await tester.pumpWidget(
      const CourtboardApp(
        initialState: _twoNbaPlayers,
        initialLocation: '/osszehasonlitas?a=lebron-james&b=nikola-jokic',
      ),
    );
    await tester.pumpAndSettle();
    final left = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('compare-left')),
    );
    expect(left.initialValue, 'LeBron James');
    expect(find.text('Nikola Jokić · NBA'), findsWidgets);

    // Csere: az útvonal követi a kiválasztást.
    await tester.tap(find.byKey(const Key('compare-swap')));
    await tester.pumpAndSettle();
    expect(
      appLocation(tester),
      '/osszehasonlitas?a=nikola-jokic&b=lebron-james',
    );

    // Oldalváltás után a kiválasztás megmarad.
    await pressKey(tester, LogicalKeyboardKey.digit1, control: true);
    await pressKey(tester, LogicalKeyboardKey.digit7, control: true);
    expect(
      appLocation(tester),
      '/osszehasonlitas?a=nikola-jokic&b=lebron-james',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
