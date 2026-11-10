// Copyright (c) 2026 Countr. All rights reserved.
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/expanded_card_view_modal.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    required String id,
    required String name,
    required String setOrSeries,
    double price = 50.0,
    String rarity = 'Mythic Rare',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2025, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'oracle_text': 'Card rules for $name',
        'type_line': 'Legendary Creature',
        'mana_cost': '{2}{U}{U}',
        'rarity': rarity,
      }),
    );
  }

  Future<void> seedCard(VaultItem item) async {
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: item.id,
            collectionType: item.collectionType,
            name: item.name,
            setOrSeries: item.setOrSeries,
            imageUrl: item.imageUrl,
            acquiredPrice: item.acquiredPrice,
            acquiredDate: item.acquiredDate,
            quantity: drift.Value(item.quantity),
            condition: item.condition,
            isGraded: drift.Value(item.isGraded),
            isAltered: drift.Value(item.isAltered),
            isMisprint: drift.Value(item.isMisprint),
            isSigned: drift.Value(item.isSigned),
            isDeleted: drift.Value(item.isDeleted),
            currentMarketPrice: item.currentMarketPrice,
            lastPriceUpdate: item.lastPriceUpdate,
            dynamicData: item.dynamicData,
          ),
        );
  }

  Widget buildApp(Widget child, {List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: Scaffold(
          body: child is ExpandedCardViewModal
              ? child
              : SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  // =========================================================================
  // GROUP 1: Single Card Invariants & Artwork Aspect Ratio
  // =========================================================================
  group('1. ExpandedCardViewModal Single-Card Invariants & Aspect Ratio', () {
    testWidgets('1.1: Lightbox renders container, high-res art with exact 63/88 aspect ratio', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-black-lotus',
                  cardTitle: 'Black Lotus',
                  cardSubtitle: 'Limited Edition Alpha',
                  cardRarity: 'Rare',
                  estimatedValue: '\$100,000.00',
                );
              },
              child: const Text('Open Single Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Single Lightbox'));
      await tester.pumpAndSettle();

      // Lightbox container check
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.byKey(const Key('expanded_card_high_res_art')), findsOneWidget);

      // Verify exact 63 / 88 aspect ratio on AspectRatio widget wrapping card art
      final aspectRatios = tester.widgetList<AspectRatio>(
        find.ancestor(
          of: find.byKey(const Key('expanded_card_high_res_art')),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(aspectRatios.isNotEmpty, isTrue);
      expect(aspectRatios.first.aspectRatio, closeTo(63 / 88, 0.001));

      // Close button check
      expect(find.byKey(const Key('expanded_card_close_button')), findsOneWidget);

      // See Details button check
      expect(find.byKey(const Key('expanded_card_see_details_button')), findsOneWidget);
    });

    testWidgets('1.2: Renders title, subtitle, formatted value; hides page counter and dots on single card', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-sol-ring',
                  cardTitle: 'Sol Ring',
                  cardSubtitle: 'Commander Masters',
                  estimatedValue: '\$12.50',
                );
              },
              child: const Text('Open Sol Ring Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sol Ring Lightbox'));
      await tester.pumpAndSettle();

      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Commander Masters'), findsOneWidget);
      expect(find.text('\$12.50'), findsOneWidget);

      // Single card should NOT display a page counter '1 / 1'
      expect(find.text('1 / 1'), findsNothing);

      // Single card should not render dot indicator row with AnimatedContainer
      final animatedContainers = find.descendant(
        of: find.byType(Row),
        matching: find.byType(AnimatedContainer),
      );
      expect(animatedContainers, findsNothing);
    });

    testWidgets('1.3: Dismissal boundary: tap on art does NOT dismiss, tap top backdrop dismisses', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-mox-ruby',
                  cardTitle: 'Mox Ruby',
                );
              },
              child: const Text('Open Mox Ruby'),
            ),
          ),
        ),
      );

      // --- Part A: Tap on card art does NOT dismiss ---
      await tester.tap(find.text('Open Mox Ruby'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

      // Tap card art
      await tester.tap(find.byKey(const Key('expanded_card_high_res_art')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

      // --- Part B: Tap top backdrop dismisses ---
      // Tap in the true top-left backdrop margin outside PageView (x: 10, y: 10)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });

    testWidgets('1.4: Tapping [See Details] routes to CardDetailSheet with card data', (tester) async {
      final card = createTestCard(
        id: 'card-sheoldred',
        name: 'Sheoldred, the Apocalypse',
        setOrSeries: 'Dominaria United',
        price: 85.00,
      );
      await seedCard(card);

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  item: card,
                );
              },
              child: const Text('Open Sheoldred Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheoldred Lightbox'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

      // Tap [See Details]
      await tester.tap(find.byKey(const Key('expanded_card_see_details_button')));
      await tester.pumpAndSettle();

      // Lightbox popped, CardDetailSheet is now visible
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
      expect(find.byKey(const Key('card_detail_close_button')), findsOneWidget);
      expect(find.text('Sheoldred, the Apocalypse'), findsWidgets);
    });

    testWidgets('1.5: Custom onSeeDetails callback override is invoked and prevents default sheet', (tester) async {
      bool customCallbackInvoked = false;

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-override',
                  cardTitle: 'Custom Action Card',
                  onSeeDetails: () {
                    customCallbackInvoked = true;
                  },
                );
              },
              child: const Text('Open Override Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Override Lightbox'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expanded_card_see_details_button')));
      await tester.pumpAndSettle();

      expect(customCallbackInvoked, isTrue);
      // CardDetailSheet should NOT be opened since callback intercepted
      expect(find.byKey(const Key('card_detail_close_button')), findsNothing);
    });

    testWidgets('1.6: Remediation verified: expanded_card_close_button is positioned at top and dismisses modal cleanly', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-close-test',
                  cardTitle: 'Close Button Test',
                );
              },
              child: const Text('Open Close Test Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Close Test Lightbox'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

      final closeBtnFinder = find.byKey(const Key('expanded_card_close_button'));
      expect(closeBtnFinder, findsOneWidget);

      // Verify close button position: Must be at top of screen (y <= 60), NOT vertically centered
      final center = tester.getCenter(closeBtnFinder);
      expect(center.dy, lessThan(60.0), reason: 'Close button must be positioned at top of screen');

      // Verify hit test: the close button receives pointer events cleanly (hits IconButton)
      final hitResult = tester.hitTestOnBinding(center);
      final hitButton = hitResult.path.any((entry) =>
          entry.target.runtimeType.toString().contains('RenderInputPadding') ||
          entry.target.runtimeType.toString().contains('InkFeatures'));
      expect(hitButton, isTrue, reason: 'Hit test at close button center must hit button ink features');

      final hitPageView = hitResult.path.any((entry) =>
          entry.target.runtimeType.toString().contains('ScrollSemantics') ||
          entry.target.runtimeType.toString().contains('Scrollable'));
      expect(hitPageView, isFalse, reason: 'Hit test at close button center must NOT hit PageView');

      // Tapping close button dismisses modal cleanly
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing, reason: 'Modal must be dismissed after tapping close button');
    });

    testWidgets('1.7: DEFECT PROOF: Tapping backdrop in lateral margins inside PageView bounds does not dismiss modal', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardId: 'card-lateral-test',
                  cardTitle: 'Lateral Test',
                );
              },
              child: const Text('Open Lateral Test Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Lateral Test Lightbox'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);

      // Tap in the lateral margin to the left of the card art (x: 20, y: 250)
      await tester.tapAt(const Offset(20, 250));
      await tester.pumpAndSettle();

      // Modal FAILS to dismiss because PageView's RawGestureDetector is opaque and shadows the background GestureDetector
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget, reason: 'Modal remained open because lateral margin tap hit PageView viewport instead of background dismiss gesture detector');
    });
  });

  // =========================================================================
  // GROUP 2: Multi-Card Swiping, Dot Indicators & Page Counter Sync
  // =========================================================================
  group('2. ExpandedCardViewModal Multi-Card Swiping & Dot Sync', () {
    testWidgets('2.1: Multi-card post initializes at 0 with counter "1 / 3" and 3 dots (dot 0 active)', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['card-1', 'card-2', 'card-3'],
                  cardTitles: ['Urza, High Artificer', 'Isochron Scepter', 'Dramatic Reversal'],
                  cardSubtitles: ['Modern Horizons', 'Mirrodin', 'Kaladesh'],
                  estimatedValues: ['\$45.00', '\$15.00', '\$3.50'],
                );
              },
              child: const Text('Open Multi Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Multi Lightbox'));
      await tester.pumpAndSettle();

      // Page counter shows '1 / 3'
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Urza, High Artificer'), findsOneWidget);

      // Verify 3 dot indicators
      final dotContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(AnimatedContainer),
        ),
      ).toList();

      expect(dotContainers.length, equals(3));
      // First dot active: width 16
      expect(dotContainers[0].constraints?.maxWidth ?? 0, equals(16));
      // Other dots inactive: width 6
      expect(dotContainers[1].constraints?.maxWidth ?? 0, equals(6));
      expect(dotContainers[2].constraints?.maxWidth ?? 0, equals(6));
    });

    testWidgets('2.2: Swipe gesture from index 0 -> 1 updates counter to "2 / 3" and activates dot 1', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['card-1', 'card-2', 'card-3'],
                  cardTitles: ['Urza, High Artificer', 'Isochron Scepter', 'Dramatic Reversal'],
                  cardSubtitles: ['Modern Horizons', 'Mirrodin', 'Kaladesh'],
                );
              },
              child: const Text('Open Swipe Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Swipe Lightbox'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);

      final textsBefore = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      debugPrint('Texts before drag: $textsBefore');

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      final textsAfter = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      debugPrint('Texts after drag: $textsAfter');
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Isochron Scepter'), findsOneWidget);

      // Dot 1 should now be active (width 16), dot 0 inactive (width 6)
      final dotContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(AnimatedContainer),
        ),
      ).toList();

      expect(dotContainers[0].constraints?.maxWidth ?? 0, equals(6));
      expect(dotContainers[1].constraints?.maxWidth ?? 0, equals(16));
      expect(dotContainers[2].constraints?.maxWidth ?? 0, equals(6));
    });

    testWidgets('2.3: Second swipe to index 2 updates counter to "3 / 3"; reverse swipe restores index 1', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['card-1', 'card-2', 'card-3'],
                  cardTitles: ['Card One', 'Card Two', 'Card Three'],
                );
              },
              child: const Text('Open 3 Cards Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open 3 Cards Lightbox'));
      await tester.pumpAndSettle();

      // Swipe 0 -> 1
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      // Swipe 1 -> 2
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Card Three'), findsOneWidget);

      // Reverse swipe 2 -> 1
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Card Two'), findsOneWidget);
    });

    testWidgets('2.4: Active swiped card tracking: [See Details] opens CardDetailSheet for index 1 card', (tester) async {
      final card1 = createTestCard(id: 'c1-ragavan', name: 'Ragavan, Nimble Pilferer', setOrSeries: 'MH2', price: 60);
      final card2 = createTestCard(id: 'c2-dockside', name: 'Dockside Extortionist', setOrSeries: 'C19', price: 80);
      final card3 = createTestCard(id: 'c3-bowmasters', name: 'Orcish Bowmasters', setOrSeries: 'LTR', price: 40);
      await seedCard(card1);
      await seedCard(card2);
      await seedCard(card3);

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  items: [card1, card2, card3],
                );
              },
              child: const Text('Open Swiped Details Lightbox'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Swiped Details Lightbox'));
      await tester.pumpAndSettle();

      // Swipe to card 2 (index 1: Dockside)
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Dockside Extortionist'), findsWidgets);

      // Tap [See Details]
      await tester.tap(find.byKey(const Key('expanded_card_see_details_button')));
      await tester.pumpAndSettle();

      // CardDetailSheet should display Dockside Extortionist, NOT Ragavan
      expect(find.byKey(const Key('card_detail_close_button')), findsOneWidget);
      expect(find.text('Dockside Extortionist'), findsWidgets);
    });
  });

  // =========================================================================
  // GROUP 3: Boundary Conditions, Index Clamping & Resilience
  // =========================================================================
  group('3. Boundary Conditions & Index Clamping Resilience', () {
    testWidgets('3.1: Negative initialIndex clamps safely to 0 without crashing', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['c1', 'c2'],
                  cardTitles: ['Card 1', 'Card 2'],
                  initialIndex: -5,
                );
              },
              child: const Text('Open Negative Index'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Negative Index'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Card 1'), findsOneWidget);
    });

    testWidgets('3.2: Excessively high initialIndex clamps to safe bounds without RangeError', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['c1', 'c2', 'c3'],
                  cardTitles: ['Card 1', 'Card 2', 'Card 3'],
                  initialIndex: 999,
                );
              },
              child: const Text('Open Overflow Index'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Overflow Index'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      // Safe fallback clamps to index 0 or length - 1
      expect(find.byKey(const Key('expanded_card_high_res_art')), findsOneWidget);
    });

    testWidgets('3.3: Direct constructor with out-of-bound initialIndex clamps in initState', (tester) async {
      await tester.pumpWidget(
        buildApp(
          ExpandedCardViewModal(
            cards: const [
              ExpandedCardItem(cardId: 'c1', cardTitle: 'Card 1'),
              ExpandedCardItem(cardId: 'c2', cardTitle: 'Card 2'),
            ],
            initialIndex: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
    });

    testWidgets('3.4: Mismatched list lengths in ExpandedCardViewModal.show resolve without throwing', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['c1', 'c2', 'c3'],
                  imageUrls: ['https://example.com/c1.jpg'], // length 1
                  cardTitles: ['Card 1'], // length 1
                  cardSubtitles: null,
                  cardRarities: null,
                  estimatedValues: null,
                );
              },
              child: const Text('Open Mismatched Lists'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Mismatched Lists'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      // Swiping to card 2 and 3 should not throw RangeError
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('3.5: Rapid flings and overscroll do not crash or throw exceptions', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ExpandedCardViewModal.show(
                  context,
                  cardIds: ['c1', 'c2'],
                  cardTitles: ['Card 1', 'Card 2'],
                );
              },
              child: const Text('Open Rapid Fling'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rapid Fling'));
      await tester.pumpAndSettle();

      // Rapidly fling back and forth
      await tester.fling(find.byType(PageView), const Offset(-800, 0), 2000);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.fling(find.byType(PageView), const Offset(800, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: Feed Card Tap Routing & Component Isolation
  // =========================================================================
  group('4. Feed Card Tap Routing & Component Isolation', () {
    testWidgets('4.1: SinglePullPostBody card tap with useLightbox: true opens ExpandedCardViewModal', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const SinglePullPostBody(
            cardId: 'feed-card-lotus',
            cardTitle: 'Black Lotus Specimen',
            cardSubtitle: 'Alpha 1993',
            estimatedValue: '\$99,999.00',
            useLightbox: true,
          ),
        ),
      );

      // Tap card in SinglePullPostBody
      await tester.tap(find.byKey(const Key('single_pull_card_feed-card-lotus')));
      await tester.pumpAndSettle();

      // Lightbox opened!
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('Black Lotus Specimen'), findsWidgets);
      expect(find.byKey(const Key('expanded_card_see_details_button')), findsOneWidget);
    });

    testWidgets('4.2: SinglePullPostBody with useLightbox: false opens CardDetailSheet directly', (tester) async {
      final card = createTestCard(id: 'feed-card-direct', name: 'Direct Sheet Card', setOrSeries: 'Set');
      await seedCard(card);

      await tester.pumpWidget(
        buildApp(
          const SinglePullPostBody(
            cardId: 'feed-card-direct',
            cardTitle: 'Direct Sheet Card',
            useLightbox: false,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('single_pull_card_feed-card-direct')));
      await tester.pumpAndSettle();

      // CardDetailSheet opened directly without lightbox
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
      expect(find.byKey(const Key('card_detail_close_button')), findsOneWidget);
    });

    testWidgets('4.3: SinglePullPostBody component isolation: custom onCardTap executes and skips lightbox', (tester) async {
      bool customTapInvoked = false;

      await tester.pumpWidget(
        buildApp(
          SinglePullPostBody(
            cardId: 'isolated-card',
            cardTitle: 'Isolated Card',
            useLightbox: true,
            onCardTap: () {
              customTapInvoked = true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('single_pull_card_isolated-card')));
      await tester.pumpAndSettle();

      expect(customTapInvoked, isTrue);
      // Lightbox should NOT be opened
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });

    testWidgets('4.4: MultiPullPostBody 3-card combo: tapping card at index 1 opens lightbox at index 1', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const MultiPullPostBody(
            pullItems: ['Urza Artificer', 'Isochron Scepter', 'Dramatic Reversal'],
            pullCardIds: ['c-urza', 'c-isochron', 'c-dramatic'],
            useLightbox: true,
          ),
        ),
      );

      // Tap second card (index 1: c-isochron)
      await tester.tap(find.byKey(const Key('multi_pull_card_1_c-isochron')));
      await tester.pumpAndSettle();

      // Lightbox opened at page index 1
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Isochron Scepter'), findsWidgets);
    });

    testWidgets('4.5: MultiPullPostBody 3-card combo: tapping card at index 2 opens lightbox at index 2', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const MultiPullPostBody(
            pullItems: ['Urza Artificer', 'Isochron Scepter', 'Dramatic Reversal'],
            pullCardIds: ['c-urza', 'c-isochron', 'c-dramatic'],
            useLightbox: true,
          ),
        ),
      );

      // Tap third card (index 2: c-dramatic)
      await tester.tap(find.byKey(const Key('multi_pull_card_2_c-dramatic')));
      await tester.pumpAndSettle();

      // Lightbox opened at page index 2
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Dramatic Reversal'), findsWidgets);
    });

    testWidgets('4.6: MultiPullPostBody component isolation: custom onCardTap executes with tapped index', (tester) async {
      int? tappedIndex;
      String? tappedCardId;

      await tester.pumpWidget(
        buildApp(
          MultiPullPostBody(
            pullItems: const ['Card A', 'Card B', 'Card C'],
            pullCardIds: const ['ca', 'cb', 'cc'],
            useLightbox: true,
            onCardTap: (index, cardId) {
              tappedIndex = index;
              tappedCardId = cardId;
            },
          ),
        ),
      );

      // Tap card at index 1
      await tester.tap(find.byKey(const Key('multi_pull_card_1_cb')));
      await tester.pumpAndSettle();

      expect(tappedIndex, equals(1));
      expect(tappedCardId, equals('cb'));
      // Lightbox should NOT be opened
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });

    testWidgets('4.7: MultiPullPostBody 2x2 grid: tapping card 0 opens lightbox at index 0, card 2 at index 2', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const MultiPullPostBody(
            pullItems: ['Grid 1', 'Grid 2', 'Grid 3', 'Grid 4'],
            pullCardIds: ['g1', 'g2', 'g3', 'g4'],
            useLightbox: true,
          ),
        ),
      );

      // Tap card 2
      await tester.tap(find.byKey(const Key('multi_pull_card_2_g3')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('3 / 4'), findsOneWidget);

      // Dismiss lightbox
      Navigator.of(tester.element(find.byKey(const Key('expanded_card_view_lightbox')))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);

      // Tap card 0
      await tester.tap(find.byKey(const Key('multi_pull_card_0_g1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
    });

    testWidgets('4.8: MultiPullPostBody 2x2 grid: 4th card with onSeeMoreTap invokes callback', (tester) async {
      bool seeMoreInvoked = false;

      await tester.pumpWidget(
        buildApp(
          MultiPullPostBody(
            pullItems: const ['Grid 1', 'Grid 2', 'Grid 3', 'Grid 4'],
            pullCardIds: const ['g1', 'g2', 'g3', 'g4'],
            useLightbox: true,
            onSeeMoreTap: () {
              seeMoreInvoked = true;
            },
          ),
        ),
      );

      // Tap 4th card
      await tester.tap(find.byKey(const Key('multi_pull_card_3_g4')));
      await tester.pumpAndSettle();

      expect(seeMoreInvoked, isTrue);
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });

    testWidgets('4.9: PostCard singlePull integration routes card tap to lightbox', (tester) async {
      final post = FeedPost(
        id: 'post-sp-1',
        type: PostType.singlePull,
        username: 'CollectorAlpha',
        avatarInitials: 'CA',
        timestamp: '1h',
        locationTag: 'Austin, TX',
        textContent: 'Check out my pull!',
        cardTitle: 'Sol Ring Masterpiece',
        cardSubtitle: 'Kaladesh Inventions',
        cardId: 'sol-ring-mps',
      );

      await tester.pumpWidget(
        buildApp(
          PostCard(post: post),
        ),
      );

      final cardFinder = find.byKey(const Key('single_pull_card_sol-ring-mps'));
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('Sol Ring Masterpiece'), findsWidgets);
    });

    testWidgets('4.10: PostCard multiPull integration routes card tap to lightbox at tapped index', (tester) async {
      final post = FeedPost(
        id: 'post-mp-1',
        type: PostType.multiPull,
        username: 'CollectorBeta',
        avatarInitials: 'CB',
        timestamp: '2h',
        locationTag: 'Austin, TX',
        textContent: 'Tri-card hit!',
        pullImages: const ['Mox Diamond', 'Lion\'s Eye Diamond', 'Lotus Petal'],
        pullCardIds: const ['mox-diamond-id', 'led-id', 'petal-id'],
      );

      await tester.pumpWidget(
        buildApp(
          PostCard(post: post),
        ),
      );

      // Tap middle card (LED, index 1)
      final cardFinder = find.byKey(const Key('multi_pull_card_1_led-id'));
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Lion\'s Eye Diamond'), findsWidgets);
    });

    testWidgets('4.11: PostCard mixedMedia integration routes card tap to lightbox', (tester) async {
      final post = FeedPost(
        id: 'post-mm-1',
        type: PostType.mixedMedia,
        username: 'MixedMediaUser',
        avatarInitials: 'MM',
        timestamp: '5m',
        locationTag: 'Austin, TX',
        textContent: 'Mixed media pull!',
        pullImages: const ['Card A', 'Card B', 'Card C'],
        pullCardIds: const ['mm-a', 'mm-b', 'mm-c'],
      );

      await tester.pumpWidget(
        buildApp(
          PostCard(post: post),
        ),
      );

      final cardFinder = find.byKey(const Key('multi_pull_card_0_mm-a'));
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('4.12: PostCard component isolation: onCardTap callback preserves custom routing', (tester) async {
      int? tappedIndex;
      String? tappedCardId;

      final post = FeedPost(
        id: 'post-isolated-1',
        type: PostType.singlePull,
        username: 'IsolatedUser',
        avatarInitials: 'IU',
        timestamp: '10m',
        locationTag: 'Austin, TX',
        cardTitle: 'Isolated Post Card',
        cardId: 'iso-card-id',
      );

      await tester.pumpWidget(
        buildApp(
          PostCard(
            post: post,
            onCardTap: (index, cardId) {
              tappedIndex = index;
              tappedCardId = cardId;
            },
          ),
        ),
      );

      final finder = find.byKey(const Key('single_pull_card_iso-card-id'));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();

      expect(tappedIndex, equals(0));
      expect(tappedCardId, equals('iso-card-id'));
      expect(find.byKey(const Key('expanded_card_view_lightbox')), findsNothing);
    });
  });
}
