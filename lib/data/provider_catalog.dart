import 'sports_api.dart';

enum ProviderKey {
  none,
  apiSports,
  ballDontLie,
  footballData,
  rapidApi,
  liveTennis,
  youtube,
}

enum ProviderStage { active, prepared }

class ProviderCatalogEntry {
  const ProviderCatalogEntry({
    required this.name,
    required this.sports,
    required this.role,
    required this.visibleOutput,
    required this.capabilities,
    required this.authentication,
    required this.limit,
    required this.cache,
    required this.setup,
    required this.fallback,
    required this.docsUrl,
    this.key = ProviderKey.none,
    this.stage = ProviderStage.active,
  });

  final String name;
  final List<String> sports;
  final String role;
  final List<String> visibleOutput;
  final List<String> capabilities;
  final String authentication;
  final String limit;
  final String cache;
  final String setup;
  final String fallback;
  final String docsUrl;
  final ProviderKey key;
  final ProviderStage stage;

  bool isConfigured(SportsApiConfig config) => switch (key) {
    ProviderKey.none => true,
    ProviderKey.apiSports => config.apiSportsKey.isNotEmpty,
    ProviderKey.ballDontLie => config.balldontlieKey.isNotEmpty,
    ProviderKey.footballData => config.footballDataKey.isNotEmpty,
    ProviderKey.rapidApi => config.rapidApiDartsKey.isNotEmpty,
    ProviderKey.liveTennis => config.liveTennisKey.isNotEmpty,
    ProviderKey.youtube => config.youtubeKey.isNotEmpty,
  };

  String get searchText => [
    name,
    ...sports,
    role,
    ...visibleOutput,
    ...capabilities,
    authentication,
    limit,
    cache,
    setup,
    fallback,
  ].join(' ').toLowerCase();
}

