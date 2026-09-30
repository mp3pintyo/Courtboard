// ignore_for_file: avoid_print

import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:courtboard/data/wehoop_wnba.dart';

Future<void> main() async {
  const athleteName = 'Juhász Dorka';
  final wehoop = WnbaWehoopRepository();
  try {
    final games = await wehoop.recentGames(athleteName);
    final playerId = games.isEmpty ? '' : games.first.athleteId;
    print('$athleteName → ${games.length} wehoop meccs → ESPN ID $playerId');
    if (playerId != '4398938') {
      throw StateError('Hibás ESPN-azonosító: $playerId');
    }
  } finally {
    wehoop.close();
  }

  // Flutter-motor nélkül a biztonságos tároló nem érhető el: a kulcs a
  // RAPIDAPI_KEY / RAPIDAPI_DARTS_KEY változóból vagy a régi állapotfájlból jön.
  final saved = await LocalStateStore().load();
  final config = SportsApiConfig.fromEnvironment().withKeys(
    saved.legacyApiKeys,
  );
  if (config.rapidApiKey.isEmpty) {
    throw StateError('A RapidAPI kulcs nincs beállítva (RAPIDAPI_KEY).');
  }
  final profile = await WnbaRapidApiRepository(
    config,
  ).playerProfile(athleteName);
  if (profile == null) {
    throw StateError('A RapidAPI profil nem töltődött be.');
  }
  print(
    'RapidAPI → ESPN ID ${profile.playerId} → '
    '${profile.team ?? 'nincs csapat'} → ${profile.facts.length} mutató',
  );
}
