// Copyright (c) 2026 Countr. All rights reserved.
// Forensic Auditor empirical adversarial stress test for Stage 2C.

import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/deck_io_parser.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = VaultDao(db);
    await db.delete(db.deckVersionItems).go();
    await db.delete(db.deckVersions).go();
    await db.delete(db.decks).go();
    await db.delete(db.vaultItems).go();
  });

  tearDown(() async {
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

  group('Forensic Stress Test: VaultDao watchDeckSummaries SQLite Edge Cases', () {
    test('STRESS 1.1: Empty deck without versions or cards returns valid DeckSummary with 0 count and null Commander', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-empty'),
          name: const Value('Empty Deck'),
          format: const Value('Modern'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1));
      final s = summaries.first;
      expect(s.cardCount, equals(0));
      expect(s.commanderCardId, isNull);
      expect(s.commanderArtCrop, isNull);
      expect(s.completeness, equals(0.0));
      expect(s.assemblyStatus, equals('Draft'));
    });

    test('STRESS 1.2: Deck with soft-deleted items excludes them from card count and Commander resolution', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-soft-del'),
          name: const Value('Soft Delete Stress Deck'),
          format: const Value('Commander'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const Value('ver-soft-del'),
          deckId: const Value('deck-soft-del'),
          versionNumber: const Value(1),
          isActive: const Value(true),
          createdAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Card 1: Soft-deleted Commander
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-cmd-del'),
          collectionType: const Value('mtg'),
          name: const Value('Deleted Commander'),
          setOrSeries: const Value('C20'),
          imageUrl: const Value(''),
          currentMarketPrice: const Value(1.0),
          acquiredPrice: const Value(1.0),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(1),
          isDeleted: const Value(false),
          dynamicData: const Value('{"color_identity":["B"]}'),
        ),
      );

      // Mark the version item as soft-deleted
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-cmd-del'),
          versionId: const Value('ver-soft-del'),
          vaultItemId: const Value('card-cmd-del'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isDeleted: const Value(true), // SOFT DELETED
        ),
      );

      // Card 2: Active Mainboard card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion(
          id: const Value('card-active-main'),
          collectionType: const Value('mtg'),
          name: const Value('Swamp'),
          setOrSeries: const Value('C20'),
          imageUrl: const Value(''),
          currentMarketPrice: const Value(0.1),
          acquiredPrice: const Value(0.1),
          acquiredDate: Value(now),
          lastPriceUpdate: Value(now),
          condition: const Value('NM'),
          quantity: const Value(4),
          isDeleted: const Value(false),
          dynamicData: const Value('{}'),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion(
          id: const Value('dvi-active-main'),
          versionId: const Value('ver-soft-del'),
          vaultItemId: const Value('card-active-main'),
          quantity: const Value(4),
          boardZone: const Value('Mainboard'),
          isDeleted: const Value(false), // ACTIVE
        ),
      );

      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1));
      final s = summaries.first;
      // Deleted commander is NOT resolved as commander
      expect(s.commanderCardId, isNull);
      // Total card count excludes soft-deleted DVI (only Swamp x4 = 4)
      expect(s.cardCount, equals(4));
    });

    test('STRESS 1.3: DFC card_faces art_crop extraction and malformed JSON resilience', () {
      // 1. DFC with card_faces
      final dfcSummary = DeckSummary.fromRow(
        id: 'dfc-deck',
        name: 'Nicol Bolas Reanimator',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderDynamicData: jsonEncode({
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/bolas_front.jpg',
              }
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/bolas_back.jpg',
              }
            }
          ],
          'color_identity': ['u', 'b', 'r'],
        }),
        cardCount: 100,
      );

      expect(dfcSummary.commanderArtCrop, equals('https://cards.scryfall.io/art_crop/bolas_front.jpg'));
      expect(dfcSummary.colorIdentity, equals(['U', 'B', 'R']));
      expect(dfcSummary.completeness, equals(1.0));
      expect(dfcSummary.assemblyStatus, equals('Ready'));

      // 2. Corrupt / Malformed JSON should not throw
      final malformedSummary = DeckSummary.fromRow(
        id: 'corrupt-deck',
        name: 'Broken Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderImageUrl: 'https://fallback.jpg',
        commanderDynamicData: '{corrupted_json:::invalid',
        cardCount: 0,
      );

      expect(malformedSummary.commanderArtCrop, equals('https://fallback.jpg'));
      expect(malformedSummary.colorIdentity, isEmpty);
      expect(malformedSummary.completeness, equals(0.0));
      expect(malformedSummary.assemblyStatus, equals('Draft'));
    });
  });

  group('Forensic Stress Test: DeckIOParser & Fallback Parser Robustness', () {
    test('STRESS 2.1: DeckIOParser parses standard lines with set codes and collector numbers', () {
      const standardInput = '''
// Commander
1 Edgar Markov

# Mana Base
36 Swamp
1 Command Tower
  2   Dark Ritual   (C17) 33
''';
      final parsed = DeckIOParser.parseList(standardInput);
      expect(parsed.length, equals(4));

      expect(parsed[0].quantity, equals(1));
      expect(parsed[0].name, equals('Edgar Markov'));

      expect(parsed[1].quantity, equals(36));
      expect(parsed[1].name, equals('Swamp'));

      expect(parsed[2].quantity, equals(1));
      expect(parsed[2].name, equals('Command Tower'));

      expect(parsed[3].quantity, equals(2));
      expect(parsed[3].name, equals('Dark Ritual'));
      expect(parsed[3].setCode, equals('C17'));
      expect(parsed[3].collectorNumber, equals('33'));
    });
  });

  group('Forensic Stress Test: Compact Screen & Extreme Font Scale Rendering', () {
    testWidgets('STRESS 3.1: DecksScreen does not overflow on 320x568 at 2.0x textScaleFactor', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed a deck with a very long title
      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion(
          id: const Value('deck-long-title'),
          name: const Value('Extremely Super Long Deck Title That Could Trigger Overflow in Smaller Constraints'),
          format: const Value('MTG Commander'),
          createdAt: Value(now),
          tcgDomain: const Value('mtg'),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          child: const DecksScreen(),
          size: const Size(320, 568),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('STRESS 3.2: VaultImportBottomSheet with empty input prevents submission', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VaultImportBottomSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Submit with empty text
      await tester.tap(find.byKey(const Key('vault_import_submit_button')));
      await tester.pumpAndSettle();

      // Verify validation message
      expect(find.text('Please enter at least one valid card or URL.'), findsOneWidget);
    });

    testWidgets('STRESS 3.3: EditBinderModal with empty name rejects save and shows SnackBar', (tester) async {
      final binder = VaultBinder(
        id: 'binder-empty-test',
        name: 'Valid Name',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
        isDeleted: false,
      );
      await db.into(db.vaultBinders).insert(binder);

      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EditBinderModal.show(context, binder),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Clear binder name
      await tester.enterText(find.byKey(const Key('edit_binder_name_input')), '   ');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byKey(const Key('edit_binder_save_button')));
      await tester.pumpAndSettle();

      // Verify rejection snackbar
      expect(find.text('Binder name cannot be empty.'), findsOneWidget);
    });
  });
}
