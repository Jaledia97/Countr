import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardAvailability Model Tests', () {
    test('CardAvailability satisfies Owned = Available + In Deck invariant', () {
      const avail = CardAvailability(owned: 4, available: 3, inDeck: 1);
      expect(avail.owned, equals(avail.available + avail.inDeck));
      expect(avail.owned, equals(4));
      expect(avail.available, equals(3));
      expect(avail.inDeck, equals(1));
    });

    test('CardAvailability zero constant', () {
      expect(CardAvailability.zero.owned, equals(0));
      expect(CardAvailability.zero.available, equals(0));
      expect(CardAvailability.zero.inDeck, equals(0));
    });

    test('CardAvailability copyWith, equality, hashCode, and toString', () {
      const a1 = CardAvailability(owned: 4, available: 3, inDeck: 1);
      final a2 = a1.copyWith(available: 2, inDeck: 2);
      expect(a2.owned, equals(4));
      expect(a2.available, equals(2));
      expect(a2.inDeck, equals(2));

      const a3 = CardAvailability(owned: 4, available: 3, inDeck: 1);
      expect(a1, equals(a3));
      expect(a1.hashCode, equals(a3.hashCode));
      expect(a1.toString(), contains('Owned: 4, Available: 3, InDeck: 1'));
    });
  });

  group('Availability Engine Database Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Unassigned vault cards have 100% availability and 0 in deck', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      expect(map.containsKey('card-sol-ring'), isTrue);
      final avail = map['card-sol-ring']!;
      expect(avail.owned, equals(4));
      expect(avail.available, equals(4));
      expect(avail.inDeck, equals(0));
    });

    test('Draft deck does NOT deduct from availability or show active badges', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create a draft deck (isAssembled: false, isRegistered: false)
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-draft',
          name: 'Draft Commander',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(false),
          isRegistered: const Value(false),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-draft',
          deckId: 'deck-draft',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      // Allocate 2 copies in the draft deck
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-1',
          versionId: 'version-draft',
          vaultItemId: 'card-sol-ring',
          boardZone: 'Mainboard',
          quantity: const Value(2),
          isProxy: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map['card-sol-ring']!;
      // Because deck is draft, inDeck remains 0 and available remains 4!
      expect(avail.owned, equals(4));
      expect(avail.available, equals(4));
      expect(avail.inDeck, equals(0));

      // Active badges query gate
      final activeDecks = await db.vaultDao.watchCardActiveDecks('card-sol-ring').first;
      expect(activeDecks.isEmpty, isTrue);
    });

    test('Assembled deck deducts from available inventory and displays active deck badge', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create an assembled deck (isAssembled: true)
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-assembled',
          name: 'Assembled EDH',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(false),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-assembled',
          deckId: 'deck-assembled',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      // Allocate 1 copy
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-assembled',
          versionId: 'version-assembled',
          vaultItemId: 'card-sol-ring',
          boardZone: 'Mainboard',
          quantity: const Value(1),
          isProxy: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map['card-sol-ring']!;
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(1));
      expect(avail.available, equals(3));

      // Active badges query gate includes the assembled deck
      final activeDecks = await db.vaultDao.watchCardActiveDecks('card-sol-ring').first;
      expect(activeDecks, contains('Assembled EDH'));
    });

    test('Proxy items in assembled deck do NOT decrement available inventory', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(2),
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-proxy-test',
          name: 'Proxy Deck',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(true),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-proxy-test',
          deckId: 'deck-proxy-test',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      // Allocate 2 copies, but marked as PROXY
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-proxy-1',
          versionId: 'version-proxy-test',
          vaultItemId: 'card-sol-ring',
          boardZone: 'Mainboard',
          quantity: const Value(2),
          isProxy: const Value(true),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map['card-sol-ring']!;
      // Proxy cards do not deduct from physical availability!
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(2));
    });

    test('Over-allocation clamps available inventory at 0 and never goes negative', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C21',
          imageUrl: '',
          quantity: const Value(1), // only 1 owned
          condition: 'Near Mint',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-over-allocated',
          name: 'Deck Over',
          format: 'Commander',
          createdAt: now,
          isAssembled: const Value(true),
          isRegistered: const Value(true),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-over',
          deckId: 'deck-over-allocated',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      // Allocate 3 copies into assembled deck
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-over',
          versionId: 'version-over',
          vaultItemId: 'card-sol-ring',
          boardZone: 'Mainboard',
          quantity: const Value(3),
          isProxy: const Value(false),
        ),
      );

      final map = await db.vaultDao.watchAllCardAvailability().first;
      final avail = map['card-sol-ring']!;
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(3));
      // Clamped at 0
      expect(avail.available, equals(0));
    });

    test('Toggling deck assembly updates availability dynamically', () async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-bolt',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'M11',
          imageUrl: '',
          quantity: const Value(4),
          condition: 'Near Mint',
          acquiredPrice: 1.5,
          acquiredDate: now,
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-toggle',
          name: 'Burn Deck',
          format: 'Modern',
          createdAt: now,
          isAssembled: const Value(false),
          isRegistered: const Value(false),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'version-toggle',
          deckId: 'deck-toggle',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-toggle',
          versionId: 'version-toggle',
          vaultItemId: 'card-bolt',
          boardZone: 'Mainboard',
          quantity: const Value(4),
          isProxy: const Value(false),
        ),
      );

      // Initially disassembled: Available = 4, InDeck = 0
      var map = await db.vaultDao.watchAllCardAvailability().first;
      expect(map['card-bolt']!.available, equals(4));
      expect(map['card-bolt']!.inDeck, equals(0));

      // Toggle assembly ON
      await db.vaultDao.setDeckAssembled('deck-toggle', true);
      map = await db.vaultDao.watchAllCardAvailability().first;
      expect(map['card-bolt']!.available, equals(0));
      expect(map['card-bolt']!.inDeck, equals(4));

      // Toggle assembly OFF
      await db.vaultDao.setDeckAssembled('deck-toggle', false);
      map = await db.vaultDao.watchAllCardAvailability().first;
      expect(map['card-bolt']!.available, equals(4));
      expect(map['card-bolt']!.inDeck, equals(0));
    });
  });

  group('Presentation Availability Breakdown Widget Tests', () {
    VaultItem createSampleItem({required String id, required int quantity}) {
      final now = DateTime.now();
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: 'The One Ring',
        setOrSeries: 'LTR',
        imageUrl: '',
        acquiredPrice: 50.0,
        acquiredDate: now,
        quantity: quantity,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 50.0,
        lastPriceUpdate: now,
        dynamicData: jsonEncode({
          'scryfall_id': 'd5806e68-1054-458e-866d-1f2470f682b2',
          'finish': 'foil',
        }),
        isDeleted: false,
      );
    }

    testWidgets('VaultItemTile renders Owned, Available, and In Deck breakdown with ProviderScope', (tester) async {
      final item = createSampleItem(id: 'item-ring-tile', quantity: 4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.value({
                'item-ring-tile': const CardAvailability(owned: 4, available: 3, inDeck: 1),
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemTile(
                item: item,
                hasMultipleVariants: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_availability_${item.id}')), findsOneWidget);
      expect(find.text('Owned: 4'), findsOneWidget);
      expect(find.text('Available: 3'), findsOneWidget);
      expect(find.text('In Deck: 1'), findsOneWidget);
    });

    testWidgets('VaultItemCard renders Owned, Available, and In Deck breakdown with ProviderScope', (tester) async {
      final item = createSampleItem(id: 'item-ring-card', quantity: 4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardAvailabilityProvider.overrideWith(
              (ref) => Stream.value({
                'item-ring-card': const CardAvailability(owned: 4, available: 2, inDeck: 2),
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 350,
                child: VaultItemCard(
                  item: item,
                  hasMultipleVariants: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_item_availability_${item.id}')), findsOneWidget);
      expect(find.text('Owned: 4'), findsOneWidget);
      expect(find.text('Available: 2'), findsOneWidget);
      expect(find.text('In Deck: 2'), findsOneWidget);
    });
  });
}
