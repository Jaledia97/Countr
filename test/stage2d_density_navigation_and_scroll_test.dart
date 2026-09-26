import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:countr/features/shell/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/widgets/catalog_card_list_tile.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() {
    ParsedJsonCache.clear();
    db = AppDatabase(NativeDatabase.memory());
    dao = VaultDao(db);
  });

  tearDown(() async {
    ParsedJsonCache.clear();
    await db.close();
  });

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
    Size size = const Size(1080, 2400),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        ...overrides,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('1. ParsedJsonCache LRU Memoization & Zero-Cost Parsing (Bottleneck B1)', () {
    test('Memoizes valid JSON strings and returns identical Map instance', () {
      const rawJson = '{"mana_cost":"{2}{U}{B}","type_line":"Creature — Wizard","rarity":"rare"}';

      final firstParse = ParsedJsonCache.parse(rawJson);
      expect(firstParse['mana_cost'], equals('{2}{U}{B}'));
      expect(firstParse['type_line'], equals('Creature — Wizard'));
      expect(firstParse['rarity'], equals('rare'));
      expect(ParsedJsonCache.count, equals(1));

      // Second retrieval should return the exact same Map reference from cache
      final secondParse = ParsedJsonCache.parse(rawJson);
      expect(identical(firstParse, secondParse), isTrue);
      expect(ParsedJsonCache.count, equals(1));
    });

    test('Handles null, empty, and malformed JSON safely without throwing', () {
      expect(ParsedJsonCache.parse(null), isEmpty);
      expect(ParsedJsonCache.parse(''), isEmpty);
      expect(ParsedJsonCache.parse('{not a valid json}'), isEmpty);
      expect(ParsedJsonCache.parse('["list", "instead", "of", "map"]'), isEmpty);
    });

    test('Clear resets cache count', () {
      ParsedJsonCache.parse('{"id": 1}');
      ParsedJsonCache.parse('{"id": 2}');
      expect(ParsedJsonCache.count, equals(2));

      ParsedJsonCache.clear();
      expect(ParsedJsonCache.count, equals(0));
    });
  });

  group('2. Data-Dense ExpansionTile Lists in VaultItemCard', () {
    final sampleItem = VaultItem(
      id: 'vault-item-1',
      name: 'Counterspell',
      setOrSeries: 'EMA',
      imageUrl: 'https://cards.scryfall.io/small/front/c/c/cc8.jpg',
      quantity: 2,
      dynamicData: jsonEncode({
        'mana_cost': '{U}{U}',
        'type_line': 'Instant',
        'rarity': 'uncommon',
        'oracle_text': 'Counter target spell.',
        'rulings_snippet': 'A spell is only countered if it is successfully resolved.',
      }),
      collectionType: 'mtg',
      acquiredPrice: 1.50,
      acquiredDate: DateTime(2026, 1, 1),
      lastPriceUpdate: DateTime(2026, 1, 1),
      currentMarketPrice: 2.25,
      isGraded: false,
      condition: 'NM',
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      protectionStatus: 'Sleeved',
      isDeleted: false,
    );

    testWidgets('Renders collapsed header with thumbnail, ManaCostBar, subtitle, and condition badge', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: VaultItemCard(
            item: sampleItem,
            initiallyExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card title and ManaCostBar
      expect(find.text('Counterspell'), findsOneWidget);
      expect(find.byType(ManaCostBar), findsOneWidget);

      // Subtitle elements
      expect(find.textContaining('EMA'), findsOneWidget);
      expect(find.textContaining('Instant'), findsOneWidget);
      expect(find.text('UNCOMMON'), findsOneWidget);
      expect(find.text('\$2.25'), findsOneWidget);

      // Condition badge
      expect(find.text('NM'), findsOneWidget);

      // RepaintBoundary wrapping
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('Tapping VaultItemCard expands to reveal ManaText Oracle rules text and quick action buttons', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: VaultItemCard(
            item: sampleItem,
            initiallyExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.text('Counterspell'));
      await tester.pumpAndSettle();

      // Oracle rules text rendered via ManaText
      expect(find.byType(ManaText), findsWidgets);
      expect(find.textContaining('Counter target spell.'), findsOneWidget);

      // Quick action buttons
      expect(find.text('Full Details'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
    });

    testWidgets('Tapping thumbnail directly invokes onTap without requiring expansion', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createHarness(
          child: VaultItemCard(
            item: sampleItem,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap thumbnail directly
      final thumbnail = find.byType(CountrCachedImage);
      expect(thumbnail, findsOneWidget);
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('3. Data-Dense ExpansionTile Lists in DeckBuilderScreen', () {
    final sampleDeck = Deck(
      id: 'deck-101',
      name: 'Simic Flash Control',
      format: 'Commander',
      tcgDomain: 'mtg',
      wins: 0,
      losses: 0,
      draws: 0,
      isCompetitive: false,
      isRegistered: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
    );

    final deckItemCard = {
      'id': 'dvi-1',
      'vault_item_id': 'v-101',
      'name': 'Mystic Snake',
      'set_or_series': 'A25',
      'image_url': 'https://cards.scryfall.io/small/front/m/y/mystic.jpg',
      'deck_quantity': 2,
      'vault_quantity': 4,
      'current_market_price': 1.10,
      'dynamic_data': jsonEncode({
        'mana_cost': '{1}{G}{U}{U}',
        'type_line': 'Creature — Snake Elf',
        'oracle_text': 'Flash. When Mystic Snake enters the battlefield, counter target spell.',
      }),
      'board_zone': 'Mainboard',
      'is_proxy': 0,
      'condition': 'NM',
    };

    testWidgets('Renders DeckBuilderScreen card items as ExpansionTile with ManaCostBar, ManaText, and RepaintBoundary', (tester) async {
      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: Value(sampleDeck.id),
          name: Value(sampleDeck.name),
          format: Value(sampleDeck.format),
          tcgDomain: const Value('mtg'),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('dv-1'),
          deckId: Value(sampleDeck.id),
          versionNumber: const Value(1),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-1'),
          versionId: const Value('dv-1'),
          vaultItemId: const Value('v-101'),
          quantity: const Value(2),
          boardZone: const Value('Mainboard'),
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('v-101'),
          name: const Value('Mystic Snake'),
          setOrSeries: const Value('A25'),
          imageUrl: const Value('https://cards.scryfall.io/small/front/m/y/mystic.jpg'),
          quantity: const Value(4),
          dynamicData: Value(deckItemCard['dynamic_data'] as String),
          collectionType: const Value('mtg'),
          acquiredPrice: const Value(1.00),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          currentMarketPrice: const Value(1.10),
          condition: const Value('NM'),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          child: DeckBuilderScreen(deck: sampleDeck),
        ),
      );
      await tester.pumpAndSettle();

      // Card title and inline ManaCostBar
      expect(find.text('Mystic Snake'), findsOneWidget);
      expect(find.byType(ManaCostBar), findsOneWidget);

      // Quantity badge 'x2'
      expect(find.text('x2'), findsOneWidget);

      // Subtitle
      expect(find.textContaining('A25'), findsOneWidget);
      expect(find.textContaining('Creature — Snake Elf'), findsOneWidget);

      // ExpansionTile tap
      await tester.tap(find.text('Mystic Snake'));
      await tester.pumpAndSettle();

      // Expanded ManaText and Quick Actions
      expect(find.byType(ManaText), findsWidgets);
      expect(find.textContaining('counter target spell'), findsOneWidget);
      expect(find.text('Full Details'), findsOneWidget);
      expect(find.text('Remove / Adjust'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);

      // Verify RepaintBoundary surrounds tiles
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('ProportionalBubbleScrollbar rail is wrapped with RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: DeckBuilderScreen(deck: sampleDeck),
        ),
      );
      await tester.pumpAndSettle();

      final scrollbarFinder = find.byType(ProportionalBubbleScrollbar);
      if (scrollbarFinder.evaluate().isNotEmpty) {
        final parentRepaint = find.ancestor(
          of: scrollbarFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(parentRepaint, findsWidgets);
      }
    });
  });

  group('4. CatalogCardListTile in Catalog Search', () {
    final catalogCard = VaultItem(
      id: 'cat-1',
      name: 'Lightning Bolt',
      flavorName: 'Bolt of Retribution',
      setOrSeries: '2X2',
      imageUrl: 'https://cards.scryfall.io/small/front/l/b/bolt.jpg',
      quantity: 1,
      dynamicData: jsonEncode({
        'mana_cost': '{R}',
        'type_line': 'Instant',
        'rarity': 'uncommon',
        'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
        'flavor_text': 'The spark of fury ignited the heavens.',
        'collector_number': '117',
        'released_at': '2022-07-08',
      }),
      collectionType: 'mtg',
      acquiredPrice: 0.0,
      acquiredDate: DateTime.now(),
      lastPriceUpdate: DateTime.now(),
      currentMarketPrice: 2.99,
      isGraded: false,
      condition: 'NM',
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      protectionStatus: 'Raw',
      isDeleted: false,
    );

    testWidgets('Renders dense list tile with ManaCostBar, rarity badge, and expandable Oracle text', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: CatalogCardListTile(
            card: catalogCard,
            trailing: const Icon(Icons.add, key: Key('add_btn')),
            initiallyExpanded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Name & ManaCostBar
      expect(find.text('Bolt of Retribution'), findsOneWidget);
      expect(find.byType(ManaCostBar), findsOneWidget);

      // Subtitle elements
      expect(find.textContaining('2X2'), findsOneWidget);
      expect(find.textContaining('Instant'), findsOneWidget);
      expect(find.text('UNCOMMON'), findsOneWidget);
      expect(find.text('\$2.99'), findsOneWidget);

      // Trailing widget
      expect(find.byKey(const Key('add_btn')), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Bolt of Retribution'));
      await tester.pumpAndSettle();

      // Expanded content: canonical name, ManaText oracle rules, flavor text, set details
      expect(find.textContaining('Canonical Name: Lightning Bolt'), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);
      expect(find.textContaining('deals 3 damage'), findsOneWidget);
      expect(find.textContaining('The spark of fury'), findsOneWidget);
      expect(find.text('Set: 2X2'), findsOneWidget);
      expect(find.text('No.: #117'), findsOneWidget);
      expect(find.text('Rarity: UNCOMMON'), findsOneWidget);
    });
  });

  group('5. Viewport Overflow Hardening in BinderDetailScreen (<= 360px)', () {
    testWidgets('Renders without RenderFlex overflow on narrow 320px viewport', (tester) async {
      final now = DateTime.now();
      final binder = VaultBinder(
        id: 'binder-narrow',
        name: 'Vintage Cube Foil Binder High Value Collection',
        collectionType: 'mtg',
        createdAt: now,
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-sol-ring-narrow'),
          collectionType: const Value('mtg'),
          name: const Value('Sol Ring'),
          setOrSeries: const Value('C21'),
          imageUrl: const Value('https://cards.scryfall.io/normal/solring.jpg'),
          currentMarketPrice: const Value(2500.0),
          acquiredPrice: const Value(2000.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          primaryBinderId: const Value('binder-narrow'),
          isDeleted: const Value(false),
          dynamicData: const Value('{}'),
        ),
      );

      // Set narrow viewport (320px wide)
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createHarness(
          size: const Size(320, 800),
          child: BinderDetailScreen(binder: binder),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow exception was thrown
      expect(tester.takeException(), isNull);

      // Check header values exist and are constrained with Flexible and FittedBox
      expect(find.text('Vintage Cube Foil Binder High Value Collection'), findsOneWidget);
      expect(find.text('TOTAL BINDER VALUE'), findsOneWidget);
      expect(find.byType(FittedBox), findsWidgets);
      expect(find.byType(Flexible), findsWidgets);
    });

    testWidgets('Renders without RenderFlex overflow on 360px viewport', (tester) async {
      final now = DateTime.now();
      final binder = VaultBinder(
        id: 'binder-360',
        name: 'Modern Horizons 3 Master Set Binder',
        collectionType: 'mtg',
        createdAt: now,
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-sol-ring-360'),
          collectionType: const Value('mtg'),
          name: const Value('Sol Ring'),
          setOrSeries: const Value('C21'),
          imageUrl: const Value('https://cards.scryfall.io/normal/solring.jpg'),
          currentMarketPrice: const Value(2500.0),
          acquiredPrice: const Value(2000.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          primaryBinderId: const Value('binder-360'),
          isDeleted: const Value(false),
          dynamicData: const Value('{}'),
        ),
      );

      // Set 360px wide viewport
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createHarness(
          size: const Size(360, 800),
          child: BinderDetailScreen(binder: binder),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Modern Horizons 3 Master Set Binder'), findsOneWidget);
      expect(find.text('TOTAL BINDER VALUE'), findsOneWidget);
      expect(find.byType(FittedBox), findsWidgets);
    });
  });

  group('6. Pop-to-Root Navigation & Active Branch Reselection', () {
    testWidgets('CustomBottomNavBar triggers onActiveBranchReselected when current tab is re-tapped', (tester) async {
      int? reselectedBranch;
      int? selectedBranch;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 2, // Currently on Decks tab (index 2)
              onBranchSelected: (index) {
                selectedBranch = index;
              },
              onActiveBranchReselected: (index) {
                reselectedBranch = index;
              },
              onMenuTap: () {},
              onScannerTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tab 2 (Decks tab, already active)
      await tester.tap(find.text('Decks'));
      await tester.pumpAndSettle();

      // Reselected callback must be triggered with branch index 2
      expect(reselectedBranch, equals(2));

      // Tap tab 1 (Vault tab, different tab)
      await tester.tap(find.text('Vault'));
      await tester.pumpAndSettle();

      // Standard select callback triggered with branch index 1
      expect(selectedBranch, equals(1));
    });

    testWidgets('MainShellScreen pop-to-root callback resets root Navigator modals to first route', (tester) async {
      bool goBranchCalled = false;
      int? targetBranch;
      bool? initialLocationArg;

      // Mock StatefulNavigationShell behavior (currently at Feed tab: index 0)
      final mockShell = _MockStatefulNavigationShell(
        currentIndex: 0,
        onGoBranch: (index, {bool? initialLocation}) {
          goBranchCalled = true;
          targetBranch = index;
          initialLocationArg = initialLocation;
        },
      );

      final rootNavKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: rootNavKey,
            home: MainShellScreen(navigationShell: mockShell),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Show a dialog on top of the root navigator
      showDialog(
        context: rootNavKey.currentContext!,
        useRootNavigator: true,
        builder: (context) => const AlertDialog(
          title: Text('Sub Modal Dialog'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sub Modal Dialog'), findsOneWidget);

      // Invoke pop-to-root on the active branch (index 0)
      final navBar = tester.widget<CustomBottomNavBar>(find.byType(CustomBottomNavBar));
      navBar.onActiveBranchReselected?.call(0);
      await tester.pumpAndSettle();

      // Modal dialog is popped back to root
      expect(find.text('Sub Modal Dialog'), findsNothing);

      // goBranch was called with initialLocation: true
      expect(goBranchCalled, isTrue);
      expect(targetBranch, equals(0));
      expect(initialLocationArg, isTrue);
    });
  });

  group('7. Scroll Bottleneck Remediation & Image Management (survey_ui.md § 5.3)', () {
    testWidgets('DecksScreen uses CountrCachedImage for Commander art rather than raw Image.network (B2)', (tester) async {
      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-art-test'),
          name: const Value('Atraxa Superfriends'),
          format: const Value('Commander'),
          tcgDomain: const Value('mtg'),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('v-art-test'),
          deckId: const Value('deck-art-test'),
          versionNumber: const Value(1),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-atraxa-art'),
          name: const Value('Atraxa, Praetors\' Voice'),
          setOrSeries: const Value('C16'),
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/a/t/atraxa.jpg'),
          quantity: const Value(1),
          dynamicData: const Value('{}'),
          collectionType: const Value('mtg'),
          acquiredPrice: const Value(20.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          currentMarketPrice: const Value(25.0),
          condition: const Value('NM'),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-atraxa-art'),
          versionId: const Value('v-art-test'),
          vaultItemId: const Value('card-atraxa-art'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          child: const DecksScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atraxa Superfriends'), findsOneWidget);

      // DecksScreen should NOT use raw Image.network for card art
      // Verify CountrCachedImage is present in widget tree
      expect(find.byType(CountrCachedImage), findsWidgets);
    });
  });
}

/// Lightweight mock implementing [StatefulNavigationShell] interface for testing
class _MockStatefulNavigationShell extends StatefulWidget
    implements StatefulNavigationShell {
  @override
  final int currentIndex;
  final void Function(int index, {bool? initialLocation}) onGoBranch;

  const _MockStatefulNavigationShell({
    required this.currentIndex,
    required this.onGoBranch,
  });

  @override
  State<_MockStatefulNavigationShell> createState() =>
      _MockStatefulNavigationShellState();

  @override
  void goBranch(int index, {bool? initialLocation}) {
    onGoBranch(index, initialLocation: initialLocation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStatefulNavigationShellState
    extends State<_MockStatefulNavigationShell> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
