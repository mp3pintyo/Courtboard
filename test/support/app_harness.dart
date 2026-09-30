// Közös segédek az egész appot indító widgettesztekhez: ablakméret,
// billentyűparancsok, és a Riverpod-konténer / router elérése.
import 'package:courtboard/app/app_location.dart';
import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/app/courtboard_app.dart';
import 'package:courtboard/app/navigation.dart';
import 'package:courtboard/app/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Asztali ablakméret (alapból 1440×900, 1-es pixelaránnyal).
void desktopView(WidgetTester tester, {Size size = const Size(1440, 900)}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Egy billentyű (Ctrl / Alt módosítóval), majd a képkockák leülepedése.
/// A [settle] hamis értékénél csak néhány képkocka (a betöltési animációt
/// mutató oldalakon, például Hírek, Naptár).
Future<void> pressKey(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool alt = false,
  bool settle = true,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpFrames(tester);
  }
}

/// Néhány képkocka (a betöltési helyőrzők animációja miatt nem
/// `pumpAndSettle`).
Future<void> pumpFrames(WidgetTester tester, {int count = 5}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Az app `ProviderScope`-jának konténere (a [CourtboardRoot] fölött).
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CourtboardRoot)));

/// Az app routere.
GoRouter appRouter(WidgetTester tester) =>
    appContainer(tester).read(routerProvider);

/// Az aktuális útvonal (`/sportolok/nikola-jokic?from=attekintes`).
String appLocation(WidgetTester tester) =>
    appRouter(tester).state.uri.toString();

/// Az aktuális útvonal értelmezve.
AppLocation parsedLocation(WidgetTester tester) =>
    AppLocation.parse(appRouter(tester).state.uri);

/// Az oldalsáv kiemelt menüpontja.
AppPage railActive(WidgetTester tester) =>
    tester.widget<SideRail>(find.byType(SideRail)).active;
