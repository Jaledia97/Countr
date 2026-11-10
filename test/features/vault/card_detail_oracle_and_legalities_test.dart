import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'test-rhystic-study',
    String name = 'Rhystic Study',
    String setCode = 'PRM',
    String collectorNumber = '028',
    double price = 42.50,
    int quantity = 1,
    Map<String, dynamic>? dynamicDataMap,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/rhystic.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: jsonEncode(dynamicDataMap ?? {
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'oracle_text':
            'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
        'flavor_text': 'A student of history must never stop studying.',
        'artist': 'Terese Nielsen',
        'type_line': 'Enchantment',
        'legalities': {
          'commander': 'legal',
          'standard': 'not_legal',
          'modern': 'not_legal',
          'pioneer': 'not_legal',
          'legacy': 'legal',
          'vintage': 'restricted',
          'pauper': 'banned',
          'brawl': 'not_legal',
          'oathbreaker': 'legal',
          'historic': 'legal',
        },
      }),
    );
  }

  void configureLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createHarness(
    Widget child, {
    Size viewportSize = const Size(800, 2600),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('Feature 24: Full Descriptions & 10-Format Legalities Grid', () {
    testWidgets('Renders all 10 major format legalities pills in 2-column grid with color coding', (tester) async {
      configureLargeViewport(tester);
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Verify container and header
      expect(find.byKey(const Key('section_format_legalities')), findsOneWidget);
      expect(find.text('Format Legalities'), findsOneWidget);

      // Verify all 10 format pills exist
      final formats = [
        'commander',
        'standard',
        'modern',
        'pioneer',
        'legacy',
        'vintage',
        'pauper',
        'brawl',
        'oathbreaker',
        'historic',
      ];

      for (final f in formats) {
        expect(
          find.byKey(Key('legality_pill_$f')),
          findsOneWidget,
          reason: 'Format pill for $f must exist',
        );
      }

      // Verify 2-column horizontal alignment: Commander (col 1) and Standard (col 2)
      final commanderTop = tester.getTopLeft(find.byKey(const Key('legality_pill_commander'))).dy;
      final standardTop = tester.getTopLeft(find.byKey(const Key('legality_pill_standard'))).dy;
      expect((commanderTop - standardTop).abs() < 1.0, isTrue);

      // Verify Modern (row 2 col 1) and Pioneer (row 2 col 2)
      final modernTop = tester.getTopLeft(find.byKey(const Key('legality_pill_modern'))).dy;
      final pioneerTop = tester.getTopLeft(find.byKey(const Key('legality_pill_pioneer'))).dy;
      expect((modernTop - pioneerTop).abs() < 1.0, isTrue);
      expect(modernTop > commanderTop, isTrue);

      // Verify Status Labels & Colors
      // Commander is Legal -> green
      final commanderFinder = find.descendant(
        of: find.byKey(const Key('legality_pill_commander')),
        matching: find.text('Legal'),
      );
      expect(commanderFinder, findsOneWidget);
      final commanderText = tester.widget<Text>(commanderFinder);
      expect(commanderText.style?.color, equals(AppColors.accentEmerald));

      // Pauper is Banned -> accentRed
      final pauperFinder = find.descendant(
        of: find.byKey(const Key('legality_pill_pauper')),
        matching: find.text('Banned'),
      );
      expect(pauperFinder, findsOneWidget);
      final pauperText = tester.widget<Text>(pauperFinder);
      expect(pauperText.style?.color, equals(AppColors.accentRed));

      // Vintage is Restricted -> accentAmber
      final vintageFinder = find.descendant(
        of: find.byKey(const Key('legality_pill_vintage')),
        matching: find.text('Restricted'),
      );
      expect(vintageFinder, findsOneWidget);
      final vintageText = tester.widget<Text>(vintageFinder);
      expect(vintageText.style?.color, equals(AppColors.accentAmber));

      // Standard is Not Legal -> textMuted
      final standardFinder = find.descendant(
        of: find.byKey(const Key('legality_pill_standard')),
        matching: find.text('Not Legal'),
      );
      expect(standardFinder, findsOneWidget);
      final standardText = tester.widget<Text>(standardFinder);
      expect(standardText.style?.color, equals(AppColors.textMuted));
    });

    testWidgets('Renders Collector Number in Section 9 Metadata & Pedigree', (tester) async {
      configureLargeViewport(tester);
      final card = createTestCard(collectorNumber: '028');
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_collector_number')), findsOneWidget);
      expect(find.text('Collector #028'), findsOneWidget);
    });

    testWidgets('Immediate catalog fallback backfills missing rules, flavor, and legalities for stub card', (tester) async {
      configureLargeViewport(tester);
      // 1. Seed complete catalog card (quantity == 0) for Rhystic Study
      final catalogCard = VaultItem(
        id: 'catalog-rhystic-prm',
        collectionType: 'mtg',
        name: 'Rhystic Study',
        setOrSeries: 'PRM',
        imageUrl: 'https://cards.scryfall.io/normal/front/catalog_rhystic.jpg',
        acquiredPrice: 50.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 50.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'scryfall_id': 'scryfall-rhystic-uuid',
          'collector_number': '028',
          'set': 'prm',
          'oracle_text':
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
          'flavor_text': 'A student of history must never stop studying.',
          'artist': 'Terese Nielsen',
          'type_line': 'Enchantment',
          'legalities': {
            'commander': 'legal',
            'standard': 'not_legal',
            'modern': 'not_legal',
            'pioneer': 'not_legal',
            'legacy': 'legal',
            'vintage': 'restricted',
            'pauper': 'banned',
            'brawl': 'not_legal',
            'oathbreaker': 'legal',
            'historic': 'legal',
          },
        }),
      );
      await db.into(db.vaultItems).insert(catalogCard);

      // 2. Open a stub user card (empty dynamicData or missing legalities/oracle)
      final stubCard = VaultItem(
        id: 'user-stub-rhystic',
        collectionType: 'mtg',
        name: 'Rhystic Study',
        setOrSeries: 'PRM',
        imageUrl: '',
        acquiredPrice: 40.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 40.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
      await db.into(db.vaultItems).insert(stubCard);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: stubCard, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Oracle rules text rendered
      expect(
        find.text('Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
        findsOneWidget,
      );

      // Flavor text rendered
      expect(
        find.text('A student of history must never stop studying.'),
        findsOneWidget,
      );

      // Collector number rendered
      expect(find.byKey(const Key('card_detail_collector_number')), findsOneWidget);
      expect(find.text('Collector #028'), findsOneWidget);

      // All 10 legalities rendered
      expect(find.byKey(const Key('legality_pill_commander')), findsOneWidget);
      expect(find.byKey(const Key('legality_pill_pauper')), findsOneWidget);
    });

    testWidgets('320px logical width with 2.0x font scaling produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 800),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
