// ignore_for_file: avoid_print

import 'dart:io';

import 'package:courtboard/data/basketball_reference.dart';

Future<void> main() async {
  final cache = await Directory.systemTemp.createTemp('courtboard-br-live-');
  try {
    final repository = BasketballReferenceRepository(cacheDirectory: cache);
    for (final request in const [
      ('Nikola Jokić', 'nba'),
      ('Dorka Juhász', 'wnba'),
    ]) {
      final games = await repository.recentGames(
        request.$1,
        league: request.$2,
      );
      print(
          '${request.$2.toUpperCase()} · ${request.$1}: ${games.length} meccs');
      for (final game in games) {
        print('- ${game.date.toIso8601String().split('T').first} · '
            '${game.opponent} · ${game.score ?? game.resultLabel} · '
            '${game.performance}');
      }
      if (games.isEmpty) {
        throw StateError('${request.$1}: nincs feldolgozott mérkőzés.');
      }
    }
  } finally {
    if (await cache.exists()) await cache.delete(recursive: true);
  }
}
