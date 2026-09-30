// Reszponzív elrendezés: a fő oldalak kis ablakban (800×600), keskeny
// (fiókos) ablakban és 1,3-es szövegnagyítással sem csordulnak túl.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/app/courtboard_app.dart';

const _state = CourtboardLocalState(
  customAthletes: [
    CustomAthlete(
      name: 'Juhász Dorka',
      sport: 'WNBA',
      team: 'Minnesota Lynx',
      country: 'Magyarország',
    ),
  ],
);

/// Néhány képkocka (a betöltési helyőrzők animációja miatt nem
/// `pumpAndSettle`).
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openNav(WidgetTester tester, String label) async {
  final menu = find.byKey(const Key('open-navigation-drawer'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await _frames(tester);
  }
  await tester.tap(find.byKey(ValueKey('nav-$label')).last);
  await _frames(tester);
}

void _expectNoLayoutError(WidgetTester tester, String where) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$where: $error');
}

void main() {
  for (final (size, scale) in const [
    (Size(800, 600), 1.0),
    (Size(800, 600), 1.3),
    (Size(1100, 800), 1.3),
    (Size(720, 800), 1.0),
    (Size(720, 800), 1.3),
    (Size(1600, 900), 1.3),
  ]) {
    testWidgets(
      'main pages fit at ${size.width.toInt()}x${size.height.toInt()} '
      'with text scale $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        await tester.pumpWidget(const CourtboardApp(initialState: _state));
        await _frames(tester);
        _expectNoLayoutError(tester, 'Áttekintés');

        for (final label in const [
          'Sportolók',
          'Naptár',
          'Hírek',
          'Videók',
          'Követés',
          'Összehasonlítás',
          'Adatforrások',
          'Beállítások',
        ]) {
          await _openNav(tester, label);
          _expectNoLayoutError(tester, label);
        }

        for (final name in const [
          'Nikola Jokić',
          'Juhász Dorka',
          'Luke Humphries',
          'Aitana Bonmatí',
          'Saquon Barkley',
        ]) {
          await _openNav(tester, 'Sportolók');
          // A lista görgetési helyzete a router ágában megmarad (0.13.0):
          // a keresés a lista tetejéről indul.
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .jumpTo(0);
          await tester.pump();
          final tile = find.byKey(ValueKey('directory-athlete-$name'));
          await tester.scrollUntilVisible(
            tile,
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.ensureVisible(tile);
          await tester.pump();
          await tester.tap(tile);
          await _frames(tester);
          _expectNoLayoutError(tester, 'profil: $name');
          expect(find.byKey(const Key('profile-hero')), findsOneWidget);
        }

        // Lebontás, hogy ne maradjon függő animáció.
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
