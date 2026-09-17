import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

VaultItemsCompanion createCompanion({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'IKO',
  String imageUrl = '',
  String? flavorName,
  double currentMarketPrice = 0.0,
  String dynamicData = '{}',
}) {
  final now = DateTime.now();
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    flavorName: flavorName != null ? drift.Value(flavorName) : const drift.Value.absent(),
    acquiredPrice: 0.0,
    acquiredDate: now,
    condition: 'NM',
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scryfall Parser - Adventure & Pricing Metadata Tests', () {
    test('mapScryfallCardToCompanion preserves layout and prices in dynamicData', () {
      final adventureJson = {
        'id': 'bonecrusher-giant-1',
        'name': 'Bonecrusher Giant // Stomp',
        'layout': 'adventure',
        'mana_cost': '{2}{R}',
        'type_line': 'Creature — Giant // Instant — Adventure',
        'oracle_text':
            'Whenever Bonecrusher Giant becomes the target of a spell, Bonecrusher Giant deals 2 damage to that spell\'s controller.',
        'card_faces': [
          {
            'name': 'Bonecrusher Giant',
            'mana_cost': '{2}{R}',
            'type_line': 'Creature — Giant',
            'oracle_text':
                'Whenever Bonecrusher Giant becomes the target of a spell, Bonecrusher Giant deals 2 damage to that spell\'s controller.',
            'power': '4',
            'toughness': '3',
          },
          {
            'name': 'Stomp',
            'mana_cost': '{1}{R}',
            'type_line': 'Instant — Adventure',
            'oracle_text':
                'Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
          }
        ],
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/bonecrusher.jpg',
        },
        'prices': {
          'usd': '1.25',
          'usd_foil': '3.50',
          'eur': '1.10',
        },
      };

      final companion = mapScryfallCardToCompanion(adventureJson);
      expect(companion.name.value, 'Bonecrusher Giant // Stomp');
      expect(companion.currentMarketPrice.value, 1.25);

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['layout'], 'adventure');
      expect(dynamicData['prices'], isA<Map>());
      expect(dynamicData['prices']['usd'], '1.25');
      expect(dynamicData['prices']['usd_foil'], '3.50');
      expect(dynamicData['oracle_text'], contains('Whenever Bonecrusher Giant becomes the target'));
      expect(dynamicData['oracle_text'], contains('Damage can\'t be prevented'));
      expect(dynamicData['oracle_text'], contains(' // '));
    });

    test('mapScryfallCardToCompanion extracts flavorName correctly for renamed cards', () {
      final ozolithJson = {
        'id': 'ozolith-1',
        'name': 'The Ozolith',
        'flavor_name': 'Adamantium Bonding Tank',
        'layout': 'normal',
        'mana_cost': '{1}',
        'type_line': 'Legendary Artifact',
        'oracle_text': 'Whenever a creature you control leaves the battlefield...',
        'prices': {'usd': '38.50'},
      };

      final companion = mapScryfallCardToCompanion(ozolithJson);
      expect(companion.name.value, 'The Ozolith');
      expect(companion.flavorName.value, 'Adamantium Bonding Tank');
      expect(companion.currentMarketPrice.value, 38.50);

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['flavor_name'], 'Adamantium Bonding Tank');
    });

    test('mapScryfallCardToCompanion extracts prices with fallbacks (usd -> usd_foil -> eur)', () {
      final foilOnlyJson = {
        'id': 'foil-only-card',
        'name': 'Exclusive Promo',
        'prices': {'usd': null, 'usd_foil': '15.99', 'eur': null},
      };
      final companion = mapScryfallCardToCompanion(foilOnlyJson);
      expect(companion.currentMarketPrice.value, 15.99);

      final eurOnlyJson = {
        'id': 'eur-only-card',
        'name': 'European Promo',
        'prices': {'usd': null, 'usd_foil': null, 'eur': '7.45'},
      };
      final eurCompanion = mapScryfallCardToCompanion(eurOnlyJson);
      expect(eurCompanion.currentMarketPrice.value, 7.45);
    });
  });

  group('VaultDao & Database Upsert & Search Tests', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
    });

    tearDown(() async {
      await db.close();
    });

    test('insertDictionaryBatch does not overwrite existing positive market price with 0.0', () async {
      // 1. Initial insert with price 25.0
      await dao.insertDictionaryBatch([
        createCompanion(
          id: 'card-valuable',
          name: 'The Ozolith',
          imageUrl: 'https://cards.scryfall.io/front/ozolith.jpg',
          currentMarketPrice: 25.0,
          dynamicData: jsonEncode({'prices': {'usd': '25.0'}}),
        ),
      ]);

      var item = await dao.getItemById('card-valuable');
      expect(item, isNotNull);
      expect(item!.currentMarketPrice, 25.0);

      // 2. Incoming update from catalog that has price 0.0 (e.g. Scryfall pricing gap)
      await dao.insertDictionaryBatch([
        createCompanion(
          id: 'card-valuable',
          name: 'The Ozolith',
          imageUrl: 'https://cards.scryfall.io/front/ozolith.jpg',
          currentMarketPrice: 0.0, // Zero price
          dynamicData: jsonEncode({'prices': {}}),
        ),
      ]);

      // Verify positive price was preserved!
      item = await dao.getItemById('card-valuable');
      expect(item!.currentMarketPrice, 25.0);
    });

    test('insertDictionaryBatch does not overwrite existing non-empty image with empty string', () async {
      await dao.insertDictionaryBatch([
        createCompanion(
          id: 'card-image',
          name: 'Card With Image',
          imageUrl: 'https://cards.scryfall.io/front/valid.jpg',
          currentMarketPrice: 5.0,
        ),
      ]);

      await dao.insertDictionaryBatch([
        createCompanion(
          id: 'card-image',
          name: 'Card With Image',
          imageUrl: '', // Empty incoming image
          currentMarketPrice: 6.0,
        ),
      ]);

      final item = await dao.getItemById('card-image');
      expect(item!.imageUrl, 'https://cards.scryfall.io/front/valid.jpg');
      expect(item.currentMarketPrice, 6.0);
    });

    test('searchCatalogCards and getItemsByCollection finds card by flavorName or oracle name', () async {
      await dao.insertDictionaryBatch([
        createCompanion(
          id: 'ozolith-bonding-tank',
          name: 'The Ozolith',
          flavorName: 'Adamantium Bonding Tank',
          imageUrl: 'https://cards.scryfall.io/front/ozolith.jpg',
          currentMarketPrice: 45.0,
        ),
      ]);

      // Search by printed flavor name
      final resultsByFlavor = await dao.searchCatalogCards('Adamantium', collectionType: 'mtg');
      expect(resultsByFlavor.length, 1);
      expect(resultsByFlavor.first.name, 'The Ozolith');
      expect(resultsByFlavor.first.flavorName, 'Adamantium Bonding Tank');

      // Search by oracle name
      final resultsByOracle = await dao.searchCatalogCards('Ozolith', collectionType: 'mtg');
      expect(resultsByOracle.length, 1);
      expect(resultsByOracle.first.flavorName, 'Adamantium Bonding Tank');
    });
  });

  group('CardDetailSheet Adventure Card Behavior', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Adventure card has NO flip button, NO face switch button, and displays both spells',
        (WidgetTester tester) async {
      final adventureItem = VaultItem(
        id: 'bonecrusher-1',
        collectionType: 'mtg',
        name: 'Bonecrusher Giant // Stomp',
        setOrSeries: 'Throne of Eldraine',
        imageUrl: 'https://cards.scryfall.io/front/bonecrusher.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'mana_cost': '{2}{R}',
          'oracle_text':
              'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage. // Damage cannot be prevented this turn. Stomp deals 2 damage.',
          'card_faces': [
            {
              'name': 'Bonecrusher Giant',
              'mana_cost': '{2}{R}',
              'type_line': 'Creature — Giant',
              'oracle_text':
                  'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage.',
              'power': '4',
              'toughness': '3',
            },
            {
              'name': 'Stomp',
              'mana_cost': '{1}{R}',
              'type_line': 'Instant — Adventure',
              'oracle_text':
                  'Damage cannot be prevented this turn. Stomp deals 2 damage.',
            }
          ],
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: adventureItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Flip buttons MUST NOT exist for Adventure card
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);

      // 2. Both spells must be rendered inside the Oracle Rules Text section
      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
      expect(find.text('Bonecrusher Giant'), findsWidgets);
      expect(find.text('Stomp'), findsWidgets);
      expect(
        find.textContaining('Whenever Bonecrusher Giant becomes the target'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Damage cannot be prevented this turn'),
        findsOneWidget,
      );
    });
  });

  group('FullScreenCardViewer Adventure Card Behavior', () {
    testWidgets('Adventure card has NO flip ActionChip or flip button in FullScreenCardViewer',
        (WidgetTester tester) async {
      final adventureItem = VaultItem(
        id: 'brazen-borrower-1',
        collectionType: 'mtg',
        name: 'Brazen Borrower // Petty Theft',
        setOrSeries: 'Throne of Eldraine',
        imageUrl: 'https://cards.scryfall.io/front/borrower.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 15.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'adventure',
          'type_line': 'Creature — Faerie Rogue // Instant — Adventure',
          'card_faces': [
            {'name': 'Brazen Borrower'},
            {'name': 'Petty Theft'},
          ],
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(item: adventureItem),
        ),
      );
      await tester.pumpAndSettle();

      // Flip buttons must NOT be present for Adventure cards in full-screen
      expect(find.byKey(const Key('fullscreen_appbar_flip_button')), findsNothing);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);

      // Foil toggle must still be available
      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
    });
  });

  group('VaultItemCard Catalog Pricing & Dual Persona Tests', () {
    late VaultItem catalogCardWithDirectPrice;
    late VaultItem catalogCardWithFallbackPrice;

    setUp(() {
      catalogCardWithDirectPrice = VaultItem(
        id: 'catalog-1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0, // Unowned catalog card
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 2.25,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'mana_cost': '{1}',
          'type_line': 'Artifact',
        }),
      );

      catalogCardWithFallbackPrice = VaultItem(
        id: 'catalog-2',
        collectionType: 'mtg',
        name: 'Mana Crypt',
        setOrSeries: 'Mystery Booster',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0, // Unowned catalog card
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.0, // Stored as 0.0
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'mana_cost': '{0}',
          'type_line': 'Artifact',
          'prices': {'usd': '180.00'}, // Fallback in dynamicData
        }),
      );
    });

    testWidgets('catalog card (quantity: 0) displays market price in Investor mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: catalogCardWithDirectPrice,
              persona: UserPersona.investor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$2.25'), findsWidgets);
      expect(find.text('CATALOG / UNOWNED'), findsOneWidget);
    });

    testWidgets('catalog card (quantity: 0) displays mechanics in Player mode without financial row',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: catalogCardWithDirectPrice,
              persona: UserPersona.player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Player mode, game utility mechanics are shown and financial row is hidden
      expect(find.text('{1}'), findsOneWidget);
      expect(find.text('CATALOG / UNOWNED'), findsNothing);
      expect(find.text('MARKET VALUE'), findsNothing);
    });

    testWidgets('catalog card falls back to dynamicData prices if currentMarketPrice is 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(
              item: catalogCardWithFallbackPrice,
              persona: UserPersona.investor,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Market price resolved from dynamicData prices.usd
      expect(find.text('\$180.00'), findsWidgets);
    });
  });

  group('VaultItemTile Catalog Pricing Fallback Tests', () {
    testWidgets('VaultItemTile resolves price from dynamicData when currentMarketPrice is 0',
        (WidgetTester tester) async {
      final unownedWithFallback = VaultItem(
        id: 'tile-unowned-1',
        collectionType: 'mtg',
        name: 'Force of Will',
        setOrSeries: 'Alliances',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'prices': {'usd': '75.50'},
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 220,
              child: VaultItemTile(item: unownedWithFallback),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$75.50'), findsOneWidget);
    });
  });
}
