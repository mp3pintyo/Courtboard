import 'package:courtboard/data/sports_api.dart';

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
    ProviderKey.rapidApi => config.rapidApiKey.isNotEmpty,
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
        'Lemezcache: státusz 1 óra, játékos- és szezonadat 12 óra, csapatkeresés 7 nap; a napi keretet helyi számláló védi.',
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
    cache: '12 órás lemezcache a játékoskereséshez.',
    setup: 'Adatforrások → BALLDONTLIE kulcs, vagy BALLDONTLIE_KEY.',
    fallback: 'API-Sports és TheSportsDB tölti ki, amit tud.',
    docsUrl: 'https://www.balldontlie.io/',
    key: ProviderKey.ballDontLie,
  ),
  ProviderCatalogEntry(
    name: 'TheSportsDB',
    sports: ['NBA', 'WNBA', 'Foci', 'Darts', 'Minden sport'],
    role:
        'Névfeloldás, profilkép, alapadatok, darts eredmények; focicsapat-mérkőzéseknél csak tartalék.',
    visibleOutput: [
      'Új sportoló profilképe',
      'NBA-profil kiegészítő adatai',
      'Focicsapat utolsó és következő meccse, ha sem a football-data.org, sem az ESPN nem ad (figyelmeztetéssel)',
      'Darts-játékosprofil és az utolsó 5 eredmény',
    ],
    capabilities: [
      'Játékoskeresés név alapján',
      'Sportesemény-keresés és szezonlista',
      'Publikus Free v1 hozzáférés',
    ],
    authentication:
        'Nem kell saját kulcs; az app a publikus 123 kulcsot használja.',
    limit:
        'Free: legfeljebb 30 kérés/perc; egyes lekérdezések korlátozottak – a csapat eventslast.php-je csak a legutóbbi hazai, az eventsnext.php csak a következő eseményt adja, ezért a klubmeccsekhez csak tartalék.',
    cache:
        'A névkeresések 24 órás lemezcache-be kerülnek; dartsnál a RapidAPI-réteg 6 órás cache-e is védi a kvótát.',
    setup: 'Nincs teendő.',
    fallback:
        'Kép nélkül monogram; dartsnál a meglévő helyi adatok maradnak. Focinál a Csapatmérkőzések kártya jelzi, ha a hiányos TheSportsDB-feed látszik.',
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
    cache:
        'A csapatlista és a Free csapatkeretek 7 napos, a sikertelen játékoskeresés 24 órás lemezcache-be kerül.',
    setup: 'Adatforrások → football-data.org kulcs, vagy FOOTBALL_DATA_KEY.',
    fallback:
        'A FotMob adja a szezonstatisztikát; nem támogatott csapatnál az ESPN, végső tartalékként a TheSportsDB ad klubmérkőzést.',
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
      'Formagörbe a legutóbbi meccsekből (értékelés, különben gól + gólpassz)',
    ],
    capabilities: [
      'Névkeresés ékezet- és névsorrend-független egyeztetéssel',
      'Férfi és női bajnokságok, köztük a Liga F',
      'Az API-Sports adataival azonos csapat és versenysorozat alapján összevonható',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem hivatalos webes feed.',
    limit:
        'Nincs publikált alkalmazási kvóta; best effort forrás, kímélő lekéréssel.',
    cache: 'Játékosonként 6 órás lemezcache.',
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
    cache:
        'A letöltött szezonfájl tartósan megmarad a cache/wehoop_wnba mappában.',
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
      'Lenyitható „Idővonal” minden meccsnél (lásd ESPN · Mérkőzés-idővonal)',
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
    name: 'ESPN · Klubcsapatok',
    sports: ['Foci', 'Női foci'],
    role:
        'Focicsapatok teljes szezonja (bajnokság, kupák, felkészülési meccsek) és menetrendje, ha a football-data.org nem fedi le a csapatot (például MLS / Inter Miami).',
    visibleOutput: [
      'Csapatmérkőzések kártya: az 5 legutóbbi eredmény (hazai/idegen, sorozat, hosszabbítás, tizenegyesek) és a következő 5 meccs, „ESPN · <liga>” forráscímkével',
      'Naptár: a klub következő meccsei a TheSportsDB előtt',
      'Nyitólap „legutóbbi eredmény” és a háttérfigyelő „Új eredmény” értesítése focicsapatoknál',
      'Lenyitható „Idővonal” a lejátszott meccseknél',
    ],
    capabilities: [
      'Csapatfeloldás a bajnoki csapatlistákból (usa.1, eng.1, esp.1, ger.1, ita.1, fra.1, por.1, ned.1, mex.1, bra.1, arg.1, ksa.1, tur.1, sco.1, bel.1; női: usa.nwsl, eng.w.1, esp.w.1), az első találatnál megáll',
      'Szigorú névegyezés: teljes név, rövid név, rövidítés vagy hely + név; részleges név nem egyezik',
      'soccer/all/teams/{id}/schedule (lejátszott meccsek, dátum szerint rendezve) és ?fixture=true (közelgő meccsek)',
      'Befejezett státuszok (FT, AET, büntetők); elhalasztott és törölt meccset nem mutat',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem dokumentált végpont.',
    limit:
        'Nincs publikált kvóta; az ESPN közös, 30 kérés/perc korlátjából fogy (best effort).',
    cache:
        'Csapatlista ligánként 7 nap, feloldott csapat 7 nap (sikertelen keresés 24 óra), eredmények 1 óra, menetrend 6 óra; hibánál a régebbi lista marad.',
    setup: 'Nincs teendő; a csapatot a sportoló adatlapján kell megadni.',
    fallback:
        'Ha az ESPN nem ismeri a csapatot vagy hibázik, a TheSportsDB (figyelmeztetéssel), német csapatnál az OpenLigaDB jön.',
    docsUrl:
        'https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/teams/20232/schedule',
  ),
  ProviderCatalogEntry(
    name: 'ESPN · Menetrendek',
    sports: ['NBA', 'WNBA', 'NFL', 'Naptár'],
    role:
        'Az NBA-, WNBA- és NFL-csapatok közelgő mérkőzései a Naptár oldalhoz.',
    visibleOutput: [
      'Naptár: a követett sportoló csapatának következő meccsei helyi időben',
      'Ellenfél, hazai/idegen, liga és szakasz (alapszakasz, rájátszás, NFL-hét)',
      'Helyszín és az ESPN Gamecast-oldal linkje',
      'A legközelebbi esemény a nyitóoldal „Mai fókusz” blokkjában',
      'NFL-profil: csapatforma (csapatpontok és GY/V sor) a befejezett meccsekből',
      '„Legutóbbi egymás elleni meccsek” a következő mérkőzésnél (az aktuális és az előző alapszakaszból)',
    ],
    capabilities: [
      'Csapatlista (teams) és csapatmenetrend (teams/{csapat}/schedule) végpont',
      'Csapatfeloldás teljes névvel, rövidítéssel vagy becenévvel',
      'Felkészülési időszakban az alapszakasz menetrendjét is lekéri',
      'Befejezett, elhalasztott és törölt meccset nem mutat; bizonytalan időpontnál „később”',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem dokumentált végpont.',
    limit:
        'Nincs publikált kvóta; az app legfeljebb 30 kérés/perc sebességgel, best effort módon kérdez.',
    cache:
        'Sportolónként 6 órás lemezcache a naptáreseményekre, 7 napos a csapatlistára; hibánál a régebbi lista marad.',
    setup: 'Nincs teendő; a csapatot a sportoló adatlapján kell megadni.',
    fallback:
        'Hiba esetén a naptár apró megjegyzést mutat az adott sportolónál, a többi forrás ettől függetlenül betölt.',
    docsUrl:
        'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams/den/schedule',
  ),
  ProviderCatalogEntry(
    name: 'ESPN · Játékosadatok',
    sports: ['NBA', 'WNBA', 'NFL'],
    role:
        'Kulcs nélküli játékoskeresés és meccsnapló: NFL-játékosadat, valamint tartalék a Basketball Reference és a wehoop mellé.',
    visibleOutput: [
      'NFL-profil: játékos-meccsnapló, szezonösszesítő (passzolt / futott / elkapott yard, TD, INT, szerelés) és formagörbe',
      'NBA: ESPN-chip a forrásállapotok között; ha a Basketball Reference nem ad meccsnaplót vagy szezonátlagot, az ESPN-é látszik',
      'WNBA: ha a wehoop szezonfájlja nem érhető el vagy üres, az ESPN meccsnaplója és szezonátlaga',
      'Összehasonlítás: NFL-játékosok meccsenkénti átlagai; NBA/WNBA tartalékként',
    ],
    capabilities: [
      'Keresés: site.web.api.espn.com/apis/common/v3/search?type=player',
      'Meccsnapló: /apis/common/v3/sports/{sport}/{liga}/athletes/{id}/gamelog',
      'Szigorú, ékezet- és névsorrend-független névegyeztetés a ligán belül; soha nem az első találat',
      'Az oszlopokat név szerint olvassa (a sorrend ligánként eltér), a felkészülési meccsek kimaradnak',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem dokumentált végpont.',
    limit:
        'Nincs publikált kvóta; az ESPN közös, 30 kérés/perc korlátjából fogy (best effort).',
    cache:
        'Meccsnapló 6 óra, játékos-azonosító 7 nap (sikertelen keresés 24 óra) lemezcache-ben; hibánál a régebbi napló marad.',
    setup: 'Nincs teendő; NFL-nél a sportoló neve alapján keres.',
    fallback:
        'Ha az ESPN sem ad adatot, az elsődleges forrás (Basketball Reference / wehoop) hibája és a meglévő kártyák látszanak.',
    docsUrl:
        'https://site.web.api.espn.com/apis/common/v3/search?query=Jalen%20Hurts&type=player',
  ),
  ProviderCatalogEntry(
    name: 'ESPN · Élő eredmények',
    sports: ['NBA', 'WNBA', 'NFL', 'Foci'],
    role:
        'A követett sportolók csapatainak zajló és mai befejezett mérkőzései.',
    visibleOutput: [
      'Áttekintés: „Élő” sáv a lap tetején, csak ha éppen zajlik egy követett csapat meccse',
      'Profil: „Élő mérkőzés” kártya állással, negyeddel / perccel; látható oldalon 30 mp-enként frissül',
      'Értesítések: a befejezett meccs végeredménye gyorsabban jelez („Új eredmény”), opcionálisan „Élő eredményváltozás”',
    ],
    capabilities: [
      'WNBA, NFL: site/v2/sports/{sport}/{liga}/scoreboard',
      'Foci: soccer/all napi összesítő (Liga F-nél esp.w.1), csapatnév-egyeztetéssel',
      'NBA: tartalék, ha az NBA CDN nem érhető el',
      'A frissítés szünetel, ha az oldal nem látható vagy az ablak a tálcán van',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem dokumentált végpont.',
    limit:
        'Az ESPN közös, 30 kérés/perc korlátja; scoreboardonként legfeljebb 45 mp-enként egy kérés.',
    cache:
        '45 mp-es cache scoreboardonként (a nyitóoldal, a profil és a háttérfigyelő közösen használja).',
    setup: 'Nincs teendő; a sportoló csapatát kell megadni.',
    fallback:
        'Hibánál az utolsó ismert állás marad, a sáv / kártya rövid megjegyzést mutat; kitalált állás nem jelenik meg.',
    docsUrl:
        'https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard',
  ),
  ProviderCatalogEntry(
    name: 'NBA CDN · Élő eredmények',
    sports: ['NBA'],
    role: 'Az NBA hivatalos, nyilvános napi scoreboardja élő állással.',
    visibleOutput: [
      'NBA-meccsek állása, negyede és órája az „Élő” sávban és az „Élő mérkőzés” kártyán',
    ],
    capabilities: [
      'cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json',
      'gameStatus 1/2/3 (kezdés előtt / zajlik / vége), ISO-óra („PT05M32.00S”) feldolgozása',
    ],
    authentication: 'Nem kell API-kulcs.',
    limit:
        'Nincs publikált kvóta; a szerver kb. 10 mp-es cache-sel dolgozik, az app legfeljebb 20 kérés/perc sebességgel kérdez.',
    cache: '45 mp-es cache (közös az ESPN-tartalékkal).',
    setup: 'Nincs teendő.',
    fallback:
        'Egyes hálózatokról a CDN HTTP 403-at ad; ilyenkor automatikusan az ESPN NBA-scoreboardja látszik, a forrás jelzésével.',
    docsUrl:
        'https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json',
  ),
  ProviderCatalogEntry(
    name: 'ESPN · Mérkőzés-idővonal',
    sports: ['Foci', 'Női foci'],
    role: 'Gólok, lapok és cserék perccel az ESPN meccsösszefoglalójából.',
    visibleOutput: [
      'Lenyitható „Idővonal” a Liga F-meccseknél, az ESPN-klubmeccseknél, az élő focimeccsnél és ahol ESPN-mérkőzésazonosító ismert',
      'Gól (büntető, öngól), sárga és piros lap, csere — Material ikonokkal, hazai / vendég oldal szerint',
    ],
    capabilities: [
      'site/v2/sports/soccer/{liga}/summary?event={id} (ismeretlen ligánál soccer/all)',
      'A keyEvents sorai, tartalékként a header.competitions[0].details',
      'Csak lenyitáskor kér; a befejezett meccs idővonala végleges',
    ],
    authentication: 'Nem kell API-kulcs; nyilvános, nem dokumentált végpont.',
    limit: 'Az ESPN közös, 30 kérés/perc korlátja.',
    cache: 'Befejezett meccs: végleges (10 év) lemezcache; zajló meccs: 60 mp.',
    setup: 'Nincs teendő.',
    fallback:
        'Hibánál a lenyitott sáv rövid üzenetet mutat; a meccssor ettől független. Az OpenLigaDB-meccseknél a gólok az OpenLigaDB-ből jönnek.',
    docsUrl:
        'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.w.1/summary?event=401882508',
  ),
  ProviderCatalogEntry(
    name: 'OpenLigaDB',
    sports: ['Foci', 'Női foci'],
    role:
        'Német bajnokságok (Bundesliga, 2. Bundesliga, Frauen-Bundesliga) eredményei és menetrendje.',
    visibleOutput: [
      'Csapatmérkőzések kártya: az utolsó 5 eredmény és a következő 5 meccs, ha a többi forrás nem ad',
      'Naptár: a német csapatok közelgő meccsei, ha a football-data.org / ESPN / TheSportsDB nem ad',
      'Gólszerzők perccel a lejátszott meccsek „Idővonal” sávjában',
      'Egymás elleni meccsek az idei szezonból',
    ],
    capabilities: [
      'getavailableteams/{liga}/{szezon} csapatfeloldás (bl1, bl2, ffb1, régebbi női szezon: fbl1)',
      'getmatchdata/{liga}/{szezon} teljes szezonlista, végeredmény és gólok',
      'Az ismeretlen (1970-es) dátumú, még kiíratlan meccseket kihagyja',
    ],
    authentication: 'Nem kell API-kulcs; nyílt, közösségi adatbázis.',
    limit:
        'Nincs publikált kemény kvóta; az app kímélően, legfeljebb 30 kérés/perc sebességgel kérdez.',
    cache:
        'Csapatlista 7 nap, szezon-meccslista 1 óra lemezcache-ben; hibánál a régebbi lista.',
    setup: 'Nincs teendő; a csapatot a sportoló adatlapján kell megadni.',
    fallback:
        'Csak akkor kérdezi, ha a csapat német és a többi forrás nem adott adatot; hibánál rövid megjegyzés.',
    docsUrl: 'https://api.openligadb.de/index.html',
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
    setup:
        'Adatforrások → RapidAPI közös kulcs, vagy RAPIDAPI_KEY (a régi RAPIDAPI_DARTS_KEY is működik).',
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
      'Ranglistapont-történet a helyben, naponta rögzített mérésekből',
      'Egymás elleni mérleg (/h2h) a következő mérkőzésnél — csak BASIC csomaggal; Free kulccsal „Nem elérhető a Free csomagban” jelzés',
    ],
    capabilities: [
      'ATP, WTA, Challenger, ITF és junior sorozatok',
      'Free játékoskeresés és részletes játékosprofil',
      'Free élő és közelgő mérkőzések, aktuális pontállás és fixture lista',
      'A befejezett mérkőzéseket nem kéri le, mert azok History/BASIC hozzáféréshez kötöttek',
      'A /h2h végpontot csak a mérleg lenyitásakor hívja, 7 napos cache-sel; a 403-as (upgrade_required) választ barátságos üzenet jelzi',
    ],
    authentication: 'Ingyenes regisztrációs Bearer API-kulcs szükséges.',
    limit:
        'Free: 30 kérés/perc és 100 kérés/nap (a 2026. szeptemberi dokumentáció szerint); bankkártya nélkül. A /h2h BASIC csomagot igényel.',
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
        'SQLite-adatbázisban tartós megőrzés; a legújabb 5000 cikken túl az egy évnél régebbiek törlődnek.',
    setup:
        'Hírek → Források. A FOX és CBS alapból aktív; ESPN és Guardian opcionális.',
    fallback:
        'Forráshiba vagy internetkimaradás esetén a teljes korábbi helyi archívum megmarad.',
    docsUrl: 'https://www.espn.com/espn/news/story?page=rssinfo',
  ),
  ProviderCatalogEntry(
    name: 'GitHub Releases',
    sports: ['Alkalmazás'],
    role: 'Frissítés-ellenőrzés: van-e a futónál újabb Courtboard-kiadás.',
    visibleOutput: [
      '„Új verzió érhető el” sáv a felület tetején, a kiadás oldalára mutató Letöltés linkkel',
      'Beállítások → Frissítések: jelenlegi verzió, utolsó ellenőrzés eredménye',
    ],
    capabilities: [
      'A releases/latest végpont; előzetes (prerelease) és vázlat kiadásról nem szól',
      'Szemantikus verzió-összevetés a futó alkalmazás verziójával',
      'Semmit nem tölt le és nem telepít magától',
    ],
    authentication: 'Nem kell kulcs; a kérés User-Agent fejlécet küld.',
    limit:
        'Hitelesítés nélkül óránként 60 kérés IP-címenként; kéréskorlátnál barátságos üzenet.',
    cache: '12 órás lemezcache; a „Keresés most” gomb kikerüli.',
    setup:
        'Beállítások → Frissítések → Automatikus frissítés-ellenőrzés (alapból bekapcsolva).',
    fallback:
        'Hálózati hibánál a legutóbb mentett eredmény, különben csak egy üzenet a Beállításokban.',
    docsUrl:
        'https://docs.github.com/en/rest/releases/releases#get-the-latest-release',
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
