import 'package:courtboard/data/youtube_playlist.dart';
import 'package:courtboard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Athlete athlete(String name, String sport, Color accent) => Athlete(
        name: name,
        sport: sport,
        team: '',
        country: 'Teszt',
        photoUrl: '',
        accent: accent,
        seasonLabel: '',
        seasonValue: '',
        primaryLabel: '',
        primaryValue: '',
        metrics: const [],
        matches: const [],
      );

  SavedYouTubeVideo video(
          String id, String athleteName, String title, DateTime savedAt) =>
      SavedYouTubeVideo(
          videoId: id,
          athleteName: athleteName,
          title: title,
          thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          savedAt: savedAt);

  test('video library filters by title, athlete and sport and sorts newest',
      () {
    final jokic = athlete('Nikola Jokić', 'NBA', Colors.amber);
    final aitana = athlete('Aitana Bonmatí', 'Foci', Colors.blue);
    final entries = [
      VideoLibraryEntry(
          video: video('aaaaaaaaaaa', jokic.name, 'Jokić playoff highlights',
              DateTime(2026, 5, 1)),
          athlete: jokic),
      VideoLibraryEntry(
          video: video('bbbbbbbbbbb', aitana.name, 'Aitana assists',
              DateTime(2026, 7, 1)),
          athlete: aitana),
    ];

    expect(filterVideoLibrary(entries: entries).first.athleteName,
        'Aitana Bonmatí');
    expect(
        filterVideoLibrary(entries: entries, titleQuery: 'PLAYOFF')
            .single
            .athleteName,
        'Nikola Jokić');
    expect(
        filterVideoLibrary(entries: entries, athleteName: 'Aitana Bonmatí')
            .single
            .sport,
        'Foci');
    expect(
        filterVideoLibrary(entries: entries, sport: 'NBA').single.video.title,
        'Jokić playoff highlights');
  });

  test('removing a legacy unassigned video removes it from the playlist', () {
    final legacy = video('ccccccccccc', '', 'Régi videó', DateTime(2025));
    final playlist = AthleteVideoPlaylist(unassigned: [legacy]);

    expect(playlist.remove(legacy).unassigned, isEmpty);
  });

  testWidgets('video library renders cards and title search', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final jokic = athlete('Nikola Jokić', 'NBA', Colors.amber);
    final aitana = athlete('Aitana Bonmatí', 'Foci', Colors.blue);
    final playlist = AthleteVideoPlaylist(videos: [
      video('aaaaaaaaaaa', jokic.name, 'Jokić playoff highlights',
          DateTime(2026, 5, 1)),
      video('bbbbbbbbbbb', aitana.name, 'Aitana assists', DateTime(2026, 7, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VideoLibraryPage(
                athletes: [jokic, aitana],
                playlist: playlist,
                onOpenAthlete: (_) {},
                onRemoveVideo: (_) {},
                onOpenAthletes: () {}))));

    expect(find.text('Videók'), findsOneWidget);
    expect(find.text('2 videó'), findsOneWidget);
    expect(find.byKey(const Key('video-athlete-filter')), findsOneWidget);
    expect(find.byKey(const Key('video-sport-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-aaaaaaaaaaa-Nikola Jokić')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('video-bbbbbbbbbbb-Aitana Bonmatí')),
        findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('video-title-search')), 'assist');
    await tester.pump();

    expect(find.text('1 videó'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-aaaaaaaaaaa-Nikola Jokić')),
        findsNothing);
    expect(find.byKey(const ValueKey('video-bbbbbbbbbbb-Aitana Bonmatí')),
        findsOneWidget);
  });

  testWidgets('empty video library guides the user to athletes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VideoLibraryPage(
                athletes: const [],
                playlist: const AthleteVideoPlaylist(),
                onOpenAthlete: (_) {},
                onRemoveVideo: (_) {},
                onOpenAthletes: () {}))));

    expect(find.text('Még nincs mentett videód'), findsOneWidget);
    expect(find.text('Sportolók megnyitása'), findsOneWidget);
  });
}
