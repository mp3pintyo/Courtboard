/// A sportolók stabil azonosítója (útvonalakhoz: `/sportolok/<id>`).
library;

import 'package:courtboard/data/file_util.dart';

/// Stabil, URL-be illeszthető azonosító egy névből (`Nikola Jokić` →
/// `nikola-jokic`); nem latin betűs névnél a név hash-e (`h1a2b3c4d`).
String athleteIdFor(String name) => cacheSlug(name).replaceAll('_', '-');

/// Egyedi azonosító: ha a [base] már foglalt, `-2`, `-3` … utótaggal.
String uniqueAthleteId(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  var suffix = 2;
  while (taken.contains('$base-$suffix')) {
    suffix++;
  }
  return '$base-$suffix';
}
