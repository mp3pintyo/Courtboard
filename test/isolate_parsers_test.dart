import 'package:courtboard/data/basketball_reference.dart';
import 'package:courtboard/data/news.dart';
import 'package:flutter_test/flutter_test.dart';

const _gameLogHtml = '''
<table id="player_game_log_reg"><tbody>
  <tr>
    <th data-stat="date">2025-04-10</th>
    <td data-stat="game_location">@</td>
    <td data-stat="opp_name_abbr">LAL</td>
    <td data-stat="game_result">W, 120-108</td>
    <td data-stat="mp">34:30</td>
    <td data-stat="pts">28</td><td data-stat="trb">12</td>
    <td data-stat="ast">9</td><td data-stat="stl">2</td>
    <td data-stat="blk">1</td><td data-stat="tov">3</td>
    <td data-stat="fg">10</td><td data-stat="fga">18</td>
    <td data-stat="game_score">27.2</td>
    <td data-stat="plus_minus">+14</td>
  </tr>
</tbody></table>
<!-- <table id="player_game_log_post"><tbody>
  <tr>
    <th data-stat="date">2025-05-01</th>
    <td data-stat="opp_name_abbr">LAC</td>
    <td data-stat="game_result">L, 101-104</td>
    <td data-stat="mp">39</td><td data-stat="pts">31</td>
  </tr>
</tbody></table> -->
''';

String _game(NbaGameLog game) => [
  game.date.toIso8601String(),
  game.opponent,
  game.outcome,
  game.location,
  game.minutes,
  game.points,
  game.rebounds,
  game.assists,
  game.turnovers,
  game.fieldGoalsMade,
  game.fieldGoalsAttempted,
  game.plusMinus,
  game.gameScore,
  game.score,
].join('|');

String _news(NewsArticle article) => [
  article.dedupeKey,
  article.sourceId,
  article.sourceName,
  article.sport,
  article.externalId,
  article.title,
  article.summary,
  article.url,
  article.imageUrl,
  article.author,
  article.publishedAt.toIso8601String(),
  article.publishedAtParsed,
  article.fetchedAt.toIso8601String(),
].join('|');

void main() {
  test(
    'Basketball Reference game logs parse identically in an isolate',
    () async {
      final sync = BasketballReferenceRepository.parseNbaGameLogHtml(
        _gameLogHtml,
      );
      final isolated =
          await BasketballReferenceRepository.parseNbaGameLogHtmlAsync(
            _gameLogHtml,
          );

      expect(sync, hasLength(2));
      expect(isolated.map(_game), sync.map(_game));
    },
  );

  test('WNBA last five, season summary and search parse identically', () async {
    const lastFive = '''
      <table id="last5"><tbody><tr>
        <th data-stat="date">2026-07-30</th>
        <td data-stat="opp_name_abbr">TOR</td>
        <td data-stat="game_result">W, 104-72</td>
        <td data-stat="mp">22</td><td data-stat="pts">12</td>
      </tr></tbody></table>''';
    expect(
      (await BasketballReferenceRepository.parseWnbaLastFiveHtmlAsync(
        lastFive,
      )).map(_game),
      BasketballReferenceRepository.parseWnbaLastFiveHtml(lastFive).map(_game),
    );

    const summaryHtml = '''
      <table><tbody><tr id="per_game_stats.2026">
        <td data-stat="team_name_abbr">DEN</td>
        <td data-stat="games">65</td>
        <td data-stat="pts_per_g">27.7</td>
        <td data-stat="fg_pct">.569</td>
      </tr></tbody></table>''';
    final summary =
        await BasketballReferenceRepository.parseNbaSeasonSummaryHtmlAsync(
          summaryHtml,
          preferredSeasonEndYear: 2026,
        );
    expect(
      summary?.toJson(),
      BasketballReferenceRepository.parseNbaSeasonSummaryHtml(
        summaryHtml,
        preferredSeasonEndYear: 2026,
      )?.toJson(),
    );
    expect(summary?.team, 'Denver Nuggets');

    const search = '''
      <a href="/players/j/jokicni01.html">Nikola Jokić (2016-2026)</a>
      <a href="/players/j/jokicni01.html">duplicate</a>
      <a href="/wnba/players/c/clarkca02w.html">Caitlin Clark (2024-2026)</a>''';
    expect(
      await BasketballReferenceRepository.parseSearchCandidatesAsync(
        search,
        league: 'nba',
      ),
      [('Nikola Jokić', '/players/j/jokicni01.html')],
    );
    expect(
      BasketballReferenceRepository.parseSearchCandidates(
        search,
        league: 'wnba',
      ),
      [('Caitlin Clark', '/wnba/players/c/clarkca02w.html')],
    );
  });

  test('RSS and FOX feeds parse identically in an isolate', () async {
    const rssSource = NewsSource(
      id: 'cbs_nba',
      name: 'CBS Sports',
      sport: 'NBA',
      url: 'https://example.com/rss',
      homepage: 'https://example.com',
    );
    const foxSource = NewsSource(
      id: 'fox_nba',
      name: 'FOX Sports',
      sport: 'NBA',
      url: 'https://example.com/fox',
      homepage: 'https://example.com',
      format: NewsSourceFormat.foxPageFeed,
    );
    const rss = '''
      <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <item>
          <title>Jokic &amp; Denver</title>
          <link>https://example.com/story?utm_source=rss</link>
          <guid>abc</guid>
          <pubDate>Tue, 29 Sep 2026 18:30:00 -0400</pubDate>
          <description><![CDATA[<p>Triple-double <b>again</b>.</p>]]></description>
          <media:thumbnail url="https://example.com/img.jpg"/>
        </item>
        <item><title>No date</title><link>https://example.com/b</link></item>
      </channel></rss>''';
    const fox = '''
      {"data":{"results":[
        {"id":"1","component_type":"news_article","title":"Fox story",
         "canonical_url":"//www.foxsports.com/stories/nba/one",
         "dek":"Short dek","thumbnail":{"url":"https://example.com/t.jpg"},
         "authors":[{"display_name":"A. Writer"}],
         "urls":{"original_publish_date":"2026-09-29T10:00:00Z"}}
      ]}}''';
    final fetchedAt = DateTime(2026, 9, 30, 8);

    for (final (body, source) in [(rss, rssSource), (fox, foxSource)]) {
      final sync = parseNewsFeed(body, source, fetchedAt: fetchedAt);
      final isolated = await parseNewsFeedAsync(
        body,
        source,
        fetchedAt: fetchedAt,
      );
      expect(sync, isNotEmpty);
      expect(isolated.map(_news), sync.map(_news));
    }
  });
}
