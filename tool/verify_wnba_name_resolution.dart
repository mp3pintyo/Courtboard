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

  final saved = await LocalStateStore().load();
  final environment = SportsApiConfig.fromEnvironment();
  final key = saved.rapidApiDartsKey.isNotEmpty
      ? saved.rapidApiDartsKey
      : environment.rapidApiDartsKey;
  if (key.isEmpty) {
    throw StateError('A RapidAPI kulcs nincs beállítva.');
  }
  final profile = await WnbaRapidApiRepository(
    SportsApiConfig(rapidApiDartsKey: key),
  ).playerProfile(athleteName);
  if (profile == null) {
    throw StateError('A RapidAPI profil nem töltődött be.');
  }
  print('RapidAPI → ESPN ID ${profile.playerId} → '
      '${profile.team ?? 'nincs csapat'} → ${profile.facts.length} mutató');
}
