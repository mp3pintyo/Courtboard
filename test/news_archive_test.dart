import 'package:courtboard/data/news.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fox = NewsSource(
    id: 'fox_nba',
    name: 'FOX Sports',
    sport: 'NBA',
    url: 'https://example.com/feed',
    homepage: 'https://example.com',
  );

  test('undated RSS items are flagged as using the fetch time', () {
    final fetchedAt = DateTime(2026, 8, 2, 21);
    final article = RssParser.parse(
      '''
      <rss><channel><item>
        <title>No date</title>
        <link>https://example.com/no-date</link>
      </item></channel></rss>
    ''',
      fox,
      fetchedAt: fetchedAt,
    ).single;

    expect(article.publishedAt, fetchedAt);
    expect(article.publishedAtParsed, isFalse);
  });

  test('undated articles keep their first stored date on refresh', () async {
    final store = NewsStore(path: NewsStore.inMemoryPath);
    addTearDown(store.close);
    final first = DateTime(2026, 8, 1, 10);
    final later = DateTime(2026, 8, 1, 18);
    NewsArticle article(DateTime published, {required bool parsed}) =>
        NewsArticle(
          dedupeKey: 'url:https://example.com/undated',
          sourceId: 'fox_nba',
          sourceName: 'FOX Sports',
          sport: 'NBA',
          title: 'Undated story',
          url: 'https://example.com/undated',
          publishedAt: published,
          fetchedAt: published,
          publishedAtParsed: parsed,
        );

    await store.saveArticles([article(first, parsed: false)]);
    await store.saveArticles([article(later, parsed: false)]);
    expect((await store.query()).single.publishedAt, first);

    await store.saveArticles([article(later, parsed: true)]);
    expect((await store.query()).single.publishedAt, later);
  });

  test('concurrent first callers share one database connection', () async {
    final store = NewsStore(path: NewsStore.inMemoryPath);
    addTearDown(store.close);

    final databases = await Future.wait([
      store.database,
      store.database,
      store.database,
    ]);

    expect(identical(databases[0], databases[1]), isTrue);
    expect(identical(databases[1], databases[2]), isTrue);
  });

  test('feed links with non-web schemes are skipped', () {
    const source = NewsSource(
      id: 'fox_nba',
      name: 'FOX Sports',
      sport: 'NBA',
      url: 'https://prod-api.foxsports.com/fs/feed',
      homepage: 'https://www.foxsports.com/nba',
      format: NewsSourceFormat.foxPageFeed,
    );
    final articles = FoxPageFeedParser.parse(
      r'''
      {"data":{"results":[
        {"id":"a","component_type":"news_article","title":"Local file",
         "canonical_url":"file:///C:/Windows/win.ini"},
        {"id":"b","component_type":"news_article","title":"Script",
         "canonical_url":"javascript:alert(1)"},
        {"id":"c","component_type":"news_article","title":"UNC",
         "canonical_url":"\\\\server\\share\\file"},
        {"id":"d","component_type":"news_article","title":"Good",
         "canonical_url":"//www.foxsports.com/stories/nba/good",
         "thumbnail":{"url":"file:///C:/img.png"}}
      ]}}
    ''',
      source,
      fetchedAt: DateTime(2026, 8, 3),
    );
    final rss = RssParser.parse('''
      <rss><channel>
        <item><title>Bad</title><link>file:///C:/evil</link></item>
        <item><title>Good</title><link>https://example.com/ok</link></item>
      </channel></rss>
    ''', fox);

    expect(articles.map((article) => article.title), ['Good']);
    expect(articles.single.url, 'https://www.foxsports.com/stories/nba/good');
    expect(articles.single.imageUrl, isEmpty);
    expect(rss.map((article) => article.title), ['Good']);
  });
}
