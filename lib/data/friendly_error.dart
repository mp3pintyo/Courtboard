import 'dart:async';
import 'dart:io';

import 'http_util.dart';

/// Felhasználónak szóló, rövid magyar hibaüzenet tetszőleges kivételből.
///
/// Soha nem ad vissza nyers kivételszöveget, URI-t vagy kérésparamétert,
/// így API-kulcs sem kerülhet a felületre.
String friendlyError(Object error) {
  if (error is CourtboardHttpException) {
    if (error.timedOut) return 'A szolgáltató nem válaszolt időben.';
    if (error.isAuthError) return 'Hibás vagy hiányzó API-kulcs.';
    if (error.isRateLimited) {
      return 'Elérted a szolgáltató kvótáját, próbáld később.';
    }
    if (error.isNotFound) return 'Nem található adat ehhez a sportolóhoz.';
    if (error.statusCode == null) return 'Nincs internetkapcsolat.';
    if (error.isServerError) {
      return 'A szolgáltató átmenetileg nem érhető el, próbáld később.';
    }
    return _generic;
  }
  if (error is TimeoutException) return 'A szolgáltató nem válaszolt időben.';
  if (error is SocketException) return 'Nincs internetkapcsolat.';
  if (error is StateError && _missingKey.hasMatch(error.message)) {
    return 'Hibás vagy hiányzó API-kulcs.';
  }
  return _generic;
}

const _generic = 'Az adatok most nem érhetők el. Próbáld újra később.';

/// A repository-k „…_KEY nincs beállítva” jellegű üzenetei.
final _missingKey = RegExp(
  r'(kulcs|_KEY)\b.*nincs beállítva',
  caseSensitive: false,
);
