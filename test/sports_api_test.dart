import 'package:courtboard/data/sports_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TheSportsDB uses the documented public Free v1 key', () {
    final uri = SportsApiClient.theSportsDbUri(
        '/searchplayers.php', {'p': 'Nikola Jokić'});

    expect(uri.host, 'www.thesportsdb.com');
    expect(uri.path, '/api/v1/json/123/searchplayers.php');
    expect(uri.queryParameters['p'], 'Nikola Jokić');
  });

  test('ESPN scoreboard uses a YYYYMMDD date range', () {
    final uri = SportsApiClient.espnScoreboardUri('esp.w.1',
        from: DateTime(2026, 8, 1), to: DateTime(2026, 9, 30));

    expect(uri.path, '/apis/site/v2/sports/soccer/esp.w.1/scoreboard');
    expect(uri.queryParameters['dates'], '20260801-20260930');
  });

  test('TheSportsDB player lookup does not fall back to the first hit', () {
    final result = {
      'player': [
        {'strPlayer': 'Luke Humphries'},
        {'strPlayer': 'Luke Littler'},
      ]
    };

    expect(
        SportsApiClient.findTheSportsDbPlayerIn(result, 'Luke Littler')?[
            'strPlayer'],
        'Luke Littler');
    expect(SportsApiClient.findTheSportsDbPlayerIn(result, 'Michael van Gerwen'),
        isNull);
  });
}
