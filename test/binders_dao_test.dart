import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
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

  group('VaultDao - Binders & Scanner Integration', () {
    test('creates and retrieves custom binders by collection', () async {
      final mtgBinder = await dao.createBinder(
        name: 'Modern Horizons 3 Foils',
        collectionType: 'Magic: The Gathering',
      );
      final pkmBinder = await dao.createBinder(
        name: '151 Master Set',
        collectionType: 'Pokémon TCG',
      );

      expect(mtgBinder.name, equals('Modern Horizons 3 Foils'));
      expect(mtgBinder.collectionType, equals('mtg'));
      expect(pkmBinder.name, equals('151 Master Set'));
      expect(pkmBinder.collectionType, equals('pokemon'));

      // Stream MTG binders
      final mtgBinders = await dao.watchBindersByCollection('mtg').first;
      expect(mtgBinders.length, equals(1));
      expect(mtgBinders.first.name, equals('Modern Horizons 3 Foils'));

      // Stream Pokémon binders
      final pkmBinders = await dao.watchBindersByCollection('pokemon').first;
      expect(pkmBinders.length, equals(1));
      expect(pkmBinders.first.name, equals('151 Master Set'));

      // Stream All binders
      final allBinders = await dao.watchBindersByCollection('all').first;
      expect(allBinders.length, equals(2));
    });

    test('upserts scanned cards into Inbox with correct initial values and foil tagging', () async {
      final card = VaultItem(
        id: 'card-lotus-001',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Vintage Masters',
        imageUrl:
            'https://cards.scryfall.io/large/front/b/c/bc86719f-0dd9-4a1c-b636-f361094aa6fe.jpg',
        acquiredPrice: 5000.0,
        acquiredDate: DateTime.now(),
        quantity: 0, // unowned catalog record initially
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 5500.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"collector_number":"232"}',
        primaryBinderId: null,
      );

      // Scanned as standard card
      await dao.upsertScannedCardToInbox(card, isFoil: false);

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
      expect(inbox.first.name, equals('Black Lotus'));
      expect(inbox.first.quantity, equals(1));
      expect(inbox.first.condition, equals('NM'));
      expect(inbox.first.primaryBinderId, equals('INBOX'));

      // Scan second copy as Foil
      await dao.upsertScannedCardToInbox(card, isFoil: true);

      inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
      expect(inbox.first.quantity, equals(2));
      expect(inbox.first.condition, equals('NM (Foil)'));
    });

    test('matches scanned cards by exact name and candidate substring with collector number', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-sol-ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander Masters',
              imageUrl: 'https://example.com/solring.jpg',
              acquiredPrice: 1.5,
              acquiredDate: DateTime.now(),
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              condition: 'NM',
              dynamicData: '{"collector_number":"400"}',
            ),
          );

      // Match exact name
      final matchExact = await dao.matchScannedCard(
        ['Sol Ring'],
        'mtg',
      );
      expect(matchExact, isNotNull);
      expect(matchExact!.id, equals('card-sol-ring'));

      // Match with collector number
      final matchSub = await dao.matchScannedCard(
        ['random text'],
        'mtg',
        collectorNumber: '400',
      );
      expect(matchSub, isNotNull);
      expect(matchSub!.id, equals('card-sol-ring'));
    });

    test('bulk transfers items from Inbox to destination binder and tracks physical anchor', () async {
      // 1. Create binder
      final binder = await dao.createBinder(
        name: 'Commander Staples',
        collectionType: 'mtg',
      );

      // 2. Insert 2 inbox items
      final card1 = VaultItem(
        id: 'c1',
        collectionType: 'mtg',
        name: 'Card One',
        setOrSeries: 'Set 1',
        imageUrl: 'https://example.com/c1.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime.now(),
        quantity: 2,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 12.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );
      final card2 = VaultItem(
        id: 'c2',
        collectionType: 'mtg',
        name: 'Card Two',
        setOrSeries: 'Set 1',
        imageUrl: 'https://example.com/c2.jpg',
        acquiredPrice: 5.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 6.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      await dao.upsertScannedCardToInbox(card1);
      await dao.upsertScannedCardToInbox(card1); // Second scan increments to 2
      await dao.upsertScannedCardToInbox(card2); // 1 copy

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(2));

      // Initial binder item counts
      var counts = await dao.watchBinderItemCounts().first;
      expect(counts[binder.id] ?? 0, equals(0));

      // 3. Move items to binder
      final movedCount = await dao.assignItemsToBinder(['c1', 'c2'], binder.id);
      expect(movedCount, equals(2));

      // Inbox is now empty
      inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);

      // Binder item counts reflect 2 + 1 = 3 cards total
      counts = await dao.watchBinderItemCounts().first;
      expect(counts[binder.id], equals(3));

      // Physical anchor query: watchItemsByBinder returns all anchored cards
      final binderCards = await dao.watchItemsByBinder(binder.id).first;
      expect(binderCards.length, equals(2));
      expect(binderCards.map((c) => c.id).toSet(), equals({'c1', 'c2'}));
      expect(binderCards.every((c) => c.primaryBinderId == binder.id), isTrue);
    });
  });
}
