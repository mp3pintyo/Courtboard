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
}
