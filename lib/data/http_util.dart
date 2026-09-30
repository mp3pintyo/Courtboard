import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Kapcsolódási időkorlát minden Courtboard HTTP-klienshez.
const httpConnectionTimeout = Duration(seconds: 10);

/// A kérés elküldésére és a teljes válasz beolvasására együtt vonatkozó
/// alapértelmezett időkorlát.
const httpRequestTimeout = Duration(seconds: 20);

/// Új [HttpClient] a közös kapcsolódási időkorláttal.
HttpClient createHttpClient({
  Duration connectionTimeout = httpConnectionTimeout,
}) => HttpClient()..connectionTimeout = connectionTimeout;

/// Típusos HTTP-hiba. Az üzenet soha nem tartalmazza a kérés query-paramétereit
/// vagy fejléceit, így API-kulcs nem kerülhet a felületre vagy naplóba.
class CourtboardHttpException implements IOException {
  CourtboardHttpException({
    required this.provider,
    this.statusCode,
    this.retryAfter,
    Uri? uri,
    this.timedOut = false,
    this.detail = '',
  }) : uri = uri == null ? null : sanitizeUri(uri);

  /// Az adatforrás felhasználónak szóló neve (például `football-data.org`).
  final String provider;

  /// HTTP-státusz; `null`, ha a kérés hálózati hiba vagy időtúllépés miatt
  /// meg sem kapott választ.
  final int? statusCode;

  /// 429 vagy 503 válasz `Retry-After` fejléce, ha volt.
  final Duration? retryAfter;

  /// A kérés címe query-paraméterek nélkül.
  final Uri? uri;
  final bool timedOut;

  /// Kulcsmentes, rövid technikai részlet (hálózati hibák esetén).
  final String detail;

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isRateLimited => statusCode == 429;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => (statusCode ?? 0) >= 500;

  /// Magyar nyelvű, felhasználónak szóló leírás.
  String get message {
    if (timedOut) return 'időtúllépés, a szolgáltatás nem válaszolt időben';
    final code = statusCode;
    if (code == null) {
      return detail.isEmpty ? 'hálózati hiba' : 'hálózati hiba ($detail)';
    }
    final base = switch (code) {
      401 || 403 => 'a kulcs hibás vagy nincs jogosultság',
      404 => 'az adat nem található',
      429 => 'kvóta vagy kéréslimit túllépve',
      >= 500 => 'a szolgáltatás átmenetileg nem elérhető',
      _ => 'váratlan válasz',
    };
    final wait = retryAfter;
    final retry = wait == null
        ? ''
        : ', újrapróbálható ${_formatDuration(wait)} múlva';
    return '$base (HTTP $code$retry)';
  }

  @override
  String toString() => '$provider: $message';
}

/// A cím query- és fragment-rész nélkül: csak séma, host és útvonal marad.
Uri sanitizeUri(Uri uri) => Uri(
  scheme: uri.scheme,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: uri.path,
);

/// `Retry-After` fejléc értelmezése: másodpercszám vagy HTTP-dátum.
Duration? parseRetryAfter(String? value, {DateTime? now}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final seconds = int.tryParse(text);
  if (seconds != null) return seconds < 0 ? null : Duration(seconds: seconds);
  try {
    final date = HttpDate.parse(text);
    final difference = date.difference((now ?? DateTime.now()).toUtc());
    return difference.isNegative ? Duration.zero : difference;
  } catch (_) {
    return null;
  }
}

/// GET kérés szöveges válasszal, teljes időkorláttal.
///
/// 2xx-tól eltérő státusznál, időtúllépésnél vagy hálózati hibánál
/// [CourtboardHttpException] keletkezik, amely nem tartalmaz query-paramétert.
Future<String> httpGetText(
  HttpClient client,
  Uri uri, {
  required String provider,
  Map<String, String> headers = const {},
  Duration timeout = httpRequestTimeout,
  bool allowMalformed = false,
  bool followRedirects = true,
}) async => (await httpGetResponse(
  client,
  uri,
  provider: provider,
  headers: headers,
  timeout: timeout,
  allowMalformed: allowMalformed,
  followRedirects: followRedirects,
)).body;

/// Egy sikeres (2xx vagy engedélyezett 304) GET válasz szövege és a
/// feltételes kérésekhez szükséges validátor-fejlécek.
class HttpTextResponse {
  const HttpTextResponse({
    required this.statusCode,
    required this.body,
    this.etag,
    this.lastModified,
  });

  final int statusCode;
  final String body;
  final String? etag;
  final String? lastModified;

  bool get notModified => statusCode == HttpStatus.notModified;
}

