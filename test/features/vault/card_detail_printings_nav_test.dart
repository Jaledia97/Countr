import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createCard({
    required String id,
    required String name,
    required String setCode,
    required String collectorNumber,
    required double price,
    int quantity = 1,
    String? setName,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName ?? setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
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
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'set_name': setName ?? setCode.toUpperCase(),
        'finishes': ['nonfoil'],
      }),
    );
  }

  Widget createHarness(
    Widget child, {
    Size viewportSize = const Size(800, 2400),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('R10: Versions & Printings Navigation Tests', () {
    testWidgets('Tapping alternate printing candidate pushes distinct CardDetailSheet page', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialItem = createCard(
        id: 'cmd-sol-ring-active',
        name: 'Sol Ring',
        setCode: 'cmd',
        collectorNumber: '243',
        price: 1.75,
        setName: 'Commander 2011',
      );
      await db.into(db.vaultItems).insert(initialItem);

      // Insert alternative 2X2 printing into catalog
      final alt2x2Item = createCard(
        id: '2x2-sol-ring-alt',
        name: 'Sol Ring',
        setCode: '2x2',
        collectorNumber: '313',
        price: 18.50,
        setName: 'Double Masters 2022',
        quantity: 0,
      );
      await db.into(db.vaultItems).insert(alt2x2Item);

      // Pump CardDetailSheet directly with large viewport height so VariantPriceChart is laid out
      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(
            item: initialItem,
            fetchOnlinePrintings: false,
          ),
          viewportSize: const Size(800, 2600),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial sheet is displayed showing Commander 2011 and $1.75
      expect(find.textContaining('1.75'), findsWidgets);
      expect(find.byKey(const Key('variant_card_cmd_243')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_2x2_313')), findsOneWidget);

      // Tap the 2X2 alternative printing candidate
      await tester.tap(find.byKey(const Key('variant_card_2x2_313')));
      await tester.pumpAndSettle();

      // Verify that a DISTINCT CardDetailSheet has been pushed displaying 2X2 details
      expect(find.byType(CardDetailSheet), findsNWidgets(2));
      expect(find.textContaining('18.50'), findsWidgets);
      expect(find.textContaining('#313'), findsWidgets);

      // Dismiss the pushed sheet by popping the top route
      Navigator.of(tester.element(find.byType(CardDetailSheet).last)).pop();
      await tester.pumpAndSettle();

      // Verify returning to the original sheet (now only 1 CardDetailSheet exists)
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.textContaining('1.75'), findsWidgets);
    });

    testWidgets('Tapping current active printing candidate does not push duplicate sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialItem = createCard(
        id: 'cmd-sol-ring-active-2',
        name: 'Sol Ring',
        setCode: 'cmd',
        collectorNumber: '243',
        price: 1.75,
        setName: 'Commander 2011',
      );
      await db.into(db.vaultItems).insert(initialItem);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(
            item: initialItem,
            fetchOnlinePrintings: false,
          ),
          viewportSize: const Size(800, 2600),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping the active printing (cmd #243)
      final activeFinder = find.byKey(const Key('variant_card_cmd_243'));
      expect(activeFinder, findsOneWidget);

      await tester.tap(activeFinder);
      await tester.pumpAndSettle();

      // Verify no duplicate modal sheet route was pushed (still only 1 CardDetailSheet)
      expect(find.byType(CardDetailSheet), findsOneWidget);
    });

    testWidgets('Resolves unowned online candidate and synthesizes catalog VaultItem for navigation', (tester) async {
      final initialItem = createCard(
        id: 'cmd-sol-ring-online-test',
        name: 'Sol Ring',
        setCode: 'cmd',
        collectorNumber: '243',
        price: 1.75,
      );
      await db.into(db.vaultItems).insert(initialItem);

      // Candidate that doesn't exist in local SQLite (e.g. Masterpiece MPS)
      final mpsCandidate = CardPrintCandidate(
        setCode: 'mps',
        setName: 'Kaladesh Inventions',
        collectorNumber: '024',
        imageUrl: 'https://cards.scryfall.io/normal/front/mps/024.jpg',
        artCropUrl: 'https://cards.scryfall.io/art_crop/front/mps/024.jpg',
        marketPrice: 250.00,
        rarity: 'special',
        finishes: const ['foil'],
        frameEffects: const ['masterpiece'],
        rawData: {
          'id': 'mps-024-uuid',
          'name': 'Sol Ring',
          'set': 'mps',
          'set_name': 'Kaladesh Inventions',
          'collector_number': '024',
          'prices': {'usd': '250.00'},
          'finishes': ['foil'],
        },
      );

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (context) {
              return VariantPriceChart(
                item: initialItem,
                initialVariants: [
                  CardPrintCandidate.fromVaultItem(initialItem),
                  mpsCandidate,
                ],
                enableOnlineFetch: false,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mpsFinder = find.byKey(const Key('variant_card_mps_024'));
      expect(mpsFinder, findsOneWidget);

      // Tap MPS candidate
      await tester.tap(mpsFinder);
      await tester.pumpAndSettle();

      // Pushes distinct CardDetailSheet displaying $250.00 and Kaladesh Inventions
      expect(find.textContaining('250.00'), findsWidgets);
      expect(find.textContaining('#024'), findsWidgets);
    });
  });
}
