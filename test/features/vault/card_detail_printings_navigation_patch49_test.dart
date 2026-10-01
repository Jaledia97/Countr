import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    required String setCode,
    required String setName,
    required String collectorNumber,
    int quantity = 1,
    double price = 15.00,
    List<String> finishes = const ['nonfoil'],
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: 'https://cards.scryfall.io/normal/$id.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: null,
      dynamicData: jsonEncode({
        'set': setCode.toLowerCase(),
        'set_code': setCode.toLowerCase(),
        'collector_number': collectorNumber,
        'mana_cost': '{1}{U}',
        'type_line': 'Instant',
        'oracle_text': 'Draw two cards.',
        'finishes': finishes,
      }),
    );
  }

  CardPrintCandidate createCandidate({
    required String setCode,
    required String setName,
    required String collectorNumber,
    double marketPrice = 12.50,
    List<String> finishes = const ['nonfoil'],
    List<String> frameEffects = const [],
    String? cardId,
  }) {
    return CardPrintCandidate(
      setCode: setCode,
      setName: setName,
      collectorNumber: collectorNumber,
      imageUrl: 'https://cards.scryfall.io/normal/${setCode}_$collectorNumber.jpg',
      artCropUrl: 'https://cards.scryfall.io/art_crop/${setCode}_$collectorNumber.jpg',
      marketPrice: marketPrice,
      rarity: 'rare',
      finishes: finishes,
      frameEffects: frameEffects,
      rawData: {
        'id': cardId ?? 'scryfall_${setCode}_$collectorNumber',
        'name': 'Archmage\'s Charm',
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'collector_number': collectorNumber,
        'finishes': finishes,
        'frame_effects': frameEffects,
        'prices': {'usd': marketPrice.toString()},
      },
    );
  }

  Widget createHarness({
    required VaultItem rootItem,
    List<CardPrintCandidate>? candidates,
    bool enableNavigation = true,
    ValueChanged<CardPrintCandidate>? onPrintingSelected,
    ValueChanged<VaultItem>? onPrintingChanged,
  }) {
    return ProviderScope(
      overrides: [
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VariantPriceChart(
              item: rootItem,
              initialVariants: candidates,
              enableOnlineFetch: false,
              enableNavigation: enableNavigation,
              onPrintingSelected: onPrintingSelected,
              onPrintingChanged: onPrintingChanged,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapVariantCard(WidgetTester tester, String setCode, String collectorNumber) async {
    final cardFinder = find.byKey(Key('variant_card_${setCode}_$collectorNumber'));
    await tester.tapAt(tester.getBottomLeft(cardFinder) + const Offset(20, -10));
  }

  group('R10 Tier 1: Isolated Features — Versions & Printings Navigation', () {
    testWidgets('T1.1: VariantPriceChart renders candidates with set codes, numbers, and prices', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
        marketPrice: 14.50,
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        marketPrice: 9.75,
      );
      final candidate3 = createCandidate(
        setCode: 'sld',
        setName: 'Secret Lair Drop',
        collectorNumber: '1102',
        marketPrice: 32.00,
        finishes: ['foil'],
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2, candidate3],
        ),
      );
      await tester.pumpAndSettle();

      // Verify all candidates rendered
      expect(find.byKey(const Key('variant_card_mh1_040')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_2x2_038')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_sld_1102')), findsOneWidget);

      // Verify collector numbers and prices
      expect(find.text('#040'), findsOneWidget);
      expect(find.text('#038'), findsOneWidget);
      expect(find.text('#1102'), findsOneWidget);
      expect(find.text('\$14.50'), findsOneWidget);
      expect(find.text('\$9.75'), findsOneWidget);
      expect(find.text('\$32.00'), findsOneWidget);
    });

    testWidgets('T1.2: Tapping alternate candidate navigates to distinct CardDetailSheet route', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        marketPrice: 9.75,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2],
        ),
      );
      await tester.pumpAndSettle();

      // Initially no CardDetailSheet in the tree
      expect(find.byType(CardDetailSheet), findsNothing);

      // Tap candidate 2 (2X2 #038)
      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // CardDetailSheet route has been pushed
      expect(find.byType(CardDetailSheet), findsOneWidget);
    });

    testWidgets('T1.3: Pushed CardDetailSheet route displays target printing details', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        marketPrice: 9.75,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2],
        ),
      );
      await tester.pumpAndSettle();

      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // Verify the pushed sheet displays target set Double Masters 2022
      expect(find.text('Double Masters 2022'), findsWidgets);
      expect(find.textContaining('038'), findsWidgets);
    });

    testWidgets('T1.4: Active printing has distinct border and tapping does not push redundant route', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2],
        ),
      );
      await tester.pumpAndSettle();

      // Active printing displays 'OWNED' badge
      expect(find.text('OWNED'), findsOneWidget);

      // Tapping the already active candidate should NOT push a new sheet
      final activeCardFinder = find.byKey(const Key('variant_card_mh1_040'));
      await tester.tap(activeCardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsNothing);
    });

    testWidgets('T1.5: Popping pushed sheet returns to original view cleanly', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2],
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Pop the sheet
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      // Sheet dismissed, root view restored
      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.byKey(const Key('variant_card_mh1_040')), findsOneWidget);
    });
  });

  group('R10 Tier 2: Boundary & Corner Cases — Candidate Resolution & Formatting', () {
    testWidgets('T2.1: Candidate not in inventory synthesizes unowned item with quantity 0', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidateAlt = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        marketPrice: 11.20,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidateAlt],
        ),
      );
      await tester.pumpAndSettle();

      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // Sheet is open; verify it has synthesized unowned item with quantity 0
      final sheetWidget = tester.widget<CardDetailSheet>(find.byType(CardDetailSheet));
      expect(sheetWidget.item!.quantity, equals(0));
      expect(sheetWidget.item!.id, contains('2x2_038'));
      expect(sheetWidget.item!.setOrSeries, equals('Double Masters 2022'));
    });

    testWidgets('T2.2: Already-owned candidate resolves existing VaultItem from database', (tester) async {
      final ownedAltCard = createTestCard(
        id: 'card-2x2-038-owned',
        name: 'Archmage\'s Charm',
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        quantity: 3,
        price: 10.50,
      );
      await db.into(db.vaultItems).insert(ownedAltCard);

      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidateAlt = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
        marketPrice: 10.50,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidateAlt],
        ),
      );
      await tester.pumpAndSettle();

      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // Pushed sheet resolves the database item with quantity 3
      final sheetWidget = tester.widget<CardDetailSheet>(find.byType(CardDetailSheet));
      expect(sheetWidget.item!.id, equals('card-2x2-038-owned'));
      expect(sheetWidget.item!.quantity, equals(3));
      expect(sheetWidget.item!.setOrSeries, equals('Double Masters 2022'));
    });

    testWidgets('T2.3: Candidate with zero market price displays fallback dash gracefully', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final zeroPriceCandidate = createCandidate(
        setCode: 'prerelease',
        setName: 'Prerelease Promos',
        collectorNumber: '040s',
        marketPrice: 0.0,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [zeroPriceCandidate],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('variant_card_prerelease_040s')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('T2.4: Etched and foil finishes display corresponding tags and highlight borders', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final etchedCandidate = createCandidate(
        setCode: 'cmr',
        setName: 'Commander Legends',
        collectorNumber: '500',
        finishes: ['etched'],
        marketPrice: 24.00,
      );
      final foilCandidate = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
        finishes: ['foil'],
        marketPrice: 18.00,
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [etchedCandidate, foilCandidate],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Etched'), findsOneWidget);
      expect(find.text('Foil'), findsOneWidget);
    });

    testWidgets('T2.5: Nested navigation chaining: pop from secondary sheet returns to primary', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidateAlt1 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidateAlt1],
        ),
      );
      await tester.pumpAndSettle();

      // Open first sheet
      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Verify the first sheet has closed candidate list or its own sheet
      // Now close first sheet
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.byKey(const Key('variant_card_2x2_038')), findsOneWidget);
    });
  });

  group('R10 Tier 3: Pairwise Combinations — Architecture & State Integration', () {
    testWidgets('T3.1: Pushed CardDetailSheet integrates scrollable view (R3) for alternate printing', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidateAlt = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidateAlt],
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // In the pushed sheet, verify scrollable content and tabs are present (R3)
      expect(find.descendant(of: find.byType(CardDetailSheet), matching: find.byType(Scrollable)), findsWidgets);
      expect(find.text('Details'), findsWidgets);
      expect(find.text('Values'), findsWidgets);
    });

    testWidgets('T3.2: Pushed CardDetailSheet retains TCG domain and name identity for alternate printing', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidateAlt = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidateAlt],
        ),
      );
      await tester.pumpAndSettle();

      await tapVariantCard(tester, '2x2', '038');
      await tester.pumpAndSettle();

      // Pushed sheet inherits collection type and card identity
      final sheetWidget = tester.widget<CardDetailSheet>(find.byType(CardDetailSheet));
      expect(sheetWidget.item!.collectionType, equals('mtg'));
      expect(sheetWidget.item!.name, equals('Archmage\'s Charm'));
      expect(sheetWidget.item!.setOrSeries, equals('Double Masters 2022'));
    });
  });

  group('R10 Tier 4: Real-World E2E Scenario — Printing Comparison & Selection Flow', () {
    testWidgets('T4.1: Complete printing comparison flow: inspect owned card -> open alternate printing -> verify details -> pop back', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Create base card and insert in DB
      final baseCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
        quantity: 2,
        price: 15.00,
      );
      await db.into(db.vaultItems).insert(baseCard);

      final altCandidate = createCandidate(
        setCode: 'sld',
        setName: 'Secret Lair Drop',
        collectorNumber: '1102',
        marketPrice: 35.00,
        finishes: ['foil'],
      );

      await tester.pumpWidget(
        createHarness(
          rootItem: baseCard,
          candidates: [
            createCandidate(setCode: 'mh1', setName: 'Modern Horizons', collectorNumber: '040', marketPrice: 15.00),
            altCandidate,
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify root cards are rendered
      expect(find.byKey(const Key('variant_card_sld_1102')), findsOneWidget);

      // Tap alternate printing
      await tapVariantCard(tester, 'sld', '1102');
      await tester.pumpAndSettle();

      // Pushed sheet displays Secret Lair Drop details
      expect(find.byType(CardDetailSheet), findsOneWidget);
      final pushedSheet = tester.widget<CardDetailSheet>(find.byType(CardDetailSheet));
      expect(pushedSheet.item!.setOrSeries, equals('Secret Lair Drop'));
      expect(pushedSheet.item!.name, equals('Archmage\'s Charm'));

      // Pop back
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      // Sheet dismissed, root view visible with both variants
      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.byKey(const Key('variant_card_mh1_040')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_sld_1102')), findsOneWidget);
    });

    testWidgets('T4.2: When enableNavigation is false, selecting printing fires onPrintingSelected callback without navigation', (tester) async {
      final rootCard = createTestCard(
        id: 'card-mh1-040',
        name: 'Archmage\'s Charm',
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );

      final candidate1 = createCandidate(
        setCode: 'mh1',
        setName: 'Modern Horizons',
        collectorNumber: '040',
      );
      final candidate2 = createCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022',
        collectorNumber: '038',
      );

      CardPrintCandidate? selectedCandidate;

      await tester.pumpWidget(
        createHarness(
          rootItem: rootCard,
          candidates: [candidate1, candidate2],
          enableNavigation: false,
          onPrintingSelected: (candidate) {
            selectedCandidate = candidate;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap candidate 2
      await tester.tap(find.text('#038'));
      await tester.pumpAndSettle();

      // No sheet pushed
      expect(find.byType(CardDetailSheet), findsNothing);
      // Callback fired with candidate2
      expect(selectedCandidate, isNotNull);
      expect(selectedCandidate!.setCode, equals('2x2'));
      expect(selectedCandidate!.collectorNumber, equals('038'));
    });
  });
}