const providerCatalog = <ProviderCatalogEntry>[
  ProviderCatalogEntry(
    name: 'API-Sports',
    sports: ['NBA', 'NFL', 'Foci'],
    role: 'Többsportos profil- és eredményforrás.',
    visibleOutput: [
      'NBA-játékosprofil mezői a közös profilkártyán',
      'Focinál legutóbbi befejezett mérkőzések',
      'Fizetős szezonhozzáférésnél focista szezonstatisztikák',
      'NFL-válasz elérhetősége; a részletes megjelenítés még korlátozott',
    ],
    capabilities: [
      'NBA, NFL és labdarúgó végpontok',
      'A többi szolgáltatóval együtt, részleges hiba mellett is működik',
      'A foci Free csomagban season-alapú lekérést használ, nem a tiltott last paramétert',
    ],
    authentication: 'Saját API-Sports kulcs szükséges.',
    limit: 'Free: 100 kérés/nap és 10 kérés/perc; korlátozott szezonok.',
    cache:
        'A szolgáltatás eredményei az adott adatfolyam frissítési szabályait követik.',
    setup: 'Adatforrások → API-Sports kulcs, vagy API_SPORTS_KEY.',
    fallback:
        'Hiba esetén a többi bekötött szolgáltató és a helyi alapadatok maradnak.',
    docsUrl: 'https://www.api-football.com/pricing',
    key: ProviderKey.apiSports,
  ),
  ProviderCatalogEntry(
    name: 'BALLDONTLIE',
    sports: ['NBA'],
    role: 'NBA-játékosprofil kiegészítése.',
    visibleOutput: [
      'Az API-Sports és TheSportsDB adataival összevont profilmezők',
    ],
    capabilities: [
      'Játékos- és csapatadatok',
      'Egy forrás hibája nem állítja le a közös NBA-profilt',
    ],
    authentication: 'Saját BALLDONTLIE kulcs szükséges.',
    limit: 'Free: 5 kérés/perc.',
    cache: 'Nincs külön tartós klienscache.',
    setup: 'Adatforrások → BALLDONTLIE kulcs, vagy BALLDONTLIE_KEY.',
    fallback: 'API-Sports és TheSportsDB tölti ki, amit tud.',
    docsUrl: 'https://www.balldontlie.io/',
    key: ProviderKey.ballDontLie,
  ),
  ProviderCatalogEntry(
    name: 'TheSportsDB',
    sports: ['NBA', 'WNBA', 'Foci', 'Darts', 'Minden sport'],
    role:
        'Névfeloldás, profilkép, alapadatok, focicsapat-mérkőzések és darts eredmények.',
    visibleOutput: [
      'Új sportoló profilképe',
      'NBA-profil kiegészítő adatai',
      'Támogatott focicsapatok utolsó és következő mérkőzései',
      'Darts-játékosprofil és az utolsó 5 eredmény',
    ],
    capabilities: [
      'Játékoskeresés név alapján',
      'Sportesemény-keresés és szezonlista',
      'Publikus Free v1 hozzáférés',
    ],
    authentication:
        'Nem kell saját kulcs; az app a publikus 123 kulcsot használja.',
    limit: 'Free: legfeljebb 30 kérés/perc; egyes lekérdezések korlátozottak.',
    cache: 'Dartsnál a RapidAPI-réteggel együtt 6 órás cache védi a kvótát.',
    setup: 'Nincs teendő.',
    fallback: 'Kép nélkül monogram; dartsnál a meglévő helyi adatok maradnak.',
    docsUrl: 'https://www.thesportsdb.com/documentation',
  ),
  ProviderCatalogEntry(
    name: 'football-data.org',
    sports: ['Foci'],
    role:
        'Free ligák kereteinek, játékos-alapadatainak és klubmérkőzéseinek kiegészítő forrása.',
    visibleOutput: [
      'Név alapján feloldott focista klubja, posztja, nemzetisége, születési dátuma, mezszáma és azonosítója',
      'Az utolsó 5 klubmérkőzés a Free csomag által támogatott csapatoknál',
    ],
    capabilities: [
      'Dinamikus csapat- és játékosfeloldás; nincs beégetett Liverpool-azonosító',
      'A 12 TIER_ONE verseny aktuális csapatkereteinek név szerinti keresése',
      'Free versenyek, mérkőzések, eredmények és tabellák',
      'A játékos meccsenkénti statisztikáját a Free API nem adja; ezt a FotMob egészíti ki',
    ],
    authentication: 'Ingyenes regisztrációs kulcs szükséges.',
    limit: 'Free: 12 verseny és 10 kérés/perc.',
    cache: 'A Free csapatkeretek 7 napos tartós lemezcache-be kerülnek.',
    setup: 'Adatforrások → football-data.org kulcs, vagy FOOTBALL_DATA_KEY.',
    fallback:
        'A FotMob adja a szezonstatisztikát; nem támogatott ligánál a TheSportsDB ad klubmérkőzést.',
    docsUrl: 'https://www.football-data.org/client/register',
    key: ProviderKey.footballData,
  ),
  ProviderCatalogEntry(
    name: 'FotMob',
    sports: ['Foci', 'Női foci'],
    role:
        'Aktuális vagy előző szezon játékos-összesítője, ha az API-Sports nem fér hozzá a friss idényhez.',
    visibleOutput: [
      'Csapat és versenysorozat',
      'Értékelésátlag, mérkőzések, gólok és gólpasszok',
      'Sárga és piros lapok',
    ],
    capabilities: [
      'Névkeresés ékezet- és névsorrend-független egyeztetéssel',
      'Férfi és női bajnokságok, köztük a Liga F',
      'Az API-Sports adataival azonos csapat és versenysorozat alapján összevonható',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem hivatalos webes feed.',
    limit:
        'Nincs publikált alkalmazási kvóta; best effort forrás, kímélő lekéréssel.',
    cache: 'Játékosonként 6 órás memóriacache.',
    setup: 'Nincs teendő.',
    fallback:
        'Ha nem érhető el, az API-Sports friss szezonadata marad; régi szezont az app nem címkéz aktuálisnak.',
    docsUrl: 'https://www.fotmob.com/',
  ),
  ProviderCatalogEntry(
    name: 'SportsDataverse · wehoop',
    sports: ['WNBA'],
    role: 'Szezononkénti WNBA box score adatforrás.',
    visibleOutput: [
      'WNBA szezonátlagok: perc, pont, lepattanó, assziszt, labdaszerzés és eladott labda',
      'Súlyozott mezőnymutató (FG%) a bedobott és megkísérelt dobásokból',
      'Forma és utolsó mérkőzések játékosonként',
    ],
    capabilities: [
      'Játékos box score CSV-k',
      'ESPN athlete ID átadása a RapidAPI WNBA-rétegnek',
    ],
    authentication: 'Nem kell API-kulcs.',
    limit:
        'Nincs apphoz kötött havi kvóta; GitHub release-fájl letöltése történik.',
    cache: 'A letöltött szezonfájl tartósan megmarad a wnba_cache mappában.',
    setup: 'Nincs teendő; az első WNBA-lekéréshez internet kell.',
    fallback: 'A már letöltött helyi szezonfájl offline is használható.',
    docsUrl: 'https://github.com/sportsdataverse/sportsdataverse-py',
  ),
  ProviderCatalogEntry(
    name: 'Basketball Reference',
    sports: ['NBA', 'WNBA'],
    role:
        'NBA szezonösszesítő, valamint NBA/WNBA mérkőzések kiegészítő forrása.',
    visibleOutput: [
      'NBA alapszakasz és rájátszás utolsó 5 mérkőzése',
      'NBA aktuális szezonátlagok: perc, pont, lepattanó, assziszt, labdaszerzés, eladott labda és FG%',
      'WNBA utolsó 5 mérkőzése',
    ],
    capabilities: [
      'Közvetlen Dart HTTP-letöltés és HTML-tábla feldolgozás',
      'A legfrissebb elérhető NBA alapszakasz per-game sorának felismerése',
      'Az NBA alapszakasz- és playoff-tábláit automatikusan egyesíti',
      'A hivatalos API-k hiányos friss adatai mellett is adhat eredményt',
    ],
    authentication: 'Nem kell API-kulcs.',
    limit:
        'Nincs publikált kvóta; nem hivatalos webes adatforrás, best effort.',
    cache:
        'Ligánként 6 órás lemezcache; hálózati hibánál a régebbi cache is használható.',
    setup: 'Nincs teendő; Python és külön telepítés nem szükséges.',
    fallback: 'Oldalhiba esetén a régi cache és a többi NBA/WNBA-forrás marad.',
    docsUrl: 'https://www.basketball-reference.com/',
  ),
  ProviderCatalogEntry(
    name: 'ESPN · Liga F',
    sports: ['Foci', 'Női foci'],
    role: 'A spanyol női liga eredményei az esp.w.1 ligából.',
    visibleOutput: [
      'Aitana Bonmatí / Barcelona Femení utolsó 5 befejezett mérkőzése',
    ],
    capabilities: [
      'Éves scoreboard lekérés',
      'Csak a női Barcelona-meccseket engedi át, férfi eredményt nem kever be',
    ],
    authentication: 'Nem kell API-kulcs.',
    limit:
        'Nincs publikált alkalmazási kvóta; nem dokumentált publikus végpont.',
    cache: 'Nincs külön tartós klienscache.',
    setup: 'Nincs teendő; jelenleg célzott Aitana/Barcelona Femení integráció.',
    fallback:
        'Nincs találat esetén nem jelenít meg kitalált vagy férfi mérkőzést.',
    docsUrl:
        'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.w.1/scoreboard?dates=2026',
  ),
  ProviderCatalogEntry(
    name: 'RapidAPI · Darts API',
    sports: ['Darts'],
    role: 'Sportbex versenyinformációk a darts profil mellett.',
    visibleOutput: ['Legfeljebb 8 elérhető verseny címkéje'],
    capabilities: [
      'Az API eseményeket, piacokat és oddsokat is kínál',
      'Az app jelenleg csak a competitions/3503 végpontot használja',
    ],
    authentication: 'RapidAPI előfizetés és X-RapidAPI-Key szükséges.',
    limit: 'Free csomag: 1000 kérés/hó.',
    cache: '6 órás cache.',
    setup: 'Adatforrások → RapidAPI közös kulcs, vagy RAPIDAPI_DARTS_KEY.',
    fallback:
        'A TheSportsDB profilja és eredményei a RapidAPI nélkül is működnek.',
    docsUrl: 'https://rapidapi.com/sportbex-api-default-api/api/darts-api',
    key: ProviderKey.rapidApi,
  ),
  ProviderCatalogEntry(
    name: 'RapidAPI · WNBA API',
    sports: ['WNBA'],
    role: 'WNBA Player Bio és Advanced Statistics kiegészítés.',
    visibleOutput: [
      'Csapat, GP, MIN, PTS, REB, AST, STL, BLK, FG% és 3P%',
      'Legfeljebb 4 WNBA-díj',
    ],
    capabilities: [
      'A wehoop ESPN athlete ID-ját használja külön keresési kérés nélkül',
      'Az ESPN-neveket ékezet- és névsorrend-függetlenül egyezteti',
      'A Bio és Advanced Statistics hívás egymás után fut a 429 elkerülésére',
    ],
    authentication:
        'Ugyanaz a mentett RapidAPI alkalmazáskulcs használható, mint dartshoz.',
    limit: 'Free csomag: 100 kérés/hó; egy profilfrissítés legfeljebb 2 hívás.',
    cache: '7 napos lemezcache, hibánál lejárt cache-visszaeséssel.',
    setup: 'Iratkozz fel a WNBA API-ra, majd add meg a RapidAPI közös kulcsot.',
    fallback: 'wehoop és Basketball Reference adatok továbbra is megjelennek.',
    docsUrl: 'https://rapidapi.com/belchiorarkad-FqvHs2EDOtP/api/wnba-api',
    key: ProviderKey.rapidApi,
  ),
  ProviderCatalogEntry(
    name: 'Live Tennis API',
    sports: ['Tenisz'],
    role:
        'Teniszjátékos-profil, aktuális ranglista, élő állás és következő mérkőzések.',
    visibleOutput: [
      'Játékos neve, sorozata, országa és aktuális ranglistája',
      'Ranglistapont, ütőkéz, fonák és születési dátum',
      'Élő ellenfél, verseny, szett-, játék- és pontállás',
      'Legfeljebb 5 következő mérkőzés vagy név alapú fixture',
      'A saját napi API-használat és csomag',
    ],
    capabilities: [
      'ATP, WTA, Challenger, ITF és junior sorozatok',
      'Free játékoskeresés és részletes játékosprofil',
      'Free élő és közelgő mérkőzések, aktuális pontállás és fixture lista',
      'A befejezett mérkőzéseket nem kéri le, mert azok History/BASIC hozzáféréshez kötöttek',
    ],
    authentication: 'Ingyenes regisztrációs Bearer API-kulcs szükséges.',
    limit: 'Free: 30 kérés/perc és 1000 kérés/nap; bankkártya nélkül.',
    cache:
        'Játékosonként 10 perces lemezcache; a kézi frissítés kikerüli a cache-t.',
    setup:
        'Adatforrások → Live Tennis API, vagy LIVE_TENNIS_API_KEY környezeti változó.',
    fallback:
        'Kulcs vagy hálózat nélkül a helyi profil megmarad; kitalált mérkőzés nem jelenik meg.',
    docsUrl: 'https://docs.livetennisapi.com/reference.html',
    key: ProviderKey.liveTennis,
  ),
  ProviderCatalogEntry(
    name: 'Hírek · RSS + FOX JSON-oldalfeed',
    sports: ['Hírek', 'NBA', 'WNBA', 'Foci', 'Tenisz'],
    role:
        'Többforrásos hírolvasó és korlátlan idejű, kereshető helyi hírarchívum.',
    visibleOutput: [
      'Központi Hírek oldal cím-, sport-, sportoló- és forrásszűréssel',
      'Cím, tisztított rövid összefoglaló, kép, dátum és eredeti cikk linkje',
      'Automatikus sportolókapcsolás ékezet- és névsorrend-függetlenül',
      'A korábban letöltött hírek internet nélkül és hónapokkal később is elérhetők',
    ],
    capabilities: [
      'FOX: NBA, WNBA, foci és tenisz a weboldalak aktuális JSON-hírfolyamából',
      'Sportáganként a FOX-oldal legfrissebb 100 cikke kérésenként, valódi publikálási dátummal',
      'CBS Sports: NBA, foci és tenisz',
      'Opcionális ESPN: NBA, WNBA, foci és tenisz',
      'Opcionális Guardian: foci és tenisz',
      'RSS, Atom és FOX JSON parser, numerikus és névvel jelölt időzónák, URL/guid deduplikáció és HTML-tisztítás',
      'Forrásfüggetlen hírmodell, amelyhez később API-provider is csatlakoztatható',
    ],
    authentication:
        'Nem kell API-kulcs. ESPN és Guardian külön kapcsolható be.',
    limit:
        '20 perces automatikus frissítési ablak; a kézi frissítés azonnal lekéri az aktív feedeket.',
    cache:
        'SQLite-adatbázisban tartós megőrzés, automatikus időalapú törlés nélkül.',
    setup:
        'Hírek → Források. A FOX és CBS alapból aktív; ESPN és Guardian opcionális.',
    fallback:
        'Forráshiba vagy internetkimaradás esetén a teljes korábbi helyi archívum megmarad.',
    docsUrl: 'https://www.espn.com/espn/news/story?page=rssinfo',
  ),
  ProviderCatalogEntry(
    name: 'YouTube oEmbed + helyi lejátszási lista',
    sports: ['Videó', 'Minden sport'],
    role: 'A felhasználó által felvett YouTube-linkek metaadatai.',
    visibleOutput: [
      'Videócím, bélyegkép és külső YouTube-megnyitás',
      'Helyben mentett könyvjelzőlista',
    ],
    capabilities: [
      'Teljes URL és videóazonosító feldolgozása',
      'oEmbed metaadatlekérés API-kulcs nélkül',
    ],
    authentication: 'Nem kell API-kulcs.',
    limit: 'Nincs az appban kezelt havi kvóta.',
    cache: 'A lista az APPDATA courtboard_playlist.json fájljában marad.',
    setup:
        'A Felfedezés oldalon adj meg egy YouTube URL-t vagy videóazonosítót.',
    fallback:
        'Metaadathiba esetén a videóazonosító alapján menthető alapbejegyzés.',
    docsUrl: 'https://oembed.com/',
  ),
  ProviderCatalogEntry(
    name: 'YouTube Data API v3',
    sports: ['Videó', 'Minden sport'],
    role: 'Előkészített videókereső adapter.',
    visibleOutput: ['Jelenleg nincs automatikus keresési találat a felületen'],
    capabilities: [
      'A kódban a videókeresési kliens és a YOUTUBE_DATA_KEY helye elkészült',
    ],
    authentication:
        'Google API-kulcs szükséges, amikor a kereső UI bekötésre kerül.',
    limit:
        'A Google projekt napi kvótája érvényes; a search.list költséges művelet.',
    cache: 'Jelenleg nincs, mert a kereső nincs aktívan használva.',
    setup: 'Most nincs teendő; a kulcs környezeti változóként előkészíthető.',
    fallback: 'A kulcs nélküli kézi YouTube URL-felvétel aktív.',
    docsUrl: 'https://developers.google.com/youtube/v3/determine_quota_cost',
    key: ProviderKey.youtube,
    stage: ProviderStage.prepared,
  ),
];

List<ProviderCatalogEntry> filterProviderCatalog(String query, String sport) {
  final normalizedQuery = query.trim().toLowerCase();
  return providerCatalog
      .where((entry) {
        final sportMatches = sport == 'Mind' || entry.sports.contains(sport);
        final queryMatches =
            normalizedQuery.isEmpty ||
            entry.searchText.contains(normalizedQuery);
        return sportMatches && queryMatches;
      })
      .toList(growable: false);
}
