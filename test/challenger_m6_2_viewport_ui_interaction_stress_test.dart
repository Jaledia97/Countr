// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 2 Milestone 6: Viewport, UI & Interaction Empirical Stress Suite
//
// Verification Scope:
// 1. 320x640 Viewport & TextScaler.linear(2.0) Constraint Verification:
//    - CardDetailSheet across Sections 7, 8, and 9.
//    - Zero RenderFlex overflows under severe screen and font scale constraints.
//    - Bounding box checks ensuring horizontal containment within 320px.
// 2. Extreme 5-to-6 figure prices ($349,999.00):
//    - Finish chips, header prices, and portfolio metrics scale/wrap cleanly.
//    - Zero overflow or text truncation crashes.
// 3. Rapid burst-tapping on finish chips and reputation upvote/downvote buttons:
//    - High-frequency successive taps without race conditions or SQLite corruption.
//    - Toggle logic (upvote -> downvote -> neutral) produces strictly valid mathematical scores.
// 4. VersionsAndPrintingsModal lifecycle, upper-left back button & candidate deduplication:
//    - Header back button (Key('versions_printings_back_button')) dismisses cleanly.
//    - Active printing deduplication across set and collector number.
//    - Tapping active printing dismisses without duplicate navigation.
// 5. Search bar internal 'X' button keystroke debouncing & clear responsiveness:
//    - Immediate 0ms suffixIcon transition to clear button.
//    - Exact debounce delay verification.
//    - Synchronous text clear and reset.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/versions_printings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'owned-ring-001',
    String name = 'The One Ring',
    String setCode = 'ltr',
    String setName = 'The Lord of the Rings: Tales of Middle-earth',
    String collectorNumber = '0269',
    double price = 65.00,
    int quantity = 1,
    int reputationScore = 42,
    int userVote = 0,
    List<String> finishes = const [
      'nonfoil',
      'foil',
      'etched',
      'surgefoil',
      'textured',
    ],
    Map<String, dynamic>? pricesMap,
    Map<String, dynamic>? legalitiesMap,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/ltr/0269.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 6, 23),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 6, 23),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'oracle_text':
            'Indestructible\nWhen The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.\nAt the beginning of your upkeep, you lose 1 life for each burden counter on The One Ring.\n{T}: Put a burden counter on The One Ring, then draw a card for each burden counter on The One Ring.',
        'flavor_text': 'One Ring to rule them all, One Ring to find them...',
        'artist': 'Tania Sanchez Fortun',
        'type_line': 'Legendary Artifact',
        'finishes': finishes,
        'reputation_score': reputationScore,
        'user_vote': userVote,
        'prices': pricesMap ?? {
          'usd': '65.00',
          'usd_foil': '95.00',
          'usd_etched': '120.00',
          'usd_surge': '250.00',
          'usd_textured': '350.00',
        },
        'finish': 'nonfoil',
        'treatment': 'Non-Foil',
        'legalities': legalitiesMap ?? {
          'commander': 'legal',
          'standard': 'not_legal',
          'modern': 'legal',
          'pioneer': 'not_legal',
          'legacy': 'legal',
          'vintage': 'restricted',
          'pauper': 'not_legal',
          'brawl': 'legal',
          'oathbreaker': 'legal',
          'historic': 'banned',
        },
      }),
    );
  }

  VaultItem createCatalogVariant({
    required String id,
    required String name,
    required String setCode,
    required String setName,
    required String collectorNumber,
    required double price,
    String? borderColor,
    List<String> frameEffects = const [],
    List<String> finishes = const ['nonfoil', 'foil'],
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 6, 23),
      quantity: 0,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 6, 23),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'border_color': borderColor,
        'frame_effects': frameEffects,
        'finishes': finishes,
        'prices': {'usd': price.toStringAsFixed(2)},
        'legalities': {
          'commander': 'legal',
          'modern': 'legal',
          'legacy': 'legal',
          'vintage': 'restricted',
        },
      }),
    );
  }

  Widget createHarness({
    required Widget child,
    bool staticPrivacyMode = false,
    Size viewportSize = const Size(800, 2600),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        privacyModeProvider.overrideWith((ref) => staticPrivacyMode),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  Future<void> scrollDownUntil(WidgetTester tester, Finder finder, {int maxDrags = 16}) async {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    final scrollable = scrollables.last;
    for (int i = 0; i < maxDrags; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(scrollable, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
  }

  // ===========================================================================
  // Requirement 1: 320x640 Viewport & TextScaler.linear(2.0) Across Sections 7, 8, 9
  // ===========================================================================
  group('1. 320x640 Viewport with TextScaler 2.0x Stress (Sections 7, 8, 9)', () {
    testWidgets(
      'CardDetailSheet under 320x640 with TextScaler 2.0x renders Sections 7, 8, and 9 with ZERO RenderFlex overflows',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        final List<FlutterErrorDetails> recordedErrors = [];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          recordedErrors.add(details);
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
            viewportSize: const Size(320, 640),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CardDetailSheet), findsOneWidget);

        // --- Section 7: Treatments & See More Button ---
        final section7Finder = find.byKey(const Key('section_variant_price_chart'));
        await scrollDownUntil(tester, section7Finder);
        expect(section7Finder, findsOneWidget, reason: 'Section 7 (Treatments) must be present');

        // Verify treatment chips are present and contained within 320px
        final chipNonfoil = find.byKey(const Key('treatment_chip_nonfoil'));
        final chipFoil = find.byKey(const Key('treatment_chip_foil'));
        final chipEtched = find.byKey(const Key('treatment_chip_etched'));
        expect(chipNonfoil, findsOneWidget);
        expect(chipFoil, findsOneWidget);
        expect(chipEtched, findsOneWidget);

        final nonfoilRect = tester.getRect(chipNonfoil);
        expect(nonfoilRect.left, greaterThanOrEqualTo(0.0));
        expect(nonfoilRect.right, lessThanOrEqualTo(320.0 + 1.0));

        final seeMoreButton = find.byKey(const Key('card_detail_see_more_versions_button'));
        expect(seeMoreButton, findsOneWidget);
        final seeMoreRect = tester.getRect(seeMoreButton);
        expect(seeMoreRect.left, greaterThanOrEqualTo(0.0));
        expect(seeMoreRect.right, lessThanOrEqualTo(320.0 + 1.0));

        // --- Section 8: Format Legalities (10 formats) ---
        final section8Finder = find.byKey(const Key('section_format_legalities'));
        await scrollDownUntil(tester, section8Finder);
        expect(section8Finder, findsOneWidget, reason: 'Section 8 (Format Legalities) must be present');

        final expectedFormats = [
          'commander',
          'standard',
          'modern',
          'pioneer',
          'legacy',
          'vintage',
          'pauper',
          'brawl',
          'oathbreaker',
          'historic',
        ];

        for (final format in expectedFormats) {
          final pillFinder = find.byKey(Key('legality_pill_$format'));
          expect(pillFinder, findsOneWidget, reason: 'Format pill for $format must exist');
          final pillRect = tester.getRect(pillFinder);
          expect(pillRect.left, greaterThanOrEqualTo(0.0), reason: '$format pill clipped left');
          expect(pillRect.right, lessThanOrEqualTo(320.0 + 1.0), reason: '$format pill overflows right');
        }

        // --- Section 9: Metadata & Pedigree ---
        final section9Finder = find.byKey(const Key('section_metadata_pedigree'));
        await scrollDownUntil(tester, section9Finder);
        expect(section9Finder, findsOneWidget, reason: 'Section 9 (Metadata & Pedigree) must be present');

        final collectorFinder = find.byKey(const Key('card_detail_collector_number'));
        expect(collectorFinder, findsOneWidget);
        final collectorRect = tester.getRect(collectorFinder);
        expect(collectorRect.left, greaterThanOrEqualTo(0.0));
        expect(collectorRect.right, lessThanOrEqualTo(320.0 + 1.0));

        // Verify ZERO RenderFlex overflow errors
        final overflowErrors = recordedErrors
            .where((e) => e.toString().toLowerCase().contains('overflowed'))
            .toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Expected 0 RenderFlex overflow errors, found: ${overflowErrors.map((e) => e.exception).toList()}',
        );
      },
    );
  });

  // ===========================================================================
  // Requirement 2: Extreme 5-to-6 Figure Prices ($349,999.00) Viewport Scaling
  // ===========================================================================
  group(r'2. Extreme 5-to-6 Figure Prices ($349,999.00) Viewport Scaling', () {
    testWidgets(
      r'CardDetailSheet handles 6-figure prices ($349,999.00) on 320x640 with TextScaler 2.0x without overflows',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final extremeCard = createTestCard(
          price: 349999.00,
          pricesMap: {
            'usd': '349999.00',
            'usd_foil': '349999.00',
            'usd_etched': '349999.00',
            'usd_surge': '349999.00',
            'usd_textured': '349999.00',
          },
        );
        await db.into(db.vaultItems).insert(extremeCard);

        final List<FlutterErrorDetails> recordedErrors = [];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          recordedErrors.add(details);
          oldOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldOnError);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: extremeCard, fetchOnlinePrintings: false),
            viewportSize: const Size(320, 640),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial screen: Header price rendered
        expect(tester.takeException(), isNull);

        // 2. Scroll to Section 7: Treatments
        final section7Finder = find.byKey(const Key('section_variant_price_chart'));
        await scrollDownUntil(tester, section7Finder);
        expect(section7Finder, findsOneWidget);

        // Treatments chips display 6-figure formatted price ($349999.00)
        final priceMatches = find.text(r'$349999.00');
        expect(priceMatches, findsWidgets);

        // Verify chips fit within bounds
        final chipFinder = find.byKey(const Key('treatment_chip_nonfoil'));
        final chipRect = tester.getRect(chipFinder);
        expect(chipRect.left, greaterThanOrEqualTo(0.0));
        expect(chipRect.right, lessThanOrEqualTo(320.0 + 1.0));

        // 3. Zero overflows
        final overflowErrors = recordedErrors
            .where((e) => e.toString().toLowerCase().contains('overflowed'))
            .toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Expected 0 RenderFlex overflow errors with \$349,999.00 prices, found: $overflowErrors',
        );
      },
    );
  });

  // ===========================================================================
  // Requirement 3: Rapid Burst-Tapping on Finish Chips and Reputation Buttons
  // ===========================================================================
  group('3. Rapid Burst-Tapping on Finish Chips & Reputation Buttons', () {
    testWidgets(
      'Burst-tapping finish chips: 10 rapid taps persist cleanly in SQLite with zero race conditions or unhandled crashes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Burst-tap sequence of 10 rapid taps:
        final sequence = [
          'foil',
          'etched',
          'surge',
          'textured',
          'foil',
          'etched',
          'nonfoil',
          'surge',
          'foil',
          'textured', // Target finish: textured ($350.00)
        ];

        for (final finish in sequence) {
          final chip = find.byKey(Key('treatment_chip_$finish'));
          expect(chip, findsOneWidget);
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Settle all async SQLite updates and transitions
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verify SQLite database integrity
        final itemInDb = await db.vaultDao.getItemById(card.id);
        expect(itemInDb, isNotNull);
        expect(itemInDb!.currentMarketPrice, equals(350.00));

        final data = jsonDecode(itemInDb.dynamicData) as Map<String, dynamic>;
        expect(data['finish'], equals('textured'));
        expect(data['treatment'], equals('Textured Foil'));

        // Verify textured chip has checkmark
        final texturedChip = find.byKey(const Key('treatment_chip_textured'));
        expect(
          find.descendant(of: texturedChip, matching: find.byIcon(Icons.check_circle)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Burst-tapping reputation upvote/downvote buttons updates scores consistently with valid mathematical states',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard(reputationScore: 42, userVote: 0);
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        final upvoteBtn = find.byKey(const Key('card_detail_upvote_button'));
        final downvoteBtn = find.byKey(const Key('card_detail_downvote_button'));
        final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

        expect(upvoteBtn, findsOneWidget);
        expect(downvoteBtn, findsOneWidget);
        expect(scoreFinder, findsOneWidget);

        // Initial score: 0
        expect(tester.widget<Text>(scoreFinder).data, equals('0'));

        // Rapid tap sequence:
        // 1. Upvote (0 -> 1, vote=1)
        await tester.tap(upvoteBtn);
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.widget<Text>(scoreFinder).data, equals('1'));

        // 2. Downvote (1 -> -1, vote=-1)
        await tester.tap(downvoteBtn);
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.widget<Text>(scoreFinder).data, equals('-1'));

        // 3. Upvote again (-1 -> 1, vote=1)
        await tester.tap(upvoteBtn);
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.widget<Text>(scoreFinder).data, equals('1'));

        // 4. Upvote again -> toggles off to neutral (1 -> 0, vote=0)
        await tester.tap(upvoteBtn);
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.widget<Text>(scoreFinder).data, equals('0'));

        // 5. Downvote (0 -> -1, vote=-1)
        await tester.tap(downvoteBtn);
        await tester.pump(const Duration(milliseconds: 15));
        expect(tester.widget<Text>(scoreFinder).data, equals('-1'));

        // 6. Downvote again -> toggles off to neutral (-1 -> 0, vote=0)
        await tester.tap(downvoteBtn);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(scoreFinder).data, equals('0'));

        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // Requirement 4: VersionsAndPrintingsModal Upper-Left Back Button & Deduplication
  // ===========================================================================
  group('4. VersionsAndPrintingsModal Upper-Left Back Button & Deduplication', () {
    testWidgets(
      'VersionsAndPrintingsModal upper-left back button dismisses modal cleanly without dismissing CardDetailSheet',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Modal initially unmounted
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // Tap [See More Versions & Printings]
        final seeMoreButton = find.byKey(const Key('card_detail_see_more_versions_button'));
        expect(seeMoreButton, findsOneWidget);
        await tester.tap(seeMoreButton);
        await tester.pumpAndSettle();

        // Modal is mounted
        expect(find.byType(VersionsAndPrintingsModal), findsOneWidget);

        // Back button is rendered in the upper-left
        final backButton = find.byKey(const Key('versions_printings_back_button'));
        expect(backButton, findsOneWidget);

        // Tap the back button
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Modal dismissed cleanly
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // CardDetailSheet is still intact
        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(find.byKey(const Key('card_detail_see_more_versions_button')), findsOneWidget);
      },
    );

    testWidgets(
      'VersionsAndPrintingsModal active printing candidate deduplication & active printing dismissal',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = createTestCard();
        await db.into(db.vaultItems).insert(card);

        // Add 2 distinct variants to the catalog
        final alt1 = createCatalogVariant(
          id: 'ring-showcase-0451',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0451',
          price: 180.00,
          borderColor: 'borderless',
          frameEffects: ['showcase'],
        );
        final alt2 = createCatalogVariant(
          id: 'ring-extended-0705',
          name: 'The One Ring',
          setCode: 'ltr',
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          collectorNumber: '0705',
          price: 210.00,
          frameEffects: ['extendedart'],
        );
        await db.into(db.vaultItems).insert(alt1);
        await db.into(db.vaultItems).insert(alt2);

        await tester.pumpWidget(
          createHarness(
            child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          ),
        );
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.byKey(const Key('card_detail_see_more_versions_button')));
        await tester.pumpAndSettle();

        // Switch to Printings tab
        await tester.tap(find.text('Printings'));
        await tester.pumpAndSettle();

        // Active printing (0269) must appear exactly once
        final activePrinting = find.byKey(const Key('variant_card_ltr_0269'));
        expect(activePrinting, findsOneWidget, reason: 'Active printing must appear exactly once (deduplicated)');

        // Tap the active printing candidate: it should dismiss the modal without pushing duplicate routes
        await tester.tap(activePrinting);
        await tester.pumpAndSettle();

        // Modal is closed
        expect(find.byType(VersionsAndPrintingsModal), findsNothing);

        // Exactly 1 CardDetailSheet exists (no duplicate pushed)
        expect(find.byType(CardDetailSheet), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // Requirement 5: Search Bar Internal 'X' Button Keystroke Debouncing & Clear Responsiveness
  // ===========================================================================
  group('5. Search Bar Internal X Button Keystroke Debouncing & Clear Responsiveness', () {
    testWidgets(
      'Search bar clear button transitions with zero latency on keystroke and synchronously clears query',
      (tester) async {
        final seedService = SocialSeedService(db);
        await db.userProfileDao.seedDefaultProfiles();
        await seedService.seedSocialData();

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-test-active'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: FeedScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand search bar
        final searchToggleBtn = find.byKey(const Key('feed_appbar_search_button'));
        expect(searchToggleBtn, findsOneWidget);
        await tester.tap(searchToggleBtn);
        await tester.pumpAndSettle();

        final searchInput = find.byKey(const Key('home_search_input'));
        expect(searchInput, findsOneWidget);

        // Initial state: close button present, clear button absent
        expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
        expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
        expect(container.read(homeSearchQueryProvider), equals(''));

        // Type 'Black Lotus' keystroke and pump 0ms
        await tester.enterText(searchInput, 'Black Lotus');
        await tester.pump();

        // SuffixIcon must transition to clear button immediately (0ms latency)
        expect(
          find.byKey(const Key('home_search_clear_button')),
          findsOneWidget,
          reason: 'Clear button must appear immediately on typing',
        );
        expect(
          find.byKey(const Key('home_search_close_button')),
          findsNothing,
          reason: 'Close button must be replaced by clear button when non-empty',
        );

        // Provider must still be empty before debounce window (200ms)
        expect(container.read(homeSearchQueryProvider), equals(''));

        // Pump past debounce window
        await tester.pump(const Duration(milliseconds: 250));
        expect(container.read(homeSearchQueryProvider), equals('Black Lotus'));

        // Tap the internal clear button
        await tester.tap(find.byKey(const Key('home_search_clear_button')));
        await tester.pump();

        // Input field is synchronously cleared
        expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
        expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
        expect(container.read(homeSearchQueryProvider), equals(''));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
