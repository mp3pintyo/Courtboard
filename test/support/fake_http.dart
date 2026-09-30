import 'dart:convert';
import 'dart:io';

import 'package:courtboard/data/http_service.dart';
import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/json_file_cache.dart';
import 'package:courtboard/data/rate_limit.dart';

/// Egy tesztfixture (`test/fixtures/<name>`) JSON-objektumként.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Hálózat nélküli [HttpService]: a kéréseket a [routes] szerint válaszolja
/// meg (az URI útvonala + query alapján), és naplózza őket.
class FakeHttpService extends HttpService {
  FakeHttpService(this.routes)
    : super(
        networkEnabled: false,
        quota: QuotaTracker(storage: MemoryCacheStorage()),
      );

  /// Útvonal (és opcionális `?query`) → válasz. A válasz lehet
  /// `Map<String, dynamic>` (JSON), [CourtboardHttpException] (hibát dob) vagy
  /// függvény, amely az URI-ból állítja elő ezek egyikét.
  final Map<String, Object> routes;

  final List<Uri> requests = [];
  final List<Map<String, String>> headers = [];

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
    Duration timeout = httpRequestTimeout,
  }) async {
    requests.add(uri);
    this.headers.add(headers);
    final withQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    var response = routes[withQuery] ?? routes[uri.path];
    if (response is Object Function(Uri)) response = response(uri);
    if (response is Exception) throw response;
    if (response is Map<String, dynamic>) {
      // Mély másolat, hogy a hívó ne módosíthassa a fixture-t.
      return jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
    }
    throw CourtboardHttpException(
      provider: provider,
      statusCode: 404,
      uri: uri,
    );
  }
}
