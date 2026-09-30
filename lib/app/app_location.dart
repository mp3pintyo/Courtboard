/// Az útvonalak (URL-ek) és az alkalmazás navigációs állapota közötti
/// leképezés — tiszta függvények, widgetek nélkül.
///
/// | Útvonal                          | Oldal                           |
/// |----------------------------------|---------------------------------|
/// | `/`                              | Áttekintés                      |
/// | `/sportolok`                     | Sportolók                       |
/// | `/sportolok/:athleteId?from=…`   | profil (a kiinduló menüponttal) |
/// | `/naptar`, `/hirek`, `/videok`   | Naptár, Hírek, Videók           |
/// | `/kovetes`                       | Követés                         |
/// | `/osszehasonlitas?a=…&b=…`       | Összehasonlítás (két sportoló)  |
/// | `/adatforrasok`, `/beallitasok`  | Adatforrások, Beállítások       |
library;

import 'package:courtboard/app/app_page.dart';
import 'package:courtboard/domain/athlete.dart';

class AppLocation {
  const AppLocation({required this.page, this.athleteId, this.origin});

  /// Az útvonal menüpontja (profilnál a Sportolók ág).
  final AppPage page;

  /// A megnyitott profil sportolójának azonosítója ([Athlete.id]).
  final String? athleteId;

  /// Profilnál a menüpont, ahonnan megnyitották (`from=`); `null`, ha nem
  /// ismert (például közvetlen útvonalnál).
  final AppPage? origin;

  static const overview = AppLocation(page: AppPage.overview);

  /// Nyitott profil-e.
  bool get isProfile => athleteId != null;

  /// A kiemelt menüpont: profilnál a kiinduló oldal (alapból a Sportolók),
  /// egyébként az útvonal oldala.
  AppPage get highlighted => isProfile ? (origin ?? AppPage.athletes) : page;

  /// Egy útvonal értelmezése; ismeretlen útvonalnál az Áttekintés.
  static AppLocation parse(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return overview;
    final page = AppPage.fromSlug(segments.first);
    if (page == null) return overview;
    if (page == AppPage.athletes && segments.length > 1) {
      return AppLocation(
        page: page,
        athleteId: segments[1],
        origin: AppPage.fromSlug(uri.queryParameters['from']),
      );
    }
    return AppLocation(page: page);
  }

  /// Egy sportoló profiljának útvonala (`/sportolok/nikola-jokic?from=…`).
  static String profilePath(String athleteId, {AppPage? from}) => Uri(
    path: '${AppPage.athletes.path}/$athleteId',
    queryParameters: from == null ? null : {'from': from.slug},
  ).toString();

  /// Az Összehasonlítás útvonala a két kiválasztott sportoló
  /// azonosítójával (`/osszehasonlitas?a=…&b=…`).
  static String comparePath({String? left, String? right}) {
    final query = {'a': ?left, 'b': ?right};
    return Uri(
      path: AppPage.compare.path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}