/// GET kérés a teljes válasszal. [allowNotModified] esetén a 304 válasz
/// üres törzzsel sikeresnek számít (feltételes `If-None-Match` /
/// `If-Modified-Since` kérésekhez); minden más nem 2xx státusz
/// [CourtboardHttpException].
Future<HttpTextResponse> httpGetResponse(
  HttpClient client,
  Uri uri, {
  required String provider,
  Map<String, String> headers = const {},
  Duration timeout = httpRequestTimeout,
  bool allowMalformed = false,
  bool followRedirects = true,
  bool allowNotModified = false,
}) async {
  Future<HttpTextResponse> run() async {
    final request = await client.getUrl(uri);
    request.followRedirects = followRedirects;
    headers.forEach(request.headers.set);
    final response = await request.close();
    final code = response.statusCode;
    final etag = response.headers.value(HttpHeaders.etagHeader);
    final lastModified = response.headers.value(HttpHeaders.lastModifiedHeader);
    if (allowNotModified && code == HttpStatus.notModified) {
      await response.drain<void>().catchError((_) {});
      return HttpTextResponse(
        statusCode: code,
        body: '',
        etag: etag,
        lastModified: lastModified,
      );
    }
    if (code < 200 || code >= 300) {
      // A törzset el kell dobni, hogy a kapcsolat felszabaduljon.
      await response.drain<void>().catchError((_) {});
      throw CourtboardHttpException(
        provider: provider,
        statusCode: code,
        uri: uri,
        retryAfter: code == 429 || code == 503
            ? parseRetryAfter(
                response.headers.value(HttpHeaders.retryAfterHeader),
              )
            : null,
      );
    }
    final body = await response
        .transform(Utf8Decoder(allowMalformed: allowMalformed))
        .join();
    return HttpTextResponse(
      statusCode: code,
      body: body,
      etag: etag,
      lastModified: lastModified,
    );
  }

  try {
    return await run().timeout(timeout);
  } on CourtboardHttpException {
    rethrow;
  } on TimeoutException {
    throw CourtboardHttpException(provider: provider, uri: uri, timedOut: true);
  } on IOException catch (error) {
    throw CourtboardHttpException(
      provider: provider,
      uri: uri,
      detail: _networkDetail(error),
    );
  }
}

/// Bináris GET (például kép) teljes időkorláttal és méretkorláttal.
///
/// 2xx-tól eltérő státusznál, időtúllépésnél, hálózati hibánál vagy a
/// [maxBytes]-nál nagyobb válasznál [CourtboardHttpException] keletkezik.
Future<Uint8List> httpGetBytes(
  HttpClient client,
  Uri uri, {
  required String provider,
  Map<String, String> headers = const {},
  Duration timeout = httpRequestTimeout,
  int maxBytes = 15 * 1024 * 1024,
}) async {
  Future<Uint8List> run() async {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final code = response.statusCode;
    if (code < 200 || code >= 300) {
      await response.drain<void>().catchError((_) {});
      throw CourtboardHttpException(
        provider: provider,
        statusCode: code,
        uri: uri,
        retryAfter: code == 429 || code == 503
            ? parseRetryAfter(
                response.headers.value(HttpHeaders.retryAfterHeader),
              )
            : null,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw CourtboardHttpException(
          provider: provider,
          uri: uri,
          detail: 'túl nagy válasz',
        );
      }
    }
    return builder.takeBytes();
  }

  try {
    return await run().timeout(timeout);
  } on CourtboardHttpException {
    rethrow;
  } on TimeoutException {
    throw CourtboardHttpException(provider: provider, uri: uri, timedOut: true);
  } on IOException catch (error) {
    throw CourtboardHttpException(
      provider: provider,
      uri: uri,
      detail: _networkDetail(error),
    );
  }
}

/// JSON-objektumot váró GET. Nem objektum gyökér esetén `{'data': ...}`.
Future<Map<String, dynamic>> httpGetJson(
  HttpClient client,
  Uri uri, {
  required String provider,
  Map<String, String> headers = const {},
  Duration timeout = httpRequestTimeout,
}) async {
  final body = await httpGetText(
    client,
    uri,
    provider: provider,
    headers: headers,
    timeout: timeout,
  );
  return decodeJsonObject(body);
}

/// JSON-szöveg objektumként; nem objektum gyökér esetén `{'data': ...}`.
Map<String, dynamic> decodeJsonObject(String body) {
  final decoded = jsonDecode(body);
  return decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{'data': decoded};
}

String _networkDetail(IOException error) => switch (error) {
  SocketException(:final osError) =>
    osError?.message.trim().isNotEmpty == true
        ? osError!.message.trim()
        : 'a kapcsolat nem jött létre',
  HandshakeException() => 'TLS-kézfogási hiba',
  HttpException() => 'megszakadt HTTP-kapcsolat',
  _ => error.runtimeType.toString(),
};

String _formatDuration(Duration value) {
  if (value.inSeconds < 120) return '${value.inSeconds} mp';
  if (value.inMinutes < 120) return '${value.inMinutes} perc';
  return '${value.inHours} óra';
}
