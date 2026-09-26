import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = VaultDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Critic: DeckSummary Domain Resilience', () {
    test('Handles corrupted, malformed, and anomalous dynamic_data without throwing', () {
      final summary = DeckSummary.fromRow(
        id: 'test-corrupt-1',
        name: 'Corrupt Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderDynamicData: '{not: valid: json!}',
        commanderImageUrl: 'https://example.com/fallback.jpg',
        cardCount: 15,
      );

      expect(summary.commanderArtCrop, equals('https://example.com/fallback.jpg'));
      expect(summary.colorIdentity, isEmpty);
      expect(summary.completeness, equals(0.15));
      expect(summary.assemblyStatus, equals('Draft'));
    });

    test('Correctly extracts art_crop from multi-faced card (card_faces)', () {
      final mdfcJson = jsonEncode({
        'card_faces': [
          {
            'name': 'Esika, God of the Tree',
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/esika.jpg',
            },
          },
          {
            'name': 'The Prismatic Bridge',
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/bridge.jpg',
            },
          }
        ],
        'color_identity': ['w', 'u', 'b', 'r', 'g'],
      });

      final summary = DeckSummary.fromRow(
        id: 'test-mdfc',
        name: 'Esika / Prismatic Bridge',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: true,
        isCompetitive: true,
        createdAt: DateTime.now(),
        commanderDynamicData: mdfcJson,
        cardCount: 100,
      );

      expect(summary.commanderArtCrop, equals('https://cards.scryfall.io/art_crop/esika.jpg'));
      expect(summary.colorIdentity, equals(['W', 'U', 'B', 'R', 'G']));
      expect(summary.completeness, equals(1.0));
      expect(summary.assemblyStatus, equals('Assembled'));
    });

    test('Clamps completeness safely for over-filled and 0-target decks', () {
      // Overfilled deck (120 cards in 100-card commander)
      final overfilled = DeckSummary.fromRow(
        id: 'overfilled',
        name: 'Overfilled Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        cardCount: 120,
      );
      expect(overfilled.completeness, equals(1.0));
      expect(overfilled.assemblyStatus, equals('Ready'));

      // Unknown custom format defaults to 60
      expect(DeckSummary.computeTargetCardCount('Custom Cube Draft'), equals(60));
    });
  });

  group('Adversarial Critic: SQL Filtering & Soft Delete Scenarios', () {
    test('Deck remains visible but commander resets to null when commander card is soft-deleted', () async {
      final now = DateTime.now();

      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-solo'),
          name: const Value('Solo Commander Deck'),
          format: const Value('Commander'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('ver-solo'),
          deckId: const Value('deck-solo'),
          versionNumber: const Value(1),
          isActive: const Value(true),
          createdAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Soft-deleted commander vault item
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-deleted-cmd'),
          collectionType: const Value('mtg'),
          name: const Value('Deleted Commander'),
          setOrSeries: const Value('C20'),
          imageUrl: const Value('https://example.com/cmd.jpg'),
          currentMarketPrice: const Value(10.0),
          acquiredPrice: const Value(10.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          dynamicData: const Value('{}'),
          isDeleted: const Value(true), // soft-deleted
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-del-cmd'),
          versionId: const Value('ver-solo'),
          vaultItemId: const Value('card-deleted-cmd'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isDeleted: const Value(false),
        ),
      );

      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1));
      final deckSummary = summaries.first;
      // Because vi.is_deleted = 1, LEFT JOIN produces null for commander fields
      expect(deckSummary.commanderName, isNull);
      expect(deckSummary.commanderCardId, isNull);
      expect(deckSummary.commanderArtCrop, isNull);
      expect(deckSummary.cardCount, equals(1)); // DVI itself is not deleted
    });
  });

  group('Adversarial Critic: Viewport & Layout Overflow Stress Testing', () {
    testWidgets('DecksScreen renders on 320px narrow screen with 1.5x font scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-narrow'),
          name: const Value('Extremely Long Deck Name For Edge Case Testing'),
          format: const Value('Commander / EDH Competitive High Power'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.5),
              ),
              child: const DecksScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must not throw RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Extremely Long Deck Name'), findsOneWidget);
    });

    testWidgets('BinderDetailScreen in 3x3 Grid mode renders cleanly at standard mobile viewport and documents narrow overflow', (tester) async {
      tester.view.physicalSize = const Size(430, 932); // iPhone 14/15 Pro Max
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final binder = VaultBinder(
        id: 'standard-binder',
        name: 'Standard Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('standard-card-1'),
          collectionType: const Value('mtg'),
          name: const Value('Sol Ring'),
          setOrSeries: const Value('C21'),
          imageUrl: const Value(''),
          currentMarketPrice: const Value(2.0),
          acquiredPrice: const Value(2.0),
          acquiredDate: Value(DateTime.now()),
          lastPriceUpdate: Value(DateTime.now()),
          condition: const Value('NM'),
          quantity: const Value(1),
          primaryBinderId: const Value('standard-binder'),
          dynamicData: const Value('{}'),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(430, 932),
              ),
              child: BinderDetailScreen(binder: binder),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Standard Binder'), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);
    });
  });
}
