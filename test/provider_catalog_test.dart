import 'package:courtboard/data/provider_catalog.dart';
import 'package:courtboard/data/sports_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog search covers output, quota and sport filters', () {
    expect(
        filterProviderCatalog('profilkép', 'Mind').single.name, 'TheSportsDB');
    expect(filterProviderCatalog('100 kérés/hó', 'WNBA').single.name,
        'RapidAPI · WNBA API');
    expect(filterProviderCatalog('Aitana', 'Női foci').single.name,
        'ESPN · Liga F');
    expect(filterProviderCatalog('', 'Darts').map((entry) => entry.name),
        containsAll(['TheSportsDB', 'RapidAPI · Darts API']));
  });

  test('catalog configuration state follows the shared RapidAPI key', () {
    const empty = SportsApiConfig();
    const configured = SportsApiConfig(rapidApiDartsKey: 'secret');
    final rapidEntries = providerCatalog
        .where((entry) => entry.key == ProviderKey.rapidApi)
        .toList();

    expect(rapidEntries, hasLength(2));
    expect(rapidEntries.every((entry) => !entry.isConfigured(empty)), isTrue);
    expect(
        rapidEntries.every((entry) => entry.isConfigured(configured)), isTrue);
  });

  test('YouTube Data API is explicitly marked as prepared', () {
    final youtubeData = providerCatalog
        .singleWhere((entry) => entry.name == 'YouTube Data API v3');

    expect(youtubeData.stage, ProviderStage.prepared);
    expect(youtubeData.visibleOutput.join(' '), contains('nincs'));
  });

  test('Live Tennis API documents free-safe tennis features and key state', () {
    final tennis =
        providerCatalog.singleWhere((entry) => entry.name == 'Live Tennis API');

    expect(filterProviderCatalog('1000 kérés/nap', 'Tenisz'), [tennis]);
    expect(tennis.isConfigured(const SportsApiConfig()), isFalse);
    expect(tennis.isConfigured(const SportsApiConfig(liveTennisKey: 'secret')),
        isTrue);
    expect(tennis.capabilities.join(' '), contains('nem kéri le'));
  });
}
