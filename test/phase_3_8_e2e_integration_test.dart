import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/shell/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Finds the large estimated total market value text in the portfolio summary card header
  Finder findHeaderMarketValue(String value) {
    return find.byWidgetPredicate(
      (w) => w is Text && w.data == value && w.style?.fontSize == 30,
    );
  }

  /// Builds a complete integration harness hosting VaultScreen and CustomBottomNavBar
  Widget buildE2EApp({
    required AppDatabase database,
    String activeGame = 'Magic: The Gathering',
    UserPersona initialPersona = UserPersona.investor,
    bool initialLoggedIn = false,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        vaultDaoProvider.overrideWithValue(database.vaultDao),
        activeGameContextProvider.overrideWith((ref) => activeGame),
        userPersonaProvider.overrideWith((ref) => initialPersona),
        isUserLoggedInProvider.overrideWith((ref) => initialLoggedIn),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: const VaultScreen(),
              bottomNavigationBar: CustomBottomNavBar(
                currentIndex: 1,
                onBranchSelected: (_) {},
                onScannerTap: () {},
                onMenuTap: () => MorphingCommandCenter.show(context),
              ),
            );
          },
        ),
      ),
    );
  }

  group('Tier 4 Real-World User Journey 1: Investor Workflow', () {
    testWidgets(
      'Full Investor Journey: Reactive totals -> Manual Add Search & Staging -> Bulk Persistence -> Detail Sheet -> Foil FullScreen -> Edit Modal Override -> Delete Confirmation & Reactivity',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Setup: Create custom binder & insert catalog reference card (quantity 0)
        await db.into(db.vaultBinders).insert(
              VaultBindersCompanion.insert(
                id: 'binder-investor-rare',
                name: 'Investor Binder',
                collectionType: 'mtg',
                createdAt: DateTime.now(),
              ),
            );

        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'catalog-sol-ring',
                collectionType: 'mtg',
                name: 'Sol Ring',
                setOrSeries: 'Commander Masters',
                imageUrl: '',
                acquiredPrice: 0.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(0),
                condition: 'NM',
                currentMarketPrice: 2.50,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'rarity': 'uncommon',
                  'type': 'Artifact',
                  'type_line': 'Artifact',
                  'mana_cost': '{1}',
                  'oracle_text': '{T}: Add {C}{C}.',
                  'keywords': <String>[],
                }),
              ),
            );

        // 2. Starts in Vault with reactive header metrics from SQLite
        await tester.pumpWidget(buildE2EApp(database: db));
        await tester.pumpAndSettle();

        // Baseline MTG totals: The One Ring (quantity 1, market price 45.50, acquired 15.00)
        expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);
        expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
        expect(find.text('Total Tracked Items: 1'), findsOneWidget);

        // 3. Opens ManualAddBottomSheet via [ + Add Item ]
        final addItemButton = find.byKey(const Key('vault_add_item_button'));
        expect(addItemButton, findsOneWidget);
        await tester.tap(addItemButton);
        await tester.pumpAndSettle();

        expect(find.byType(ManualAddBottomSheet), findsOneWidget);
        expect(find.text('Add Cards to Vault'), findsOneWidget);

        // 4. Performs 300ms debounced search for catalog cards
        final searchField = find.byType(SearchField);
        expect(searchField, findsOneWidget);

        // Type query 'Sol Ring'
        await tester.enterText(searchField, 'Sol Ring');

        // Before debounce (< 300ms), results haven't filtered to Sol Ring alone
        await tester.pump(const Duration(milliseconds: 150));

        // Advance past 300ms debounce
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Sol Ring appears in search results
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Sol Ring'),
          ),
          findsOneWidget,
        );
        expect(find.text('\$2.50'), findsOneWidget);

        // 5. Stages multiple quantities with stepper (0 -> 1 -> 2)
        final incrementButton =
            find.byKey(const Key('stepper_increment_catalog-sol-ring'));
        expect(incrementButton, findsOneWidget);

        await tester.tap(incrementButton);
        await tester.pumpAndSettle();
        expect(find.text('Add 1 Item to Vault'), findsOneWidget);

        await tester.tap(incrementButton);
        await tester.pumpAndSettle();
        expect(find.text('Add 2 Items to Vault'), findsOneWidget);

        // 6. Selects a specific destination binder ('Investor Binder')
        expect(find.text('Unsorted (Main Vault)'), findsOneWidget);
        await tester.tap(find.text('Unsorted (Main Vault)'));
        await tester.pumpAndSettle();

        expect(find.text('Investor Binder').last, findsOneWidget);
        await tester.tap(find.text('Investor Binder').last);
        await tester.pumpAndSettle();

        // 7. Submits bulk add
        final bulkSubmitButton =
            find.byKey(const Key('bulk_add_submit_button'));
        expect(bulkSubmitButton, findsOneWidget);
        await tester.tap(bulkSubmitButton);
        await tester.pumpAndSettle();

        // Bottom sheet popped
        expect(find.byType(ManualAddBottomSheet), findsNothing);

        // 8. Verifies Vault totals header reactively updates with new totalCount and totalMarketValue
        // Total Count: 1 (The One Ring) + 2 (Sol Rings) = 3
        // Market Value: 45.50 + (2 * 2.50) = 50.50
        expect(find.text('Total Tracked Items: 3'), findsOneWidget);
        expect(findHeaderMarketValue('\$50.50'), findsOneWidget);

        // Verify SQLite reflects quantity and destination binder
        final inDb = await db.vaultDao.getItemById('catalog-sol-ring');
        expect(inDb, isNotNull);
        expect(inDb!.quantity, 2);
        expect(inDb.primaryBinderId, 'binder-investor-rare');

        // 9. Opens CardDetailSheet on an added card ('Sol Ring')
        final solRingCardFinder =
            find.widgetWithText(VaultItemCard, 'Sol Ring');
        expect(solRingCardFinder, findsOneWidget);

        await tester.tap(solRingCardFinder);
        await tester.pumpAndSettle();

        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(
            find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);

        // 10. Opens FullScreenCardViewer, verifies InteractiveViewer and toggles foil finish
        final fullscreenButton =
            find.byKey(const Key('quick_action_fullscreen'));
        expect(fullscreenButton, findsOneWidget);
        await tester.tap(fullscreenButton);
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenCardViewer), findsOneWidget);
        expect(find.byKey(const Key('fullscreen_interactive_viewer')),
            findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);

        // Toggle foil finish on
        final foilToggle = find.byKey(const Key('fullscreen_foil_toggle'));
        expect(foilToggle, findsOneWidget);
        await tester.tap(foilToggle);
        await tester.pump(const Duration(milliseconds: 100));

        // Shimmer animated ShaderMask rendered
        expect(find.byType(ShaderMask), findsOneWidget);

        // Toggle foil finish off cleanly before settling
        await tester.tap(foilToggle);
        await tester.pump(const Duration(milliseconds: 100));

        // Close fullscreen viewer
        await tester.tap(find.byKey(const Key('fullscreen_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenCardViewer), findsNothing);

        // 11. Opens EditCardModal, alters condition flags, overrides acquired price, adds custom tags, and saves
        final editButton = find.byKey(const Key('quick_action_edit'));
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(find.byType(EditCardModal), findsOneWidget);

        // Alter condition checkboxes: isSigned, isAltered, isGraded
        await tester.tap(find.byKey(const Key('condition_checkbox_signed')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('condition_checkbox_altered')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('condition_checkbox_graded')));
        await tester.pumpAndSettle();

        // Override acquired price field
        final priceField =
            find.byKey(const Key('edit_card_acquired_price_field'));
        expect(priceField, findsOneWidget);
        await tester.enterText(priceField, '10.00');
        await tester.pumpAndSettle();

        // Add custom tag 'Commander Staple'
        await tester.enterText(
            find.byKey(const Key('edit_card_tag_input')), 'Commander Staple');
        await tester.tap(find.byKey(const Key('edit_card_add_tag_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tag_chip_Commander Staple')), findsOneWidget);

        // Save changes
        await tester.tap(find.byKey(const Key('save_card_edits_button')));
        await tester.pumpAndSettle();

        expect(find.byType(EditCardModal), findsNothing);

        // 12. Verifies updated card details reflect in UI and Vault totals
        // Verify in SQLite schema v4 columns
        final editedDbItem = await db.vaultDao.getItemById('catalog-sol-ring');
        expect(editedDbItem, isNotNull);
        expect(editedDbItem!.isSigned, isTrue);
        expect(editedDbItem.isAltered, isTrue);
        expect(editedDbItem.isGraded, isTrue);
        expect(editedDbItem.acquiredPrice, 10.00);

        final dynamicData =
            jsonDecode(editedDbItem.dynamicData) as Map<String, dynamic>;
        expect(dynamicData['tags'], contains('Commander Staple'));

        // Verify updated price reflects in CardDetailSheet UI
        expect(find.textContaining('10.00'), findsWidgets);

        // 13. Deletes card via Quick Action Bar with confirmation dialog and verifies totals update
        final deleteButton = find.byKey(const Key('quick_action_delete'));
        expect(deleteButton, findsOneWidget);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.byKey(const Key('card_detail_delete_dialog')), findsOneWidget);
        expect(find.text('Delete Card?'), findsOneWidget);

        // Confirm deletion
        await tester.tap(find.byKey(const Key('delete_confirm_button')));
        await tester.pumpAndSettle();

        // Sheet is popped and dismissed
        expect(find.byType(CardDetailSheet), findsNothing);

        // Verify card is deleted from SQLite
        final deletedItem = await db.vaultDao.getItemById('catalog-sol-ring');
        expect(deletedItem, isNull);

        // Verify Vault totals header reactively restores to single seed item
        expect(find.text('Total Tracked Items: 1'), findsOneWidget);
        expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('Tier 4 Real-World User Journey 2: Player Workflow', () {
    testWidgets(
      'Full Player Journey: Drawer persona toggle -> Dynamic VaultItemCard player layout (Mana, P/T, keywords, no financial deltas) -> Add to Deck -> Unauthenticated Share login prompt -> Authenticated Share',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Setup: Insert MTG combat creature with Mana Cost, P/T, and keywords
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'item-mtg-atraxa',
                collectionType: 'mtg',
                name: "Atraxa, Praetors' Voice",
                setOrSeries: 'Commander 2016',
                imageUrl: '',
                acquiredPrice: 20.00,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 50.00,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'mana_cost': '{G}{W}{U}{B}',
                  'type_line': 'Legendary Creature — Phyrexian Angel',
                  'power': '4',
                  'toughness': '4',
                  'oracle_text':
                      'Flying, vigilance, deathtouch, lifelink.\nAt the beginning of your end step, proliferate.',
                  'keywords': ['Flying', 'Vigilance', 'Deathtouch', 'Lifelink'],
                  'rarity': 'mythic',
                }),
              ),
            );

        // 2. Starts in Vault with Investor Mode active
        await tester.pumpWidget(buildE2EApp(
          database: db,
          initialPersona: UserPersona.investor,
          initialLoggedIn: false,
        ));
        await tester.pumpAndSettle();

        // Initially in Investor Mode: verify financial labels inside VaultItemCard
        final vaultCardFinder = find.byType(VaultItemCard);
        expect(
          find.descendant(of: vaultCardFinder, matching: find.text('ACQUIRED')),
          findsWidgets,
        );
        expect(
          find.descendant(of: vaultCardFinder, matching: find.text('LIVE TMV')),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: vaultCardFinder,
            matching: find.byIcon(Icons.trending_up_rounded),
          ),
          findsWidgets,
        );

        // 3. Opens MorphingCommandCenter (Drawer) via Menu tap in CustomBottomNavBar
        final menuTouchTarget = find.text('Menu');
        expect(menuTouchTarget, findsOneWidget);
        await tester.tap(menuTouchTarget);
        await tester.pumpAndSettle();

        expect(find.byType(MorphingCommandCenter), findsOneWidget);
        expect(find.text('COMMAND CENTER'), findsOneWidget);

        // 4. Toggles segmented switch to [ ⚔️ Player ]
        final playerToggle = find.byKey(const Key('persona_toggle_player'));
        expect(playerToggle, findsOneWidget);
        await tester.tap(playerToggle);
        await tester.pumpAndSettle();

        expect(find.text('PLAYER MODE'), findsOneWidget);

        // 5. Closes drawer & returns to Vault
        final closeMenuButton = find.byTooltip('Close Menu');
        expect(closeMenuButton, findsOneWidget);
        await tester.tap(closeMenuButton);
        await tester.pumpAndSettle();

        expect(find.byType(MorphingCommandCenter), findsNothing);

        // 6. Verifies VaultItemCard switches to Player Mode
        // Displays Mana Cost, P/T, keywords, and GAME UTILITY badge
        expect(find.text('{G}{W}{U}{B}'), findsOneWidget);
        expect(find.text('⚔️ 4 / 🛡️ 4'), findsOneWidget);
        expect(find.text('Flying'), findsOneWidget);
        expect(find.text('Vigilance'), findsOneWidget);
        expect(find.text('Deathtouch'), findsOneWidget);
        expect(find.text('Lifelink'), findsOneWidget);
        expect(find.text('GAME UTILITY'), findsWidgets);

        // CRITICAL: Verifies financial deltas are completely HIDDEN inside VaultItemCard in Player Mode
        expect(
          find.descendant(of: vaultCardFinder, matching: find.text('ACQUIRED')),
          findsNothing,
        );
        expect(
          find.descendant(of: vaultCardFinder, matching: find.text('LIVE TMV')),
          findsNothing,
        );
        expect(
          find.descendant(of: vaultCardFinder, matching: find.text('\$20.00')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: vaultCardFinder,
            matching: find.byIcon(Icons.trending_up_rounded),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: vaultCardFinder,
            matching: find.byIcon(Icons.trending_down_rounded),
          ),
          findsNothing,
        );

        // 7. Opens CardDetailSheet on Atraxa
        final atraxaCardFinder =
            find.widgetWithText(VaultItemCard, "Atraxa, Praetors' Voice");
        expect(atraxaCardFinder, findsOneWidget);
        await tester.tap(atraxaCardFinder);
        await tester.pumpAndSettle();

        expect(find.byType(CardDetailSheet), findsOneWidget);

        // 8. Adds card to a deck via Quick Action Bar [ Add to Deck ]
        final addToDeckButton =
            find.byKey(const Key('quick_action_add_to_deck'));
        expect(addToDeckButton, findsOneWidget);
        await tester.tap(addToDeckButton);
        await tester.pumpAndSettle();

        expect(find.text('Add Card to Deck'), findsOneWidget);
        expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

        // Tap deck to add
        await tester.tap(find.text('Edgar Markov Aristocrats'));
        await tester.pumpAndSettle();

        // Verify persisted into SQLite dynamicData['deck_history']
        final inDb = await db.vaultDao.getItemById('item-mtg-atraxa');
        expect(inDb, isNotNull);
        final dynamicData =
            jsonDecode(inDb!.dynamicData) as Map<String, dynamic>;
        final deckHistory = List<String>.from(dynamicData['deck_history'] ?? []);
        expect(deckHistory, contains('Edgar Markov Aristocrats'));

        // 9. Taps [ Share ] unauthenticated and verifies login dialog prompt appears
        final shareButton = find.byKey(const Key('quick_action_share'));
        expect(shareButton, findsOneWidget);
        await tester.tap(shareButton);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('share_login_dialog')), findsOneWidget);
        expect(find.text('Sign in to Share'), findsOneWidget);

        // 10. Authenticates via login dialog and verifies subsequent Share action
        final signInButton = find.byKey(const Key('share_login_button'));
        expect(signInButton, findsOneWidget);
        await tester.tap(signInButton);
        await tester.pumpAndSettle();

        // Verify login dialog dismissed
        expect(find.byKey(const Key('share_login_dialog')), findsNothing);

        // Tap Share again now that isUserLoggedIn is true
        await tester.tap(shareButton);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);
        expect(find.textContaining("Share Atraxa, Praetors' Voice"), findsOneWidget);

        // Close share dialog
        await tester.tap(find.byKey(const Key('share_dialog_close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('card_share_dialog')), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  group('Tier 3 Cross-Feature Combinatorial & Adversarial Edge Scenarios', () {
    testWidgets(
      'Pairwise Integration 1: Persona toggles preserve live VaultTotals reactivity while filtering collection and binders',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed an additional MTG binder
        await db.into(db.vaultBinders).insert(
              VaultBindersCompanion.insert(
                id: 'binder-modern-staples',
                name: 'Modern Staples',
                collectionType: 'mtg',
                createdAt: DateTime.now(),
              ),
            );

        await (db.update(db.vaultItems)
              ..where((t) => t.id.equals('item-mtg-one-ring')))
            .write(
          const VaultItemsCompanion(
            primaryBinderId: drift.Value('binder-modern-staples'),
          ),
        );

        await tester.pumpWidget(buildE2EApp(database: db));
        await tester.pumpAndSettle();

        // 1. Investor mode initial totals: The One Ring ($45.50)
        expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
        expect(find.text('Total Tracked Items: 1'), findsOneWidget);

        // 2. Open drawer and toggle to Player mode
        await tester.tap(find.text('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('persona_toggle_player')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close Menu'));
        await tester.pumpAndSettle();

        // 3. Vault header totals remain strictly reactive and accurate in Player mode
        expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
        expect(find.text('Total Tracked Items: 1'), findsOneWidget);

        // 4. Insert an additional card into database directly
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'item-mtg-mox-opal',
                collectionType: 'mtg',
                name: 'Mox Opal',
                setOrSeries: 'Scars of Mirrodin',
                imageUrl: '',
                acquiredPrice: 80.00,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 100.00,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'mana_cost': '{0}',
                  'oracle_text': 'Metalcraft — {T}: Add one mana of any color.',
                  'keywords': <String>[],
                }),
                primaryBinderId: const drift.Value('binder-modern-staples'),
              ),
            );

        await tester.pumpAndSettle();

        // Header reactively reflects 2 items, $145.50 in Player mode
        expect(find.text('Total Tracked Items: 2'), findsOneWidget);
        expect(findHeaderMarketValue('\$145.50'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Pairwise Integration 2: Manual Add staging boundary recovery (zeroing out steppers, search clear, atomic commit)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert two catalog cards
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'cat-card-1',
                collectionType: 'mtg',
                name: 'Lightning Bolt',
                setOrSeries: 'Alpha',
                imageUrl: '',
                acquiredPrice: 0.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(0),
                condition: 'NM',
                currentMarketPrice: 5.00,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
              ),
            );

        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'cat-card-2',
                collectionType: 'mtg',
                name: 'Counterspell',
                setOrSeries: 'Beta',
                imageUrl: '',
                acquiredPrice: 0.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(0),
                condition: 'NM',
                currentMarketPrice: 3.00,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
              ),
            );

        await tester.pumpWidget(buildE2EApp(database: db));
        await tester.pumpAndSettle();

        // Open Manual Add Bottom Sheet
        await tester.tap(find.byKey(const Key('vault_add_item_button')));
        await tester.pumpAndSettle();

        // Stage Lightning Bolt to 1
        await tester.tap(find.byKey(const Key('stepper_increment_cat-card-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bulk_add_submit_button')), findsOneWidget);
        expect(find.text('Add 1 Item to Vault'), findsOneWidget);

        // Decrement back to 0 -> sticky action bar hides
        await tester.tap(find.byKey(const Key('stepper_decrement_cat-card-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);

        // Search for 'Counterspell'
        await tester.enterText(find.byType(SearchField), 'Counterspell');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Target list item specifically (not EditableText in SearchField)
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Counterspell'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Lightning Bolt'),
          ),
          findsNothing,
        );

        // Stage Counterspell to 3
        await tester.tap(find.byKey(const Key('stepper_increment_cat-card-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('stepper_increment_cat-card-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('stepper_increment_cat-card-2')));
        await tester.pumpAndSettle();

        expect(find.text('Add 3 Items to Vault'), findsOneWidget);

        // Clear search field
        await tester.tap(find.byKey(const Key('search_field_clear_button')));
        await tester.pumpAndSettle();

        // Both cards visible in results list again, Counterspell retains staged quantity of 3
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Lightning Bolt'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Counterspell'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('stepper_count_cat-card-2')), findsOneWidget);
        expect(find.text('Add 3 Items to Vault'), findsOneWidget);

        // Submit bulk add
        await tester.tap(find.byKey(const Key('bulk_add_submit_button')));
        await tester.pumpAndSettle();

        // Sheet closed and Vault totals updated: 1 + 3 = 4 items; $45.50 + (3 * $3.00) = $54.50
        expect(find.byType(ManualAddBottomSheet), findsNothing);
        expect(find.text('Total Tracked Items: 4'), findsOneWidget);
        expect(findHeaderMarketValue('\$54.50'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Pairwise Integration 3: Multi-quantity acquired price edit recalculates cost basis and profit metrics in real-time',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert card with quantity = 5, acquired = 2.0, market = 10.0
        // Total cost = 10.0, Total market = 50.0
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'item-mtg-swords',
                collectionType: 'mtg',
                name: 'Swords to Plowshares',
                setOrSeries: 'Ice Age',
                imageUrl: '',
                acquiredPrice: 2.00,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(5),
                condition: 'NM',
                currentMarketPrice: 10.00,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
              ),
            );

        // Listen to live watchVaultTotals stream
        final costHistory = <double>[];
        final subscription = db.vaultDao
            .watchVaultTotals(collectionType: 'mtg')
            .listen((totals) {
          costHistory.add(totals.totalCostBasis);
        });
        addTearDown(() => subscription.cancel());

        await tester.pumpWidget(buildE2EApp(database: db));
        await tester.pumpAndSettle();

        // Open CardDetailSheet on Swords to Plowshares
        await tester.tap(find.widgetWithText(VaultItemCard, 'Swords to Plowshares'));
        await tester.pumpAndSettle();

        // Tap Edit in Quick Action Bar
        await tester.tap(find.byKey(const Key('quick_action_edit')));
        await tester.pumpAndSettle();

        // Override acquired price from 2.00 to 8.00
        // New cost basis for 5 items = 5 * 8.00 = 40.00 (+ The One Ring's 15.00 = 55.00 total)
        await tester.enterText(
            find.byKey(const Key('edit_card_acquired_price_field')), '8.00');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_card_edits_button')));
        await tester.pumpAndSettle();

        // Verify SQLite reflects new acquired price
        final updated = await db.vaultDao.getItemById('item-mtg-swords');
        expect(updated, isNotNull);
        expect(updated!.acquiredPrice, 8.00);

        // Verify stream emission includes new cost basis of 55.00
        await tester.pump(const Duration(milliseconds: 100));
        expect(costHistory, contains(55.00));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
