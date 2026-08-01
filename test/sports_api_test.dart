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
}
