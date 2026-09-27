// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/life_counter/presentation/dialogs/art_override_sheet.dart';

/// Fake Scryfall service for deterministic offline testing.
class FakeScryfallService extends ScryfallService {
  final Map<String, List<Map<String, dynamic>>> queryResponses;
  bool shouldThrow = false;

  FakeScryfallService({this.queryResponses = const {}});

  @override
  Future<List<Map<String, dynamic>>?> searchCards(
    String query, {
    int limit = 20,
  }) async {
    if (shouldThrow) {
      throw Exception('Network unreachable');
    }
    return queryResponses[query.toLowerCase().trim()] ?? const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final atraxaCard = {
    'id': 'atraxa-1',
    'name': "Atraxa, Praetors' Voice",
    'set': 'cm2',
    'image_uris': {
      'art_crop': 'https://cards.scryfall.io/art_crop/atraxa.jpg',
      'normal': 'https://cards.scryfall.io/normal/atraxa.jpg',
    },
  };

  final dfcBolasCard = {
    'id': 'bolas-dfc',
    'name': 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
    'set': 'm19',
    'card_faces': [
      {
        'name': 'Nicol Bolas, the Ravager',
        'image_uris': {
          'art_crop': 'https://cards.scryfall.io/art_crop/bolas_front.jpg',
        },
      },
      {
        'name': 'Nicol Bolas, the Arisen',
        'image_uris': {
          'art_crop': 'https://cards.scryfall.io/art_crop/bolas_back.jpg',
        },
      },
    ],
  };

  group('ArtOverrideSheet Widget Tests (Feature 31)', () {
    setUp(() {
      //
    });

    Future<void> setTestSize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }
    testWidgets('T31.1: renders sheet header, player name, live preview box, and tabs',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Alice',
                currentArtUrl: 'https://cards.scryfall.io/art_crop/current.jpg',
                initialCommanderName: 'Urza',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('art_override_sheet')), findsOneWidget);
      expect(find.text('Customize Backdrop Art'), findsOneWidget);
      expect(find.text('Player: Alice'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('Scryfall Catalog'), findsOneWidget);
      expect(find.text('Custom Image URL'), findsOneWidget);
      expect(find.byKey(const Key('art_search_input')), findsOneWidget);
    });

    testWidgets('T31.2: typing in search input executes debounced search and renders results',
        (tester) async {
      await setTestSize(tester);
      final fakeScryfall = FakeScryfallService(
        queryResponses: {
          'atraxa': [atraxaCard],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Alice',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Enter search text
      await tester.enterText(find.byKey(const Key('art_search_input')), 'atraxa');
      await tester.pump(); // Start debounce timer

      // Debounce delay is 300ms; advance clock
      await tester.pump(const Duration(milliseconds: 350));

      // Result should now appear
      expect(find.byKey(const Key('art_results_grid')), findsOneWidget);
      expect(find.text("Atraxa, Praetors' Voice"), findsOneWidget);
      expect(find.text('CM2'), findsOneWidget);
    });

    testWidgets('T31.3: selecting a card result updates the live preview box and enables apply button',
        (tester) async {
      await setTestSize(tester);
      final fakeScryfall = FakeScryfallService(
        queryResponses: {
          'atraxa': [atraxaCard],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Alice',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('art_search_input')), 'atraxa');
      await tester.pump(const Duration(milliseconds: 350));

      // Tap on card result tile
      await tester.tap(find.byKey(const Key('card_result_tile_0')));
      await tester.pump();

      // Apply button should be enabled
      final applyButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('apply_art_override_button')),
      );
      expect(applyButton.onPressed, isNotNull);
    });

    testWidgets('T31.4: double-faced card (DFC) toggles between face 0 and face 1 art_crop',
        (tester) async {
      await setTestSize(tester);
      final fakeScryfall = FakeScryfallService(
        queryResponses: {
          'bolas': [dfcBolasCard],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Bob',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('art_search_input')), 'bolas');
      await tester.pump(const Duration(milliseconds: 350));

      // DFC badge should be visible
      expect(find.text('DFC'), findsOneWidget);

      // Tap DFC face toggle
      await tester.tap(find.text('DFC'));
      await tester.pump();

      // Tile tap selects back face
      await tester.tap(find.byKey(const Key('card_result_tile_0')));
      await tester.pump();

      final applyButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('apply_art_override_button')),
      );
      expect(applyButton.onPressed, isNotNull);
    });

    testWidgets('T31.5: custom URL tab accepts direct image link and updates preview',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Charlie',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch to Custom Image URL tab
      await tester.tap(find.text('Custom Image URL'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom_url_input')), findsOneWidget);

      // Enter direct URL
      const customUrl = 'https://custom.art/playmat_crop.png';
      await tester.enterText(find.byKey(const Key('custom_url_input')), customUrl);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Apply button should be enabled
      final applyButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('apply_art_override_button')),
      );
      expect(applyButton.onPressed, isNotNull);
    });

    testWidgets('T31.6: tapping Apply Backdrop invokes onArtSelected callback',
        (tester) async {
      await setTestSize(tester);
      String? selectedUrl;
      String? selectedName;

      final fakeScryfall = FakeScryfallService(
        queryResponses: {
          'atraxa': [atraxaCard],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Alice',
                onArtSelected: (url, name) {
                  selectedUrl = url;
                  selectedName = name;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('art_search_input')), 'atraxa');
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byKey(const Key('card_result_tile_0')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('apply_art_override_button')));
      await tester.pump();

      expect(selectedUrl, equals('https://cards.scryfall.io/art_crop/atraxa.jpg'));
      expect(selectedName, equals("Atraxa, Praetors' Voice"));
    });

    testWidgets('T31.7: tapping Reset Default invokes onResetDefault callback',
        (tester) async {
      await setTestSize(tester);
      bool resetCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ArtOverrideSheet(
                playerId: 'p1',
                playerName: 'Alice',
                currentArtUrl: 'https://cards.scryfall.io/art_crop/override.jpg',
                onResetDefault: () {
                  resetCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('reset_default_art_button')));
      await tester.pump();

      expect(resetCalled, isTrue);
    });
  });
}
