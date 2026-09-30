import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:courtboard/data/http_util.dart';
import 'package:courtboard/data/rate_limit.dart';

/// Újrapróbálási szabályok.
///
/// * 429: a `Retry-After` szerint legfeljebb [maxRateLimitRetries]-szer,
///   ha a várakozás nem hosszabb [maxRetryAfter]-nél (különben azonnal
///   továbbadja a hibát, mert a felhasználó úgysem várna ennyit).
/// * 5xx, időtúllépés, hálózati hiba: legfeljebb [maxTransientRetries]-szer,
///   exponenciálisan növekvő várakozással és véletlen szórással.
/// * Minden más 4xx (401, 403, 404…) és a helyi keret kimerülése: soha.
class RetryPolicy {
  const RetryPolicy({
    this.maxTransientRetries = 2,
    this.maxRateLimitRetries = 1,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxRetryAfter = const Duration(seconds: 30),
    this.jitter = 0.25,
  });

  /// Egyetlen próbálkozás, újrapróbálás nélkül.
  static const none = RetryPolicy(
    maxTransientRetries: 0,
    maxRateLimitRetries: 0,
  );

  final int maxTransientRetries;
  final int maxRateLimitRetries;
  final Duration baseDelay;
  final Duration maxRetryAfter;

  /// A várakozás legfeljebb ekkora hányaddal nő véletlenszerűen.
  final double jitter;

  /// A következő próbálkozás előtti várakozás, vagy `null`, ha nincs több
  /// próbálkozás. [random] 0 és 1 közötti számot ad (tesztben rögzíthető).
  Duration? retryDelay(
    CourtboardHttpException error, {
    required int transientRetries,
    required int rateLimitRetries,
    required double Function() random,
  }) {
    if (error is QuotaExhaustedException) return null;
    final retryAfter = error.retryAfter;
    if (error.isRateLimited) {
      if (rateLimitRetries >= maxRateLimitRetries) return null;
      final wait = retryAfter ?? baseDelay * 2;
      return wait > maxRetryAfter ? null : wait;
    }
    final transient =
        error.timedOut || error.statusCode == null || error.isServerError;
    if (!transient || transientRetries >= maxTransientRetries) return null;
    if (retryAfter != null && retryAfter > maxRetryAfter) return null;
    final backoff = baseDelay * (1 << transientRetries);
    final spread = Duration(
      milliseconds: (backoff.inMilliseconds * jitter * random()).round(),
    );
    final wait = backoff + spread;
    return retryAfter != null && retryAfter > wait ? retryAfter : wait;
  }
}

/// Az alkalmazás közös HTTP-rétege: egyetlen, hosszú életű [HttpClient]
/// (kapcsolat-újrahasznosítás), szolgáltatónkénti kéréskorlát, tartós
/// napi/havi keretszámláló és újrapróbálás.
///
/// A repository-k konstruktorban kapják meg; alapértelmezés a [shared]
/// példány.
class HttpService {
  HttpService({
    this._client,
    RateLimiter? limiter,
    QuotaTracker? quota,
    this.retryPolicy = const RetryPolicy(),
    Map<String, ProviderLimits> limits = providerLimits,
    Future<void> Function(Duration duration)? delay,
    double Function()? random,
    this.networkEnabled = true,
  }) : limiter = limiter ?? RateLimiter(delay: delay),
       quota = quota ?? QuotaTracker(limits: limits),
       _limits = limits,
       _delay = delay ?? _realDelay,
       _random = random ?? Random().nextDouble;

  static HttpService? _shared;

  /// Az alkalmazás közös példánya.
  static HttpService get shared => _shared ??= HttpService();

  /// Tesztekhez: a közös példány cseréje (`null` visszaállítja).
  @visibleForTesting
  static set shared(HttpService? value) => _shared = value;

  final RateLimiter limiter;
  final QuotaTracker quota;
  final RetryPolicy retryPolicy;

  /// `false` esetén minden kérés azonnal hálózati hibával zárul (tesztek,
  /// offline futtatás).
  final bool networkEnabled;

  final Map<String, ProviderLimits> _limits;
  final Future<void> Function(Duration duration) _delay;
  final double Function() _random;
  HttpClient? _client;

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// A közös kliens (első használatkor jön létre).
  HttpClient get client => _client ??= createHttpClient();

  /// Szöveges GET a korlátozón, a keretszámlálón és az újrapróbáláson át.
  Future<String> getText(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
    Duration timeout = httpRequestTimeout,
    bool allowMalformed = false,
    bool followRedirects = true,
  }) => send(
    provider,
    () => httpGetText(
      client,
      uri,
      provider: provider,
      headers: headers,
      timeout: timeout,
      allowMalformed: allowMalformed,
      followRedirects: followRedirects,
    ),
  );

  /// JSON-objektumot váró GET (nem objektum gyökérnél `{'data': ...}`).
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
    Duration timeout = httpRequestTimeout,
  }) async => decodeJsonObject(
    await getText(uri, provider: provider, headers: headers, timeout: timeout),
  );

  /// Teljes válasz (státusz + validátorok), 304 engedélyezésével.
  Future<HttpTextResponse> getResponse(
    Uri uri, {
    required String provider,
    Map<String, String> headers = const {},
    Duration timeout = httpRequestTimeout,
    bool allowNotModified = true,
  }) => send(
    provider,
    () => httpGetResponse(
      client,
      uri,
      provider: provider,
      headers: headers,
      timeout: timeout,
      allowNotModified: allowNotModified,
    ),
  );

  /// Tetszőleges kérés futtatása a szolgáltató szabályai szerint:
  /// keretellenőrzés → percenkénti korlát → küldés → szükség esetén
  /// újrapróbálás. Minden próbálkozás külön kérésnek számít.
  Future<T> send<T>(String provider, Future<T> Function() request) async {
    if (!networkEnabled) {
      throw CourtboardHttpException(
        provider: provider,
        detail: 'a hálózat ki van kapcsolva',
      );
    }
    final limits = _limits[provider];
    var transientRetries = 0;
    var rateLimitRetries = 0;
    while (true) {
      await quota.reserve(provider);
      final perMinute = limits?.perMinute;
      if (perMinute != null) await limiter.acquire(provider, perMinute);
      try {
        return await request();
      } on CourtboardHttpException catch (error) {
        final wait = retryPolicy.retryDelay(
          error,
          transientRetries: transientRetries,
          rateLimitRetries: rateLimitRetries,
          random: _random,
        );
        if (wait == null) rethrow;
        if (error.isRateLimited) {
          rateLimitRetries++;
        } else {
          transientRetries++;
        }
        await _delay(wait);
      }
    }
  }

  /// A kliens lezárása; a következő kérés újat nyit.
  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
