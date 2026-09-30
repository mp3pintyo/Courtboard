import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:courtboard/data/local_state.dart';

void main() {
  test('local state persists notes, alerts, and custom athletes', () async {
    final file =
        File('${Directory.systemTemp.path}/courtboard_state_test.json');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final store = LocalStateStore(file: file);
    await store.save(const CourtboardLocalState(
      notes: {'Nikola Jokić': 'Figyeld a lepattanó trendet.'},
      alerts: {'Nikola Jokić': true},
      removedAthleteNames: {'Saquon Barkley'},
      rapidApiDartsKey: 'rapid-test-key',
      liveTennisKey: 'tennis-test-key',
      theme: 'burgundy',
      overviewSort: 'sport',
      athleteSort: 'name',
      customAthletes: [
        CustomAthlete(name: 'Teszt Játékos', sport: 'Foci', team: 'Teszt FC')
      ],
    ));

    final restored = await store.load();
    expect(restored.notes['Nikola Jokić'], 'Figyeld a lepattanó trendet.');
    expect(restored.alerts['Nikola Jokić'], isTrue);
    expect(restored.removedAthleteNames, contains('Saquon Barkley'));
    expect(restored.customAthletes.single.name, 'Teszt Játékos');
    expect(restored.rapidApiDartsKey, 'rapid-test-key');
    expect(restored.liveTennisKey, 'tennis-test-key');
    expect(restored.theme, 'burgundy');
    expect(restored.overviewSort, 'sport');
    expect(restored.athleteSort, 'name');
  });

  test('corrupt state file is preserved before defaults are returned',
      () async {
    final directory = await Directory.systemTemp.createTemp('courtboard-ls-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/courtboard_state.json');
    await file.writeAsString('{"notes": {"Jokić": "félbe');

    final store = LocalStateStore(file: file);
    final restored = await store.load();

    expect(restored.notes, isEmpty);
    final backup = store.lastCorruptBackup;
    expect(backup, isNotNull);
    expect(backup!.uri.pathSegments.last,
        matches(RegExp(r'^courtboard_state\.corrupt-\d+\.json$')));
    expect(await backup.readAsString(), '{"notes": {"Jokić": "félbe');

    // A következő mentés már nem semmisíti meg a sérült tartalmat.
    await store.save(const CourtboardLocalState(theme: 'blue'));
    expect(await backup.exists(), isTrue);
    expect((await store.load()).theme, 'blue');
  });

  test('concurrent saves run in order and the last state wins', () async {
    final directory = await Directory.systemTemp.createTemp('courtboard-ls-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/courtboard_state.json');
    final store = LocalStateStore(file: file);

    await Future.wait([
      for (var i = 0; i < 20; i++)
        store.save(CourtboardLocalState(notes: {'index': '$i'})),
    ]);

    expect((await store.load()).notes['index'], '19');
    final leftovers = directory
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .where((name) => name != 'courtboard_state.json');
    expect(leftovers, isEmpty);
  });

  test('custom athlete order round-trips through JSON', () {
    const state = CourtboardLocalState(
      athleteOrder: ['Saquon Barkley', 'Nikola Jokić'],
    );
    final restored = CourtboardLocalState.fromJson(state.toJson());
    expect(restored.athleteOrder, ['Saquon Barkley', 'Nikola Jokić']);
    expect(CourtboardLocalState.fromJson(const {}).athleteOrder, isEmpty);
  });
}
