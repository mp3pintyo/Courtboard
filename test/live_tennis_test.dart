import 'package:courtboard/data/live_tennis.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player matching tolerates accents and reversed name order', () {
    final player = TennisRepository.findPlayer({
      'data': [
        {'id': 1104, 'name': 'Swiatek Iga', 'ranking': 2, 'tour': 'wta'}
      ]
    }, 'Iga Świątek');

    expect(player?.id, 1104);
    expect(player?.ranking, 2);
  });

  test('score parser follows player-major game arrays', () {
    final score = TennisScore.fromJson({
      'sets': [1, 0],
      'games': [
        [6, 3],
        [4, 4]
      ],
      'points': ['40', '30'],
      'server': 1,
    });

    expect(score.summary, '1–0 szett · 6–4, 3–4 · 40–30 pont');
    expect(score.server, 1);
  });

  test('tiebreak points are labelled as tiebreak', () {
    final score = TennisScore.fromJson({
      'sets': [0, 0],
      'games': [
        [6],
        [6]
      ],
      'points': ['5', '3'],
      'server': 2,
      'is_tiebreak': true,
    });

    expect(score.summary, '0–0 szett · 6–6 · 5–3 rövidítés');
  });

  test('live detail shows the server from the tracked player side', () {
    final player =
        TennisPlayer.fromJson(const {'id': 7, 'name': 'Iga Swiatek'});
    final match = TennisMatch.fromJson({
      'id': 91,
      'tournament': 'Montreal',
      'status': 'live',
      'players': {
        'p1': {'id': 7, 'name': 'Iga Swiatek'},
        'p2': {'id': 8, 'name': 'Coco Gauff'}
      },
      'score': {
        'sets': [1, 0],
        'games': [
          [6, 4],
          [2, 1]
        ],
        'points': ['15', '0'],
        'server': 1,
      }
    });
    final opponentServes = TennisMatch.fromJson({
      'id': 92,
      'tournament': 'Montreal',
      'status': 'live',
      'players': {
        'p1': {'id': 8, 'name': 'Coco Gauff'},
        'p2': {'id': 7, 'name': 'Iga Swiatek'}
      },
      'score': {
        'sets': [0, 0],
        'games': [
          [3],
          [3]
        ],
        'server': 1,
      }
    });

    expect(match.liveDetail(player), endsWith('· adogat'));
    expect(opponentServes.liveDetail(player), endsWith('· az ellenfél adogat'));
  });

  test('repository uses only Free endpoints and filters by player', () async {
    final calls = <String>[];
    Future<Map<String, dynamic>> fake(
        String path, Map<String, String> query) async {
      calls.add(
          '$path?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}');
      if (path == '/players') {
        return {
          'data': [
            {'id': 7, 'name': 'Iga Swiatek', 'tour': 'wta'}
          ]
        };
      }
      if (path == '/players/7') {
        return {
          'id': 7,
          'name': 'Iga Swiatek',
          'tour': 'wta',
          'country': 'POL',
          'ranking': 2,
          'ranking_points': 8000,
          'hand': 'R',
          'backhand': 2,
          'stats': {'season': {}}
        };
      }
      if (path == '/matches' && query['status'] == 'live') {
        return {
          'data': [
            {
              'id': 91,
              'tournament': 'Montreal',
              'status': 'live',
              'players': {
                'p1': {'id': 7, 'name': 'Iga Swiatek'},
                'p2': {'id': 8, 'name': 'Coco Gauff'}
              },
              'score': {
                'sets': [1, 0],
                'games': [
                  [6, 2],
                  [4, 1]
                ],
                'points': ['15', '0']
              }
            },
            {
              'id': 92,
              'tournament': 'Toronto',
              'status': 'live',
              'players': {
                'p1': {'id': 20, 'name': 'Other One'},
                'p2': {'id': 21, 'name': 'Other Two'}
              }
            }
          ]
        };
      }
      if (path == '/matches') return {'data': []};
      if (path == '/fixtures') {
        return {
          'data': [
            {
              'id': 100,
              'event_date': '2026-08-04T17:00:00Z',
              'tournament': 'Cincinnati',
              'player1_name': 'Gauff Coco',
              'player2_name': 'Swiatek Iga',
              'surface': 'hard'
            }
          ]
        };
      }
      if (path == '/usage') {
        return {
          'tier': 'free',
          'limits': {'per_day': 100},
          'today': {'calls': 12}
        };
      }
      throw StateError('Unexpected endpoint: $path');
    }

    final data = await TennisRepository(const SportsApiConfig(), call: fake)
        .fetch('Iga Świątek', forceRefresh: true);

    expect(data.player.ranking, 2);
    expect(data.liveMatches.single.opponentOf(data.player), 'Coco Gauff');
    expect(data.fixtures.single.opponentOf(data.player), 'Gauff Coco');
    expect(data.usage?.today, 12);
    expect(data.usage?.dailyLimit, 100);
    expect(calls.any((call) => call.contains('status=completed')), isFalse);
    expect(calls.any((call) => call.contains('/history')), isFalse);
    expect(calls.where((call) => call.startsWith('/matches?')),
        everyElement(contains('tour=wta')));
  });
}
