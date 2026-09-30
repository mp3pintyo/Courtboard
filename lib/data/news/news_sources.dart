import 'news_models.dart';

const newsRefreshInterval = Duration(minutes: 20);

const newsSources = <NewsSource>[
  NewsSource(
    id: 'fox_nba',
    name: 'FOX Sports',
    sport: 'NBA',
    url:
        'https://prod-api.foxsports.com/fs/feed?uri=basketball%2Fnba%2Fleague%2F1&component_type=news_article&size=100&from=0',
    homepage: 'https://www.foxsports.com/nba',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A FOX-oldal aktuális hírfolyama; kérésenként a legfrissebb 100 NBA-cikk.',
  ),
  NewsSource(
    id: 'fox_wnba',
    name: 'FOX Sports',
    sport: 'WNBA',
    url:
        'https://prod-api.foxsports.com/fs/feed?uri=basketball%2Fwnba%2Fleague%2F1&component_type=news_article&size=100&from=0',
    homepage: 'https://www.foxsports.com/wnba',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A régi FOX WNBA RSS elavult. Ez a forrás a FOX WNBA-oldal aktuális hírfolyamát használja, kérésenként 100 cikkel.',
  ),
  NewsSource(
    id: 'fox_soccer',
    name: 'FOX Sports',
    sport: 'Foci',
    url:
        'https://prod-api.foxsports.com/fs/feed?component_type=news_article&size=100&from=0&tags=fs%2Fsoccer%2Csoccer%2Fepl%2Fleague%2F1%2Csoccer%2Fmls%2Fleague%2F5%2Csoccer%2Fucl%2Fleague%2F7%2Csoccer%2Feuropa%2Fleague%2F8',
    homepage: 'https://www.foxsports.com/soccer',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A FOX-oldal aktuális hírfolyama; kérésenként a legfrissebb 100 focicikk.',
  ),
  NewsSource(
    id: 'fox_tennis',
    name: 'FOX Sports',
    sport: 'Tenisz',
    url:
        'https://prod-api.foxsports.com/fs/feed?component_type=news_article&size=100&from=0&tags=fs%2Fatp%2Cfs%2Fwta',
    homepage: 'https://www.foxsports.com/tennis',
    format: NewsSourceFormat.foxPageFeed,
    termsNote:
        'A régi FOX tenisz RSS több éves elemeket is adott. Ez a forrás az ATP/WTA oldal aktuális hírfolyamát használja, kérésenként 100 cikkel.',
  ),
  NewsSource(
    id: 'cbs_nba',
    name: 'CBS Sports',
    sport: 'NBA',
    url: 'https://www.cbssports.com/rss/headlines/nba',
    homepage: 'https://www.cbssports.com/nba/',
  ),
  NewsSource(
    id: 'cbs_soccer',
    name: 'CBS Sports',
    sport: 'Foci',
    url: 'https://www.cbssports.com/rss/headlines/soccer',
    homepage: 'https://www.cbssports.com/soccer/',
  ),
  NewsSource(
    id: 'cbs_tennis',
    name: 'CBS Sports',
    sport: 'Tenisz',
    url: 'https://www.cbssports.com/rss/headlines/tennis',
    homepage: 'https://www.cbssports.com/tennis/',
  ),
  NewsSource(
    id: 'espn_nba',
    name: 'ESPN',
    sport: 'NBA',
    url: 'https://www.espn.com/espn/rss/nba/news',
    homepage: 'https://www.espn.com/nba/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_wnba',
    name: 'ESPN',
    sport: 'WNBA',
    url: 'https://www.espn.com/espn/rss/wnba/news',
    homepage: 'https://www.espn.com/wnba/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_soccer',
    name: 'ESPN',
    sport: 'Foci',
    url: 'https://www.espn.com/espn/rss/soccer/news',
    homepage: 'https://www.espn.com/soccer/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'espn_tennis',
    name: 'ESPN',
    sport: 'Tenisz',
    url: 'https://www.espn.com/espn/rss/tennis/news',
    homepage: 'https://www.espn.com/tennis/',
    enabledByDefault: false,
    summaryEnabled: false,
    termsNote:
        'Csak az eredeti cím, ESPN-forrásmegjelölés és visszalink jelenik meg. Reklám nem kapcsolható a feed tartalmához.',
  ),
  NewsSource(
    id: 'guardian_football',
    name: 'The Guardian',
    sport: 'Foci',
    url: 'https://www.theguardian.com/football/rss',
    homepage: 'https://www.theguardian.com/football',
    enabledByDefault: false,
    termsNote: 'Személyes, nem kereskedelmi használatra kapcsolható be.',
  ),
  NewsSource(
    id: 'guardian_tennis',
    name: 'The Guardian',
    sport: 'Tenisz',
    url: 'https://www.theguardian.com/sport/tennis/rss',
    homepage: 'https://www.theguardian.com/sport/tennis',
    enabledByDefault: false,
    termsNote: 'Személyes, nem kereskedelmi használatra kapcsolható be.',
  ),
];
