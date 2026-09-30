// Billentyűparancsok a shell szintjén: Ctrl+1…7 navigáció, Esc / Alt+Bal
// vissza a profilból, Ctrl+F a keresőmezőre, Ctrl+N új sportoló.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:courtboard/main.dart';

void _desktopView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool alt = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

EditableText _focusedEditable() {
  final context = FocusManager.instance.primaryFocus?.context;
  expect(context, isNotNull, reason: 'nincs fókuszban lévő elem');
  final editable =
      context!.findAncestorWidgetOfExactType<EditableText>() ??
      (context.widget is EditableText ? context.widget as EditableText : null);
  expect(editable, isNotNull, reason: 'a fókusz nem szövegmezőn van');
  return editable!;
}

void main() {
  testWidgets('Ctrl+2 opens the athlete directory, Ctrl+1 returns', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.digit2, control: true);
    expect(find.byKey(const Key('athlete-directory-search')), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.digit7, control: true);
    expect(find.byKey(const Key('shortcut-list')), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.digit1, control: true);
    expect(find.text('A te személyes sportközpontod'), findsOneWidget);
  });

  testWidgets('Esc and Alt+Left go back from a profile', (tester) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    expect(find.text('A te személyes sportközpontod'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('athlete-Luke Humphries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowLeft, alt: true);
    expect(find.byKey(const Key('profile-hero')), findsNothing);
  });

  testWidgets('Esc closes a dialog without leaving the profile', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('athlete-Nikola Jokić')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-delete-athlete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-athlete-dialog')), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const Key('delete-athlete-dialog')), findsNothing);
    expect(find.byKey(const Key('profile-hero')), findsOneWidget);

    // A törlés megerősítés után történik meg.
    await tester.tap(find.byKey(const Key('profile-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-delete-athlete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-athlete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-hero')), findsNothing);
    expect(find.byKey(const ValueKey('athlete-Nikola Jokić')), findsNothing);
  });

  testWidgets('Ctrl+F focuses the search field of the visible page', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.keyF, control: true);
    expect(_focusedEditable().focusNode.debugLabel, 'dashboard-search');

    await _press(tester, LogicalKeyboardKey.digit2, control: true);
    await _press(tester, LogicalKeyboardKey.keyF, control: true);
    expect(_focusedEditable().focusNode.debugLabel, 'directory-search');

    // Keresőmező nélküli oldalról az Áttekintés keresőjére ugrik.
    await _press(tester, LogicalKeyboardKey.digit3, control: true);
    await _press(tester, LogicalKeyboardKey.keyF, control: true);
    expect(_focusedEditable().focusNode.debugLabel, 'dashboard-search');
    expect(find.text('A te személyes sportközpontod'), findsOneWidget);
  });

  testWidgets('Ctrl+N opens the add-athlete dialog', (tester) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.keyN, control: true);
    expect(find.byKey(const Key('add-athlete-submit')), findsOneWidget);
  });

  testWidgets('rail collapses to icons and remembers the choice', (
    tester,
  ) async {
    _desktopView(tester);
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    expect(find.text('Sportolók'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rail-collapse')));
    await tester.pumpAndSettle();
    expect(find.text('Sportolók'), findsNothing);
    expect(find.byKey(const ValueKey('nav-Sportolók')), findsOneWidget);
    expect(find.byTooltip('Sportolók (Ctrl+2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rail-expand')));
    await tester.pumpAndSettle();
    expect(find.text('Sportolók'), findsOneWidget);
  });

  testWidgets('narrow window uses a navigation drawer', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(720, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const CourtboardApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-Hírek')), findsNothing);
    await tester.tap(find.byKey(const Key('open-navigation-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-Naptár')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-empty-state')), findsOneWidget);
  });
}
