import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M1: Scryfall Parser Metadata & Universes Beyond Tests', () {
    test('detects Universes Beyond via promo_types case-insensitively', () {
      final card = {
        'id': 'ub-promo-1',
        'name': 'The One Ring',
        'set': 'ltr',
        'set_name': 'The Lord of the Rings: Tales of Middle-earth',
        'promo_types': ['Universes_Beyond', 'boosterfun'],
        'prices': {'usd': '55.00'},
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['is_universes_beyond'], isTrue);
      expect(dyn['promo_types'], contains('universes_beyond'));
      expect(dyn['set'], 'ltr');
      expect(dyn['set_code'], 'ltr');
      expect(dyn['set_name'], 'The Lord of the Rings: Tales of Middle-earth');
    });

    test('detects Universes Beyond via frame_effects (universesbeyond)', () {
      final card = {
        'id': 'ub-frame-1',
        'name': 'Optimus Prime, Hero',
        'set': 'bot',
        'set_name': 'Transformers',
        'frame_effects': ['UniversesBeyond', 'showcase'],
        'prices': {'usd': '12.00'},
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['is_universes_beyond'], isTrue);
      expect(dyn['frame_effects'], contains('universesbeyond'));
      expect(dyn['set'], 'bot');
      expect(dyn['set_code'], 'bot');
    });

    test('detects Universes Beyond via security_stamp == triangle', () {
      final card = {
        'id': 'ub-stamp-1',
        'name': 'Space Marine',
        'set': '40k',
        'set_name': 'Warhammer 40,000',
        'security_stamp': 'TRIANGLE',
        'prices': {'usd': '4.50'},
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['is_universes_beyond'], isTrue);
      expect(dyn['security_stamp'], 'triangle');
      expect(dyn['set'], '40k');
      expect(dyn['set_code'], '40k');
    });

    test('detects Universes Beyond from card_faces level fallback', () {
      final card = {
        'id': 'ub-face-1',
        'name': 'Megatron, Tyrant // Megatron, Destructive Force',
        'set': 'bot',
        'set_name': 'Transformers',
        'layout': 'transform',
        'card_faces': [
          {
            'name': 'Megatron, Tyrant',
            'promo_types': ['universes_beyond'],
            'oracle_text': 'Convert Megatron.',
            'image_uris': {'normal': 'https://cards.scryfall.io/front/megatron.jpg'},
          },
          {
            'name': 'Megatron, Destructive Force',
            'oracle_text': 'Whenever Megatron attacks...',
            'image_uris': {'normal': 'https://cards.scryfall.io/back/megatron.jpg'},
          },
        ],
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['is_universes_beyond'], isTrue);
      expect(dyn['promo_types'], contains('universes_beyond'));
      expect(dyn['oracle_text'], 'Convert Megatron. // Whenever Megatron attacks...');
      expect(dyn['back_image_url'], 'https://cards.scryfall.io/back/megatron.jpg');
    });

    test('standard in-universe cards have is_universes_beyond == false', () {
      final card = {
        'id': 'standard-card-1',
        'name': 'Lightning Bolt',
        'set': 'lea',
        'set_name': 'Limited Edition Alpha',
        'security_stamp': 'oval',
        'promo_types': ['reprint'],
        'frame_effects': ['legendary'],
        'prices': {'usd': '400.00'},
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['is_universes_beyond'], isFalse);
      expect(dyn['security_stamp'], 'oval');
      expect(dyn['promo_types'], contains('reprint'));
      expect(dyn['frame_effects'], contains('legendary'));
      expect(dyn['set'], 'lea');
      expect(dyn['set_code'], 'lea');
    });

    test('preserves Secret Lair set code sld in lowercase', () {
      final card = {
        'id': 'sld-card-1',
        'name': 'The Ozolith',
        'flavor_name': 'Adamantium Bonding Tank',
        'set': 'SLD',
        'set_name': 'Secret Lair Drop',
        'security_stamp': 'triangle',
        'promo_types': ['universes_beyond'],
        'prices': {'usd': '35.00'},
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(comp.flavorName.value, 'Adamantium Bonding Tank');
      expect(dyn['flavor_name'], 'Adamantium Bonding Tank');
      expect(dyn['set'], 'sld');
      expect(dyn['set_code'], 'sld');
      expect(dyn['set_name'], 'Secret Lair Drop');
      expect(dyn['is_universes_beyond'], isTrue);
    });

    test('preserves multi-face oracle text, images, and flavor names', () {
      final card = {
        'id': 'mdfc-card-1',
        'name': 'Barkchannel Pathway // Tidechannel Pathway',
        'layout': 'modal_dfc',
        'set': 'khm',
        'set_name': 'Kaldheim',
        'card_faces': [
          {
            'name': 'Barkchannel Pathway',
            'type_line': 'Land',
            'oracle_text': '{T}: Add {G}.',
            'flavor_name': 'Front Flavor',
            'image_uris': {'normal': 'https://cards.scryfall.io/front/bark.jpg'},
          },
          {
            'name': 'Tidechannel Pathway',
            'type_line': 'Land',
            'oracle_text': '{T}: Add {U}.',
            'flavor_name': 'Back Flavor',
            'image_uris': {'normal': 'https://cards.scryfall.io/back/tide.jpg'},
          },
        ],
      };

      final comp = mapScryfallCardToCompanion(card);
      final dyn = jsonDecode(comp.dynamicData.value) as Map<String, dynamic>;

      expect(dyn['oracle_text'], '{T}: Add {G}. // {T}: Add {U}.');
      expect(dyn['card_faces'], hasLength(2));
      expect(dyn['back_image_url'], 'https://cards.scryfall.io/back/tide.jpg');
      expect(comp.flavorName.value, 'Front Flavor // Back Flavor');
    });
  });

  group('M1: Adventure vs DFC Layout & Flip Suppression Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createSheetApp(VaultItem item) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
        child: MaterialApp(home: Scaffold(body: CardDetailSheet(item: item))),
      );
    }

    testWidgets('Transform DFC card displays flip button and face switcher in CardDetailSheet',
        (WidgetTester tester) async {
      final transformCard = VaultItem(
        id: 'delver-dfc',
        collectionType: 'mtg',
        name: 'Delver of Secrets // Insectile Aberration',
        setOrSeries: 'Innistrad',
        imageUrl: 'https://cards.scryfall.io/front/delver.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
              'type_line': 'Creature — Human Wizard',
              'oracle_text': 'At the beginning of your upkeep, look at top card...',
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
              'type_line': 'Creature — Human Insect',
              'oracle_text': 'Flying',
            },
          ],
        }),
      );

      await tester.pumpWidget(createSheetApp(transformCard));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsOneWidget);

      // Tap flip button
      await tester.tap(find.byKey(const Key('card_detail_flip_button')));
      await tester.pumpAndSettle();
      expect(find.text('View Face 1'), findsOneWidget);
    });

    testWidgets('Modal DFC (modal_dfc) retains flip button and face switcher',
        (WidgetTester tester) async {
      final mdfcCard = VaultItem(
        id: 'pathway-mdfc',
        collectionType: 'mtg',
        name: 'Barkchannel Pathway // Tidechannel Pathway',
        setOrSeries: 'Kaldheim',
        imageUrl: 'https://cards.scryfall.io/front/pathway.jpg',
        acquiredPrice: 5.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 8.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'modal_dfc',
          'card_faces': [
            {
              'name': 'Barkchannel Pathway',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/pathway.jpg'},
              'type_line': 'Land',
              'oracle_text': '{T}: Add {G}.',
            },
            {
              'name': 'Tidechannel Pathway',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/pathway.jpg'},
              'type_line': 'Land',
              'oracle_text': '{T}: Add {U}.',
            },
          ],
        }),
      );

      await tester.pumpWidget(createSheetApp(mdfcCard));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsOneWidget);
    });

    testWidgets('Reversible card (reversible_card) displays flip buttons in FullScreenCardViewer',
        (WidgetTester tester) async {
      final reversibleCard = VaultItem(
        id: 'propaganda-reversible',
        collectionType: 'mtg',
        name: 'Propaganda // Propaganda',
        setOrSeries: 'SLD',
        imageUrl: 'https://cards.scryfall.io/front/prop1.jpg',
        acquiredPrice: 20.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 25.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'reversible_card',
          'card_faces': [
            {
              'name': 'Propaganda (Art 1)',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/prop1.jpg'},
            },
            {
              'name': 'Propaganda (Art 2)',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/prop2.jpg'},
            },
          ],
        }),
      );

      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: reversibleCard)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_appbar_flip_button')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);
    });

    testWidgets('Adventure card strictly disables 3D flip controls and renders unified rules box',
        (WidgetTester tester) async {
      final adventureCard = VaultItem(
        id: 'bonecrusher-m1',
        collectionType: 'mtg',
        name: 'Bonecrusher Giant // Stomp',
        setOrSeries: 'Throne of Eldraine',
        imageUrl: 'https://cards.scryfall.io/front/bonecrusher.jpg',
        acquiredPrice: 1.5,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 2.5,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'mana_cost': '{2}{R}',
          'oracle_text': 'Permanent rules // Adventure rules',
          'card_faces': [
            {
              'name': 'Bonecrusher Giant',
              'mana_cost': '{2}{R}',
              'type_line': 'Creature — Giant',
              'oracle_text': 'Whenever Bonecrusher Giant becomes target...',
              'power': '4',
              'toughness': '3',
            },
            {
              'name': 'Stomp',
              'mana_cost': '{1}{R}',
              'type_line': 'Instant — Adventure',
              'oracle_text': 'Damage cannot be prevented this turn.',
            },
          ],
        }),
      );

      // Verify CardDetailSheet flip buttons are strictly suppressed
      await tester.pumpWidget(createSheetApp(adventureCard));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsNothing);

      // Verify unified rules box renders permanent and adventure spell text with divider banner
      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
      expect(find.text('Bonecrusher Giant'), findsWidgets);
      expect(find.text('Stomp'), findsWidgets);
      expect(find.text('Whenever Bonecrusher Giant becomes target...'), findsOneWidget);
      expect(find.text('Damage cannot be prevented this turn.'), findsOneWidget);

      // Verify FullScreenCardViewer flip buttons are strictly suppressed
      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: adventureCard)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_appbar_flip_button')), findsNothing);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
      // Verify subtitle does NOT say "Face 1 of 2"
      expect(find.textContaining('Face 1 of 2'), findsNothing);
    });
  });

  group('M1: VaultDao Secret Lair & Flavor Name Search Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.ensureSecretLairIndexes();

      // Seed Secret Lair Drop card with flavor name
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ozolith-sld',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://cards.scryfall.io/large/front/ozolith.jpg',
          acquiredPrice: 25.00,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 35.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'sld',
            'set_code': 'sld',
            'set_name': 'Secret Lair Drop',
            'is_universes_beyond': true,
            'promo_types': ['universes_beyond'],
            'flavor_name': 'Adamantium Bonding Tank',
          }),
        ),
      );

      // Seed non-Secret Lair card
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-lotus-alpha',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Limited Edition Alpha',
          imageUrl: 'https://cards.scryfall.io/large/front/lotus.jpg',
          acquiredPrice: 5000.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 10000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'lea',
            'set_code': 'lea',
            'set_name': 'Limited Edition Alpha',
            'is_universes_beyond': false,
          }),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('searches Secret Lairs case-insensitively across sld, SLD, Secret Lair, and full name', () async {
      // 1. Lowercase 'sld'
      final resSld = await db.vaultDao.searchCatalogCards('sld');
      expect(resSld.any((c) => c.id == 'card-ozolith-sld'), isTrue);
      expect(resSld.any((c) => c.id == 'card-lotus-alpha'), isFalse);

      // 2. Uppercase 'SLD'
      final resSldUpper = await db.vaultDao.searchCatalogCards('SLD');
      expect(resSldUpper.any((c) => c.id == 'card-ozolith-sld'), isTrue);

      // 3. 'Secret Lair'
      final resSecretLair = await db.vaultDao.searchCatalogCards('Secret Lair');
      expect(resSecretLair.any((c) => c.id == 'card-ozolith-sld'), isTrue);

      // 4. 'SECRET LAIR DROP'
      final resFullUpper = await db.vaultDao.searchCatalogCards('SECRET LAIR DROP');
      expect(resFullUpper.any((c) => c.id == 'card-ozolith-sld'), isTrue);

      // 5. getItemsByCollection with searchQuery 'sld'
      final itemsQuery = await db.vaultDao.getItemsByCollection('mtg', searchQuery: 'sld');
      expect(itemsQuery.any((c) => c.id == 'card-ozolith-sld'), isTrue);

      // 6. watchItemsByCollection stream with searchQuery 'SLD'
      final streamQuery = await db.vaultDao.watchItemsByCollection('mtg', searchQuery: 'SLD').first;
      expect(streamQuery.any((c) => c.id == 'card-ozolith-sld'), isTrue);

      // 7. Dedicated watchSecretLairItems stream
      final sldStream = await db.vaultDao.watchSecretLairItems().first;
      expect(sldStream.length, 1);
      expect(sldStream.first.id, 'card-ozolith-sld');

      // 8. Dedicated getSecretLairItems
      final sldGet = await db.vaultDao.getSecretLairItems();
      expect(sldGet.length, 1);
      expect(sldGet.first.id, 'card-ozolith-sld');
    });

    test('searches flavor_name case-insensitively returning oracle card', () async {
      // 1. Full flavor name
      final fullFlavor = await db.vaultDao.searchCatalogCards('Adamantium Bonding Tank');
      expect(fullFlavor.length, 1);
      expect(fullFlavor.first.name, 'The Ozolith');

      // 2. Substring lowercase 'adamantium'
      final subLower = await db.vaultDao.searchCatalogCards('adamantium');
      expect(subLower.length, 1);
      expect(subLower.first.name, 'The Ozolith');

      // 3. Substring uppercase 'BONDING'
      final subUpper = await db.vaultDao.searchCatalogCards('BONDING');
      expect(subUpper.length, 1);
      expect(subUpper.first.name, 'The Ozolith');

      // 4. Substring 'tank'
      final subTank = await db.vaultDao.searchCatalogCards('tank');
      expect(subTank.length, 1);
      expect(subTank.first.name, 'The Ozolith');

      // 5. Oracle name 'The Ozolith'
      final oracleName = await db.vaultDao.searchCatalogCards('The Ozolith');
      expect(oracleName.length, 1);
      expect(oracleName.first.name, 'The Ozolith');
    });

    test('queries Universes Beyond cards via watchUniversesBeyondItems and getUniversesBeyondItems', () async {
      final ubCards = await db.vaultDao.getUniversesBeyondItems(collectionType: 'mtg');
      expect(ubCards.length, 1);
      expect(ubCards.first.id, 'card-ozolith-sld');

      final ubStream = await db.vaultDao.watchUniversesBeyondItems().first;
      expect(ubStream.length, 1);
      expect(ubStream.first.id, 'card-ozolith-sld');
    });

    test('queries cards by setIdentifier via getItemsBySet', () async {
      final sldCards = await db.vaultDao.getItemsBySet(setIdentifier: 'sld');
      expect(sldCards.length, 1);
      expect(sldCards.first.id, 'card-ozolith-sld');

      final leaCards = await db.vaultDao.getItemsBySet(setIdentifier: 'lea');
      expect(leaCards.length, 1);
      expect(leaCards.first.id, 'card-lotus-alpha');
    });
  });
}
