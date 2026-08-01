import 'dart:io';

import 'package:courtboard/data/basketball_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basketball Reference parser returns newest games first', () {
    final games = BasketballReferenceRepository.parseGames({
      'games': [
        {
          'date': '2026-04-08',
          'opponent': 'Memphis Grizzlies',
          'outcome': 'WIN',
          'location': 'HOME',
          'minutes': 31.0,
          'points': 14,
          'rebounds': 16,
          'assists': 10,
          'steals': 2,
          'blocks': 0,
          'game_score': 23.4,
          'plus_minus': 24,
        },
        {
          'date': '2026-04-12',
          'opponent': 'San Antonio Spurs',
          'outcome': 'WIN',
          'location': 'AWAY',
          'minutes': 18.3,
          'points': 23,
          'rebounds': 8,
          'assists': 1,
          'steals': 0,
          'blocks': 1,
          'game_score': 22.4,
          'plus_minus': 6,
          'score': '104-72',
        }
      ]
    });

    expect(games.first.opponent, 'San Antonio Spurs');
    expect(games.first.performance, '23 PTS · 8 REB · 1 AST · 18 MIN');
    expect(games.first.resultLabel, 'GYŐZELEM');
    expect(games.first.grade, 'A');
    expect(games.first.score, '104-72');
  });

  test('NBA season end year rolls over in September', () {
    expect(BasketballReferenceRepository.seasonEndYear(DateTime(2026, 8, 1)),
        2026);
    expect(BasketballReferenceRepository.seasonEndYear(DateTime(2026, 10, 1)),
        2027);
  });

  test('direct Dart parser merges regular season and playoff tables', () {
    final games = BasketballReferenceRepository.parseNbaGameLogHtml('''
      <table id="player_game_log_reg"><tbody>
        <tr>
          <th data-stat="date">2025-04-10</th>
          <td data-stat="game_location">@</td>
          <td data-stat="opp_name_abbr">LAL</td>
          <td data-stat="game_result">W, 120-108</td>
          <td data-stat="mp">34:30</td>
          <td data-stat="pts">28</td><td data-stat="trb">12</td>
          <td data-stat="ast">9</td><td data-stat="stl">2</td>
          <td data-stat="blk">1</td><td data-stat="game_score">27.2</td>
          <td data-stat="plus_minus">+14</td>
        </tr>
      </tbody></table>
      <!-- <table id="player_game_log_post"><tbody>
        <tr>
          <th data-stat="date">2025-05-01</th>
          <td data-stat="game_location"></td>
          <td data-stat="opp_name_abbr">LAC</td>
          <td data-stat="game_result">L, 101-104</td>
          <td data-stat="mp">39</td>
          <td data-stat="pts">31</td><td data-stat="trb">15</td>
          <td data-stat="ast">8</td><td data-stat="stl">1</td>
          <td data-stat="blk">0</td><td data-stat="game_score">26.1</td>
          <td data-stat="plus_minus">-2</td>
        </tr>
      </tbody></table> -->
    ''');

    expect(games, hasLength(2));
    expect(games.first.opponent, 'Los Angeles Clippers');
    expect(games.first.outcome, 'LOSS');
    expect(games.last.opponent, 'Los Angeles Lakers');
    expect(games.last.minutes, 34.5);
    expect(games.last.plusMinus, 14);
    expect(games.last.score, '120-108');
  });

  test('direct Dart parser reads the WNBA last5 table', () {
    final games = BasketballReferenceRepository.parseWnbaLastFiveHtml('''
      <table id="last5"><tbody><tr>
        <th data-stat="date">2026-07-30</th>
        <td data-stat="game_location">@</td>
        <td data-stat="opp_name_abbr">TOR</td>
        <td data-stat="game_result">W, 104-72</td>
        <td data-stat="mp">22</td><td data-stat="pts">12</td>
        <td data-stat="orb">1</td><td data-stat="drb">4</td>
        <td data-stat="ast">2</td><td data-stat="stl">1</td>
        <td data-stat="blk">1</td><td data-stat="game_score">11.6</td>
        <td data-stat="plus_minus">13</td>
      </tr></tbody></table>
    ''');

    expect(games.single.opponent, 'Toronto Tempo');
    expect(games.single.rebounds, 5);
    expect(games.single.location, 'AWAY');
    expect(games.single.score, '104-72');
  });

  test('repository resolves a player, downloads HTML and then uses cache',
      () async {
    final cache = await Directory.systemTemp.createTemp('courtboard-br-test-');
    addTearDown(() => cache.delete(recursive: true));
    final requested = <Uri>[];
    final repository = BasketballReferenceRepository(
      cacheDirectory: cache,
      fetchHtml: (uri) async {
        requested.add(uri);
        if (uri.path == '/search/search.fcgi') {
          return '<a href="/players/j/jokicni01.html">Nikola Jokić (2016-2026)</a>';
        }
        return '''
          <table id="player_game_log_reg"><tbody><tr>
            <th data-stat="date">2026-04-12</th>
            <td data-stat="opp_name_abbr">SAS</td>
            <td data-stat="game_result">W, 104-72</td>
            <td data-stat="mp">18:20</td><td data-stat="pts">23</td>
            <td data-stat="trb">8</td><td data-stat="ast">1</td>
            <td data-stat="stl">0</td><td data-stat="blk">1</td>
          </tr></tbody></table>
        ''';
      },
    );
    final now = DateTime.now();
    final season = BasketballReferenceRepository.seasonEndYear(now);

    final first = await repository.recentGames(
      'Nikola Jokić',
      now: now,
    );
    final second = await repository.recentGames(
      'Nikola Jokić',
      now: now,
    );

    expect(first.single.opponent, 'San Antonio Spurs');
    expect(second.single.points, 23);
    expect(requested, hasLength(2));
    expect(requested.first.queryParameters['search'], 'Nikola Jokić');
    expect(requested.last.path, '/players/j/jokicni01/gamelog/$season');
  });
}
