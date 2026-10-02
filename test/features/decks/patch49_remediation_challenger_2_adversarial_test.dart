import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> cleanWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  // =========================================================================
  // Group 1: Requirement R4 — Decks Screen TCG Filter Lifecycle & Unknown Domain Resilience
  // =========================================================================
  group('R4 Adversarial: Decks Screen TCG Filter Lifecycle & Unknown Domain Resilience', () {
    final pathologicalDomainInputs = [
      'yugioh',
      'onepiece',
      'digimon',
      'custom_domain_99',
      '???',
      '!@#\$%^&*()',
      '',
      '   ',
      ' mtg ',
      'POKEMON',
      'lorcana_fan_made',
      '🃏🎴',
      'null',
      'undefined',
    ];

    for (final domain in pathologicalDomainInputs) {
      testWidgets('1.1: Fuzz test unknown domain "$domain" gracefully renders empty state without throwing', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeDeckTcgFilterProvider.overrideWith((ref) => domain),
              vaultDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(
              home: DecksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Dropdown title handles unknown domain without throwing
        expect(tester.takeException(), isNull);

        // 2. Empty state must be displayed
        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);
        expect(find.byKey(const Key('decks_empty_wizard_button')), findsOneWidget);

        // 3. Floating action button is still present
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        await cleanWidgetTree(tester);
      });
    }

    testWidgets('1.2: Empty wizard button on unknown domain opens DeckSetupWizardModal with safe MTG fallback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeDeckTcgFilterProvider.overrideWith((ref) => 'fuzzed_yugioh_domain'),
            vaultDaoProvider.overrideWithValue(dao),
          ],
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No decks found'), findsOneWidget);

      // Tap the empty state wizard button
      final emptyButton = find.byKey(const Key('decks_empty_wizard_button'));
      expect(emptyButton, findsOneWidget);
      await tester.tap(emptyButton);
      await tester.pumpAndSettle();

      // Modal wizard should open safely without throwing
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      expect(find.text('Commander'), findsOneWidget); // Falls back safely to Commander format
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_format_dropdown')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DeckSetupWizardModal), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      await cleanWidgetTree(tester);
    });

    testWidgets('1.3: Rapid switching between valid, invalid, and "all" domain filters across 30 cycles', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const SizedBox.shrink();
                  },
                ),
                const Expanded(child: DecksScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sequence = [
        'all', 'pokemon', 'yugioh', 'lorcana', 'invalid1',
        'mtg', 'all', 'onepiece', 'pokemon', 'lorcana',
        '', 'all', 'mtg', 'fuzz', 'starwars',
        'pokemon', 'yugioh', 'all', 'mtg', 'lorcana',
      ];

      for (int i = 0; i < sequence.length; i++) {
        final domain = sequence[i];
        capturedRef.read(activeDeckTcgFilterProvider.notifier).state = domain;
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Verify no exceptions were thrown during rapid churn
      expect(tester.takeException(), isNull);
      expect(find.byType(DecksScreen), findsOneWidget);

      await cleanWidgetTree(tester);
    });

    testWidgets('1.4: Subheader tab filtering (All / Competitive / Draft) survives unknown domain state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeDeckTcgFilterProvider.overrideWith((ref) => 'unknown_domain_xyz'),
            vaultDaoProvider.overrideWithValue(dao),
          ],
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially All Decks (0)
      expect(find.text('No decks found'), findsOneWidget);

      // Tap Competitive tab
      await tester.tap(find.byKey(const Key('decks_tab_competitive')));
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Draft tab
      await tester.tap(find.byKey(const Key('decks_tab_draft')));
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap All Decks tab
      await tester.tap(find.byKey(const Key('decks_tab_all')));
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await cleanWidgetTree(tester);
    });
  });

  // =========================================================================
  // Group 2: Requirement R4 — DeckThumbnailPickerModal Cover Selection Under Network Image Failure & Rapid Tapping
  // =========================================================================
  group('R4 Adversarial: DeckThumbnailPickerModal Network Image Failure & Rapid Tapping', () {
    final now = DateTime.now();
    final mockDeck = Deck(
      id: 'adversarial-deck-1',
      name: 'Adversarial Test Deck',
      format: 'Commander',
      tcgDomain: 'mtg',
      isRegistered: false,
      isAssembled: false,
      isCompetitive: false,
      wins: 0,
      losses: 0,
      draws: 0,
      isDeleted: false,
      createdAt: now,
    );

    Future<void> setupDeckInDb() async {
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const drift.Value('adversarial-deck-1'),
          name: const drift.Value('Adversarial Test Deck'),
          format: const drift.Value('Commander'),
          tcgDomain: const drift.Value('mtg'),
          isRegistered: const drift.Value(false),
          isAssembled: const drift.Value(false),
          isCompetitive: const drift.Value(false),
          isDeleted: const drift.Value(false),
          createdAt: drift.Value(now),
        ),
      );

      // Insert member cards
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const drift.Value('card-failing-img'),
          collectionType: const drift.Value('mtg'),
          name: const drift.Value('Damaged Circuit Card'),
          setOrSeries: const drift.Value('BRO'),
          imageUrl: const drift.Value('https://invalid-host-404.scryfall.io/broken_image.jpg'),
          currentMarketPrice: const drift.Value(5.0),
          acquiredPrice: const drift.Value(2.0),
          acquiredDate: drift.Value(now),
          lastPriceUpdate: drift.Value(now),
          condition: const drift.Value('NM'),
          quantity: const drift.Value(1),
          isDeleted: const drift.Value(false),
          dynamicData: const drift.Value('{"color_identity":["B"]}'),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const drift.Value('card-null-img'),
          collectionType: const drift.Value('mtg'),
          name: const drift.Value('Null Image Card'),
          setOrSeries: const drift.Value('LEA'),
          imageUrl: const drift.Value(''),
          currentMarketPrice: const drift.Value(50.0),
          acquiredPrice: const drift.Value(20.0),
          acquiredDate: drift.Value(now),
          lastPriceUpdate: drift.Value(now),
          condition: const drift.Value('NM'),
          quantity: const drift.Value(1),
          isDeleted: const drift.Value(false),
          dynamicData: const drift.Value('{"mana_cost":"{2}{U}"}'),
        ),
      );
    }

    testWidgets('2.1: Selection succeeds when image fails/throws 404 (IgnorePointer + opaque hit test)', (tester) async {
      await setupDeckInDb();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('adversarial-deck-1').overrideWith((ref) => Stream.value(mockDeck)),
            deckItemsProvider('adversarial-deck-1').overrideWith(
              (ref) => Stream.value([
                {
                  'id': 'dvi-fail-1',
                  'vault_item_id': 'card-failing-img',
                  'name': 'Damaged Circuit Card',
                  'image_url': 'https://invalid-host-404.scryfall.io/broken_image.jpg',
                  'dynamic_data': '{}',
                },
              ]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeckThumbnailPickerModal(deck: mockDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileKey = const Key('cover_card_tile_card-failing-img');
      expect(find.byKey(tileKey), findsOneWidget);

      // Tap on card with failing network image
      await tester.tap(find.byKey(tileKey));
      await tester.pumpAndSettle();

      // Verify that coverItemId was updated despite network image failure
      final updated = await (db.select(db.decks)..where((t) => t.id.equals('adversarial-deck-1'))).getSingle();
      expect(updated.coverItemId, equals('card-failing-img'));
      expect(tester.takeException(), isNull);

      await cleanWidgetTree(tester);
    });

    testWidgets('2.2: Aggressive rapid tapping (10 taps) on cover card tile is safely debounced by _isSaving guard', (tester) async {
      await setupDeckInDb();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('adversarial-deck-1').overrideWith((ref) => Stream.value(mockDeck)),
            deckItemsProvider('adversarial-deck-1').overrideWith(
              (ref) => Stream.value([
                {
                  'id': 'dvi-fail-1',
                  'vault_item_id': 'card-failing-img',
                  'name': 'Damaged Circuit Card',
                  'image_url': 'https://invalid-host-404.scryfall.io/broken_image.jpg',
                  'dynamic_data': '{}',
                },
              ]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeckThumbnailPickerModal(deck: mockDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileKey = const Key('cover_card_tile_card-failing-img');

      // Dispatch 10 rapid taps in immediate succession
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byKey(tileKey), warnIfMissed: false);
      }
      await tester.pumpAndSettle();

      // Verify no Navigator pop collision or concurrency corruption
      expect(tester.takeException(), isNull);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals('adversarial-deck-1'))).getSingle();
      expect(updated.coverItemId, equals('card-failing-img'));

      await cleanWidgetTree(tester);
    });

    testWidgets('2.3: Rapid multi-tapping on Reset Cover button is safely guarded against concurrency collisions', (tester) async {
      final deckWithCover = Deck(
        id: 'adversarial-deck-reset',
        name: 'Adversarial Reset Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isAssembled: false,
        isCompetitive: false,
        coverItemId: 'card-failing-img',
        wins: 0,
        losses: 0,
        draws: 0,
        isDeleted: false,
        createdAt: now,
      );
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const drift.Value('adversarial-deck-reset'),
          name: const drift.Value('Adversarial Reset Deck'),
          format: const drift.Value('Commander'),
          tcgDomain: const drift.Value('mtg'),
          isRegistered: const drift.Value(false),
          isAssembled: const drift.Value(false),
          isCompetitive: const drift.Value(false),
          coverItemId: const drift.Value('card-failing-img'),
          isDeleted: const drift.Value(false),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('adversarial-deck-reset').overrideWith((ref) => Stream.value(deckWithCover)),
            deckItemsProvider('adversarial-deck-reset').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeckThumbnailPickerModal(deck: deckWithCover),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('reset_deck_cover_button'));
      expect(resetButton, findsOneWidget);

      // Dispatch 5 rapid taps on reset button
      for (int i = 0; i < 5; i++) {
        await tester.tap(resetButton, warnIfMissed: false);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final updated = await (db.select(db.decks)..where((t) => t.id.equals('adversarial-deck-reset'))).getSingle();
      expect(updated.coverItemId, isNull);

      await cleanWidgetTree(tester);
    });
  });

  // =========================================================================
  // Group 3: Requirement R4 — Modal Router Deep Verification (CardDetailSheet "Add to +" sheet)
  // =========================================================================
  group('R4 Adversarial: Modal Router Deep Verification in CardDetailSheet', () {
    late VaultItem unownedCard;

    setUp(() async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'unowned-adversarial-card-1',
          collectionType: 'mtg',
          name: 'Mox Diamond',
          setOrSeries: 'Stronghold',
          imageUrl: 'https://cards.scryfall.io/large/front/4/f/4fb011e5-9c05-4c07-8874-8d4e5f2cf97b.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 650.0,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_text":"Discard a land card: Add one mana of any color.","rarity":"rare"}',
        ),
      );

      unownedCard = await (db.select(db.vaultItems)..where((t) => t.id.equals('unowned-adversarial-card-1'))).getSingle();
    });

    Widget buildSheetHarness(VaultItem card) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => CardDetailSheet.show(ctx, card),
                    child: const Text('Open Card Detail'),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('3.1: Unowned card "Add to +" opens modal router and navigates cleanly into "Binders"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSheetHarness(unownedCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Card Detail'));
      await tester.pumpAndSettle();

      // Verify "Add to +" quick action button
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);
      expect(find.text('Add to +'), findsOneWidget);

      // Tap "Add to +"
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      // "Add to..." modal bottom sheet is displayed
      expect(find.text('Add to...'), findsOneWidget);
      expect(find.byKey(const Key('add_to_binders_option')), findsOneWidget);
      expect(find.byKey(const Key('add_to_decks_option')), findsOneWidget);

      // Tap "Binders" option
      await tester.tap(find.byKey(const Key('add_to_binders_option')));
      await tester.pumpAndSettle();

      // Verify "Move to Binder" modal opened cleanly
      expect(find.text('Move to Binder'), findsOneWidget);
      expect(find.byKey(const Key('move_to_inbox_tile')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close Move to Binder modal via topmost close button
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      // Back at CardDetailSheet
      expect(find.byType(CardDetailSheet), findsOneWidget);

      await cleanWidgetTree(tester);
    });

    testWidgets('3.2: Unowned card "Add to +" opens modal router and navigates cleanly into "Decks"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSheetHarness(unownedCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Card Detail'));
      await tester.pumpAndSettle();

      // Tap "Add to +"
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      // Tap "Decks" option
      await tester.tap(find.byKey(const Key('add_to_decks_option')));
      await tester.pumpAndSettle();

      // Verify Add Card to Deck dialog opened cleanly
      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Create and add'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close Add to Deck dialog via topmost close button
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      // Back at CardDetailSheet
      expect(find.byType(CardDetailSheet), findsOneWidget);

      await cleanWidgetTree(tester);
    });

    testWidgets('3.3: Rapid 5x open-close cycles of the "Add to +" modal router preserves navigation state without leaks', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSheetHarness(unownedCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Card Detail'));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        // Open modal router
        await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
        await tester.pumpAndSettle();

        expect(find.text('Add to...'), findsOneWidget);

        // Dismiss modal router via topmost close icon
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        expect(find.text('Add to...'), findsNothing);
        expect(find.byType(CardDetailSheet), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
      await cleanWidgetTree(tester);
    });
  });
}
