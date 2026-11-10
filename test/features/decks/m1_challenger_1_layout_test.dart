import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

ExploreDeckWithVote buildDeckWithVote({
  required String id,
  required String name,
  String format = 'Commander',
  String tcgDomain = 'mtg',
  String sourceType = 'official',
  String creatorName = 'Official WotC',
  String? commanderName,
  String? commanderImageUrl,
  String? commanderArtCrop,
  String? featuredCategory,
  List<String> colorIdentity = const ['U'],
  int cardCount = 100,
  double estimatedPrice = 100.0,
  int upvotes = 10,
  int downvotes = 0,
  int score = 10,
  int userVote = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  final deck = ExploreDeck(
    id: id,
    name: name,
    format: format,
    tcgDomain: tcgDomain,
    sourceType: sourceType,
    creatorName: creatorName,
    commanderName: commanderName,
    commanderImageUrl: commanderImageUrl,
    commanderArtCrop: commanderArtCrop,
    featuredCategory: featuredCategory,
    colorIdentity: jsonEncode(colorIdentity),
    cardCount: cardCount,
    estimatedPrice: estimatedPrice,
    upvotes: upvotes,
    downvotes: downvotes,
    score: score,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    isDeleted: false,
  );
  return ExploreDeckWithVote(deck: deck, userVote: userVote);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    final now = DateTime.now();

    // 1. Seed Suggested Commanders
    for (int i = 1; i <= 4; i++) {
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_sug_comm_$i',
          name: i == 1
              ? 'Urza Lord High Artificer Extreme Artifact Ramp Combo Engine'
              : 'Suggested Commander #$i',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('official'),
          creatorName: const Value('Official WotC'),
          commanderName: const Value('Urza, Lord High Artificer'),
          commanderImageUrl: const Value('https://cards.scryfall.io/normal/front/u/r/urza.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/u/r/urza.jpg'),
          featuredCategory: const Value('Suggested Commanders'),
          colorIdentity: const Value('["U"]'),
          cardCount: const Value(100),
          estimatedPrice: Value(145.0 * i),
          upvotes: Value(42 * i),
          downvotes: const Value(3),
          score: Value(42 * i - 3),
          createdAt: now.subtract(Duration(days: i)),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }

    // 2. Seed From Top Deck Builders
    for (int i = 1; i <= 4; i++) {
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_top_builder_$i',
          name: i == 1
              ? 'Spicy Aristocrats Sacrifice Engine with Teysa Karlov'
              : 'Top Builder Deck #$i',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          creatorName: const Value('@SpicyBrewMasterOfficial'),
          commanderName: const Value('Teysa Karlov'),
          commanderImageUrl: const Value('https://cards.scryfall.io/normal/front/t/e/teysa.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/t/e/teysa.jpg'),
          featuredCategory: const Value('From Top Deck Builders'),
          colorIdentity: const Value('["W","B"]'),
          cardCount: const Value(100),
          estimatedPrice: Value(68.5 * i),
          upvotes: Value(88 * i),
          downvotes: const Value(5),
          score: Value(88 * i - 5),
          createdAt: now.subtract(Duration(days: i)),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }

    // 3. Seed Popular Standard Decks
    for (int i = 1; i <= 4; i++) {
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_pop_standard_$i',
          name: i == 1
              ? 'Mono Red Aggro Pro Fast Burn Deck Standard Ranked'
              : 'Popular Standard Deck #$i',
          format: 'Standard',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          creatorName: const Value('@DraftGuruChampion'),
          commanderName: const Value(''),
          featuredCategory: const Value('Popular Standard Decks'),
          colorIdentity: const Value('["R"]'),
          cardCount: const Value(60),
          estimatedPrice: Value(45.0 * i),
          upvotes: Value(60 * i),
          downvotes: const Value(4),
          score: Value(60 * i - 4),
          createdAt: now.subtract(Duration(days: i)),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }

    // 4. Seed General Grid Decks (Diverse Formats, 5-Color, High Values)
    for (int i = 1; i <= 14; i++) {
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_grid_$i',
          name: i % 2 == 0
              ? 'Adversarial Long Deck Title #$i Featuring Complex Synergies and Infinite Mana'
              : 'Deck #$i',
          format: i % 3 == 0 ? 'Commander' : (i % 3 == 1 ? 'Modern' : 'Pioneer'),
          tcgDomain: const Value('mtg'),
          sourceType: i % 4 == 0 ? const Value('official') : const Value('community'),
          creatorName: Value(i % 4 == 0 ? 'Official WotC' : '@ProPlayer_$i'),
          commanderName: Value(i % 2 == 0 ? 'Atraxa, Praetors\' Voice' : 'Ragavan, Nimble Pilferer'),
          commanderImageUrl: Value('https://cards.scryfall.io/normal/front/c/o/cover_$i.jpg'),
          commanderArtCrop: Value('https://cards.scryfall.io/art_crop/front/c/o/cover_$i.jpg'),
          colorIdentity: Value(i % 2 == 0 ? '["W","U","B","R","G"]' : '["R"]'),
          cardCount: Value(i % 3 == 0 ? 100 : 60),
          estimatedPrice: Value(i == 10 ? 9999.99 : 25.0 * i),
          upvotes: Value(i == 10 ? 9999 : 15 * i),
          downvotes: const Value(2),
          score: Value(i == 10 ? 9997 : 15 * i - 2),
          createdAt: now.subtract(Duration(hours: i * 3)),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({
    int initialTopTab = 1,
    double textScale = 1.0,
    ProviderContainer? container,
  }) {
    final home = Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: const DecksScreen(),
        );
      },
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: home,
          debugShowCheckedModeBanner: false,
        ),
      );
    }
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        decksTopTabProvider.overrideWith((ref) => initialTopTab),
      ],
      child: MaterialApp(
        home: home,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  // =========================================================================
  // GROUP 1: Ultra-Narrow Small Viewport (320x568 iPhone SE 1st gen)
  // =========================================================================
  group('1. Ultra-Narrow Viewport (320x568 iPhone SE 1st gen) Layout Stress', () {
    testWidgets('1.1 320x568 at standard 1.0x font scaling maintains zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.0));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        expect(scrollFinder, findsOneWidget);

        // Scroll down to expose the unified 2-column grid and back up
        for (int i = 0; i < 3; i++) {
          await tester.fling(scrollFinder, const Offset(0, -600), 2500);
          await tester.pumpAndSettle();
        }
        for (int i = 0; i < 3; i++) {
          await tester.fling(scrollFinder, const Offset(0, 600), 2500);
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 320x568 (1.0x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('1.2 320x568 with font scaling 1.25x maintains zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.25));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        expect(scrollFinder, findsOneWidget);

        for (int i = 0; i < 3; i++) {
          await tester.fling(scrollFinder, const Offset(0, -600), 2500);
          await tester.pumpAndSettle();
        }
        for (int i = 0; i < 3; i++) {
          await tester.fling(scrollFinder, const Offset(0, 600), 2500);
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 320x568 (1.25x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('1.3 320x568 with extreme font scaling 1.5x maintains zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.5));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        expect(scrollFinder, findsOneWidget);

        // Fling down through carousels to the grid
        for (int i = 0; i < 4; i++) {
          await tester.fling(scrollFinder, const Offset(0, -700), 2500);
          await tester.pumpAndSettle();
        }
        for (int i = 0; i < 4; i++) {
          await tester.fling(scrollFinder, const Offset(0, 700), 2500);
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 320x568 (1.5x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });
  });

  // =========================================================================
  // GROUP 2: Standard Viewports (375x812, 390x844) Across Font Scales
  // =========================================================================
  group('2. Standard Viewports (375x812, 390x844) Layout Stress', () {
    testWidgets('2.1 375x812 at standard 1.0x font scale with carousel and grid scrolling', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.0));
        await tester.pumpAndSettle();

        final carousel1 = find.byKey(const Key('explore_carousel_suggested_commanders'));
        expect(carousel1, findsOneWidget);
        await tester.fling(carousel1, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1200), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 375x812 (1.0x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('2.2 375x812 at 1.5x font scale with carousel and grid scrolling', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.5));
        await tester.pumpAndSettle();

        final carousel1 = find.byKey(const Key('explore_carousel_suggested_commanders'));
        expect(carousel1, findsOneWidget);
        await tester.fling(carousel1, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1200), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 375x812 (1.5x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('2.3 390x844 at standard 1.0x font scale with full carousel navigation', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.0));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        final carousel1 = find.byKey(const Key('explore_carousel_suggested_commanders'));
        expect(carousel1, findsOneWidget);
        await tester.fling(carousel1, const Offset(-250, 0), 1000);
        await tester.pumpAndSettle();

        await tester.fling(scrollFinder, const Offset(0, -1500), 2000);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 390x844 (1.0x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('2.4 390x844 at 1.25x font scale with carousel and grid scrolling', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.25));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        final carousel1 = find.byKey(const Key('explore_carousel_suggested_commanders'));
        expect(carousel1, findsOneWidget);
        await tester.fling(carousel1, const Offset(-250, 0), 1000);
        await tester.pumpAndSettle();

        await tester.fling(scrollFinder, const Offset(0, -1500), 2000);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 390x844 (1.25x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });

    testWidgets('2.5 390x844 at 1.5x font scale with carousel and grid scrolling', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.5));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        final carousel1 = find.byKey(const Key('explore_carousel_suggested_commanders'));
        expect(carousel1, findsOneWidget);
        await tester.fling(carousel1, const Offset(-250, 0), 1000);
        await tester.pumpAndSettle();

        await tester.fling(scrollFinder, const Offset(0, -1500), 2000);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 390x844 (1.5x): ${overflowErrors.map((e) => e.exceptionAsString()).toList()}',
      );
    });
  });

  // =========================================================================
  // GROUP 3: Large Tablet & Desktop Viewports (800x1200, 1200x800)
  // =========================================================================
  group('3. Large Tablet & Desktop Viewports (800x1200, 1200x800)', () {
    testWidgets('3.1 800x1200 tablet portrait at 1.0x font scale', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.0));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1500), 2500);
        await tester.pumpAndSettle();
        await tester.fling(scrollFinder, const Offset(0, 1500), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 800x1200 (1.0x)',
      );
    });

    testWidgets('3.2 800x1200 tablet portrait at 1.5x font scale', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.5));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1500), 2500);
        await tester.pumpAndSettle();
        await tester.fling(scrollFinder, const Offset(0, 1500), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 800x1200 (1.5x)',
      );
    });

    testWidgets('3.3 1200x800 desktop landscape at 1.0x font scale', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.0));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1000), 2500);
        await tester.pumpAndSettle();
        await tester.fling(scrollFinder, const Offset(0, 1000), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 1200x800 (1.0x)',
      );
    });

    testWidgets('3.4 1200x800 desktop landscape at 1.5x font scale', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final caughtErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      try {
        await tester.pumpWidget(createSubject(initialTopTab: 1, textScale: 1.5));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        await tester.fling(scrollFinder, const Offset(0, -1000), 2500);
        await tester.pumpAndSettle();
        await tester.fling(scrollFinder, const Offset(0, 1000), 2500);
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = originalOnError;
      }

      final overflowErrors = caughtErrors.where((e) => e.toString().contains('RenderFlex overflowed'));
      expect(
        overflowErrors.isEmpty,
        isTrue,
        reason: 'RenderFlex overflow detected at 1200x800 (1.5x)',
      );
    });
  });

  // =========================================================================
  // GROUP 4: Card Presentation, MTG Aspect Ratio & Format Badge Placement
  // =========================================================================
  group('4. Card Presentation, MTG Aspect Ratio & Format Badge Invariants', () {
    testWidgets('4.1 ExploreDeckCard renders card art in uncropped 63 / 88 aspect ratio', (tester) async {
      final sampleDeck = buildDeckWithVote(
        id: 'test_aspect_deck',
        name: 'Aspect Ratio Verification Deck',
        format: 'Commander',
        sourceType: 'official',
        creatorName: 'Official WotC',
        commanderName: 'Urza, Lord High Artificer',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/u/r/urza.jpg',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/u/r/urza.jpg',
        colorIdentity: const ['U'],
        cardCount: 100,
        estimatedPrice: 250.0,
        upvotes: 40,
        downvotes: 2,
        score: 38,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 175,
                  child: ExploreDeckCard(
                    deckWithVote: sampleDeck,
                    isCompact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find AspectRatio widget in card
      final aspectRatioFinder = find.descendant(
        of: find.byType(ExploreDeckCard),
        matching: find.byType(AspectRatio),
      );
      expect(aspectRatioFinder, findsOneWidget);

      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      const expectedRatio = 63.0 / 88.0;
      expect(
        (aspectRatioWidget.aspectRatio - expectedRatio).abs(),
        lessThan(0.001),
        reason: 'ExploreDeckCard must maintain MTG 63/88 aspect ratio (~0.7159)',
      );

      final renderBox = tester.renderObject(aspectRatioFinder) as RenderBox;
      final size = renderBox.size;
      // Container width is 175 with 1px border on each side, yielding 173px inner width
      expect(size.width, equals(173.0));
      expect((size.height - (173.0 / expectedRatio)).abs(), lessThan(0.5));
      expect(((size.width / size.height) - expectedRatio).abs(), lessThan(0.001));
    });

    testWidgets('4.2 ExploreDeckCard prioritizes commanderImageUrl (normal) over commanderArtCrop', (tester) async {
      final sampleDeck = buildDeckWithVote(
        id: 'test_priority_deck',
        name: 'Image Priority Deck',
        format: 'Commander',
        sourceType: 'community',
        creatorName: '@Brewer',
        commanderName: 'Atraxa',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/a/t/atraxa.jpg',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/a/t/atraxa.jpg',
        colorIdentity: const ['W', 'U', 'B', 'G'],
        cardCount: 100,
        estimatedPrice: 120.0,
        upvotes: 10,
        downvotes: 0,
        score: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 175,
                child: ExploreDeckCard(deckWithVote: sampleDeck),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImageFinder = find.descendant(
        of: find.byType(ExploreDeckCard),
        matching: find.byType(CountrCachedImage),
      );
      expect(cachedImageFinder, findsOneWidget);

      final CountrCachedImage imageWidget = tester.widget(cachedImageFinder);
      expect(imageWidget.imageUrl, equals('https://cards.scryfall.io/normal/front/a/t/atraxa.jpg'));
    });

    testWidgets('4.3 Format badge is positioned at top-left (top: 6, left: 6) inside card boundary', (tester) async {
      final sampleDeck = buildDeckWithVote(
        id: 'test_badge_deck',
        name: 'Badge Placement Deck',
        format: 'Commander',
        sourceType: 'official',
        creatorName: 'Official WotC',
        commanderName: 'Urza',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/u/r/urza.jpg',
        colorIdentity: const ['U'],
        cardCount: 100,
        estimatedPrice: 100.0,
        upvotes: 5,
        downvotes: 0,
        score: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 175,
                  child: ExploreDeckCard(deckWithVote: sampleDeck),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the card container RenderBox
      final cardFinder = find.byType(ExploreDeckCard);
      final RenderBox cardBox = tester.renderObject(cardFinder);
      final cardTopLeft = cardBox.localToGlobal(Offset.zero);

      // Find format badge text "Commander"
      final badgeFinder = find.text('Commander');
      expect(badgeFinder, findsOneWidget);
      final RenderBox badgeBox = tester.renderObject(badgeFinder);
      final badgeTopLeft = badgeBox.localToGlobal(Offset.zero);

      // Verify badge is inside card with expected top/left padding
      final relativeLeft = badgeTopLeft.dx - cardTopLeft.dx;
      final relativeTop = badgeTopLeft.dy - cardTopLeft.dy;

      // Card border is 1px, badge Positioned is top: 6, left: 6, plus container padding horizontal: 5, vertical: 1.5
      expect(relativeLeft, greaterThanOrEqualTo(6.0));
      expect(relativeTop, greaterThanOrEqualTo(6.0));
      // Ensure badge does NOT extend past right boundary
      expect(badgeTopLeft.dx + badgeBox.size.width, lessThan(cardTopLeft.dx + cardBox.size.width));
    });
  });

  // =========================================================================
  // GROUP 5: Bottom Quick-Info Block Containment & Content Invariants
  // =========================================================================
  group('5. Bottom Quick-Info Block Containment & Content Invariants', () {
    testWidgets('5.1 Extreme text lengths and values do not break layout containment', (tester) async {
      final extremeDeck = buildDeckWithVote(
        id: 'test_extreme_deck',
        name: 'Extremely Long Deck Name Exceeding Normal Limits To Verify Ellipsis And Containment In 2-Column Grid',
        format: 'Commander',
        sourceType: 'community',
        creatorName: '@SuperDuperLongAuthorHandleExceedingCellBoundary12345',
        commanderName: 'Nicol Bolas, Dragon-God',
        colorIdentity: const ['U', 'B', 'R'],
        cardCount: 100,
        estimatedPrice: 99999.99,
        upvotes: 99999,
        downvotes: 1234,
        score: 98765,
        userVote: 1,
      );

      // Test inside a narrow cell (width: 139 - iPhone SE grid cell width)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 139,
                  child: ExploreDeckCard(
                    deckWithVote: extremeDeck,
                    cardMatch: ExploreDeckCardMatch(
                      deckWithVote: extremeDeck,
                      matchingCardName: 'Nicol Bolas, Dragon-God',
                      cardQuantity: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title truncated cleanly with ellipsis without overflow
      expect(find.textContaining('Extremely Long Deck Name'), findsOneWidget);
      expect(find.textContaining('SuperDuperLongAuthor'), findsOneWidget);
      expect(find.textContaining('contains: Nicol Bolas'), findsOneWidget);
      expect(find.text('\$99999.99'), findsOneWidget);
      expect(find.text('98765'), findsOneWidget);
    });

    testWidgets('5.2 5-Color identity mana pips stay cleanly within quick-info block', (tester) async {
      final rainbowDeck = buildDeckWithVote(
        id: 'test_rainbow_deck',
        name: '5-Color Omnath Rainbow',
        format: 'Commander',
        sourceType: 'official',
        creatorName: 'Official WotC',
        commanderName: 'Omnath, Locus of All',
        colorIdentity: const ['W', 'U', 'B', 'R', 'G'],
        cardCount: 100,
        estimatedPrice: 350.0,
        upvotes: 50,
        downvotes: 2,
        score: 48,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 139,
                  child: ExploreDeckCard(deckWithVote: rainbowDeck),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(ExploreDeckCard);
      final RenderBox cardBox = tester.renderObject(cardFinder);
      final cardRect = cardBox.localToGlobal(Offset.zero) & cardBox.size;

      // Verify price and voting cluster are completely inside card bounds
      final priceFinder = find.text('\$350.00');
      final RenderBox priceBox = tester.renderObject(priceFinder);
      final priceRect = priceBox.localToGlobal(Offset.zero) & priceBox.size;

      expect(cardRect.contains(priceRect.topLeft), isTrue);
      expect(cardRect.contains(priceRect.bottomRight), isTrue);
    });
  });

  // =========================================================================
  // GROUP 6: Carousel Section Dimensions & Unified Grid Section Header
  // =========================================================================
  group('6. Carousel Section Dimensions & Unified Grid Hierarchy Invariants', () {
    testWidgets('6.1 Carousel horizontal list view has exact height 350px and elevated styling', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      final carouselFinder = find.byKey(const Key('explore_carousel_suggested_commanders'));
      expect(carouselFinder, findsOneWidget);

      final RenderBox carouselBox = tester.renderObject(carouselFinder);
      // Container includes vertical margins and vertical padding + 350 SizedBox + header
      expect(carouselBox.size.height, greaterThan(350.0));

      // Locate horizontal SizedBox with height: 350
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(of: carouselFinder, matching: find.byType(SizedBox)),
      );
      final height350Box = sizedBoxes.where((b) => b.height == 350.0);
      expect(height350Box.isNotEmpty, isTrue, reason: 'Horizontal carousel ListView must be sized at 350px');
    });

    testWidgets('6.2 "All Explore Decks" section header separates carousels from the unified 2-column grid', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Drag down past the first lead carousel to reveal the unified 2-column grid and header
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      // Find section header
      expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
      expect(find.byKey(const Key('explore_all_decks_header')), findsOneWidget);

      // Verify grid delegate childAspectRatio is 0.74
      final gridFinder = find.byType(SliverGrid);
      expect(gridFinder, findsWidgets);
      final SliverGrid gridWidget = tester.widget(gridFinder.first);
      final delegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));
      expect(delegate.childAspectRatio, equals(0.74));
    });
  });
}
