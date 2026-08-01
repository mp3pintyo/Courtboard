// ignore_for_file: avoid_print

import 'package:courtboard/data/api_sports.dart';
import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/darts.dart';
import 'package:courtboard/data/espn_liga_f.dart';
import 'package:courtboard/data/local_state.dart';
import 'package:courtboard/data/multi_provider.dart';
import 'package:courtboard/data/rapidapi_wnba.dart';
import 'package:courtboard/data/sports_api.dart';

Future<void> main(List<String> arguments) async {
  final athleteName = arguments.isEmpty ? 'Nikola Jokić' : arguments.join(' ');
  final saved = await LocalStateStore().load();
  final environment = SportsApiConfig.fromEnvironment();
  final config = SportsApiConfig(
    apiSportsKey: saved.apiSportsKey.isNotEmpty
        ? saved.apiSportsKey
        : environment.apiSportsKey,
    balldontlieKey: saved.balldontlieKey.isNotEmpty
        ? saved.balldontlieKey
        : environment.balldontlieKey,
    footballDataKey: saved.footballDataKey.isNotEmpty
        ? saved.footballDataKey
        : environment.footballDataKey,
    youtubeKey: environment.youtubeKey,
    rapidApiDartsKey: saved.rapidApiDartsKey.isNotEmpty
        ? saved.rapidApiDartsKey
        : environment.rapidApiDartsKey,
  );

  final data =
      await MultiProviderAthleteRepository(config).fetchNbaPlayer(athleteName);
  print('NBA ellenőrzés: $athleteName');
  for (final provider in data.providers) {
    final state = provider.hasData
        ? 'OK'
        : provider.configured
            ? 'HIBA/NINCS TALÁLAT'
            : 'NINCS KULCS';
    print('- ${provider.name}: $state');
  }
  for (final fact in data.facts) {
    print('- ${fact.label}: ${fact.value} (${fact.source})');
  }
  print('NBA meccsnapló: ${data.games.length} mérkőzés');
  for (final game in data.games) {
    print('- ${game.date.toIso8601String().split('T').first}: '
        '${game.opponent}, ${game.resultLabel}, ${game.performance}');
  }
  if (data.facts.isEmpty) {
    throw StateError('Egyik szolgáltató sem adott NBA-játékosadatot.');
  }

  final wnbaGames = await BasketballReferenceRepository()
      .recentGames('Dorka Juhász', league: 'wnba');
  print('WNBA Basketball Reference ellenőrzés: ${wnbaGames.length} mérkőzés');
  for (final game in wnbaGames) {
    print('- ${game.date.toIso8601String().split('T').first}: '
        '${game.opponent}, ${game.score ?? game.resultLabel}, ${game.performance}');
  }
  if (wnbaGames.isEmpty) {
    throw StateError('A Basketball Reference nem adott WNBA-meccsnaplót.');
  }

  if (config.apiSportsKey.isNotEmpty) {
    final games = await ApiSportsRepository(config.apiSportsKey)
        .footballRecent('FC Barcelona');
    print('Foci ellenőrzés: ${games.length} API-Sports mérkőzés');
    if (games.isNotEmpty) {
      print('- ${games.first.date.toIso8601String()}: '
          '${games.first.opponent} ${games.first.score}');
    }
  }

  final darts = await DartsRepository(config).fetch('Luke Littler');
  print('Darts ellenőrzés: ${darts.player?['strPlayer'] ?? 'nincs profil'}');
  print('- TheSportsDB eredmények: ${darts.results.length}');
  for (final result in darts.results) {
    print('- ${result.date.toIso8601String().split('T').first}: '
        '${result.event}, ${result.detail}');
  }
  print('- RapidAPI versenyek: ${darts.competitions.length} '
      '(${darts.rapidApiConfigured ? 'kulcs beállítva' : 'kulcs nincs beállítva'})');
  if (darts.player == null || darts.results.isEmpty) {
    throw StateError('A TheSportsDB nem adott használható darts adatot.');
  }

  final ligaFGames = await LigaFRepository().recentBarcelonaGames();
  print('Liga F ESPN ellenőrzés: ${ligaFGames.length} Barcelona-meccs');
  for (final game in ligaFGames) {
    print('- ${game.date.toIso8601String().split('T').first}: '
        '${game.opponent}, ${game.score}, ${game.result}');
  }
  if (ligaFGames.isEmpty) {
    throw StateError('Az ESPN esp.w.1 nem adott Barcelona-meccseket.');
  }

  if (config.rapidApiDartsKey.isNotEmpty) {
    final rapidWnba =
        await WnbaRapidApiRepository(config).playerProfile('Caitlin Clark');
    print('RapidAPI WNBA ellenőrzés: '
        '${rapidWnba?.team ?? 'nincs profil'}, ${rapidWnba?.facts.length ?? 0} mutató');
    if (rapidWnba == null || rapidWnba.facts.isEmpty) {
      throw StateError('A RapidAPI WNBA nem adott advanced stat adatot.');
    }
  }
}
