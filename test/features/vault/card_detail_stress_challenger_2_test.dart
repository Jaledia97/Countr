import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
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

  VaultItem createTestCard({
    String id = 'stress-card-1',
    String name = 'Sol Ring',
    String setCode = 'CMD',
    String collectorNumber = '243',
    double acquiredPrice = 1.50,
    double marketPrice = 1.75,
    int quantity = 1,
    String condition = 'NM',
    bool isGraded = false,
    String? primaryBinderId,
    String? personalNotes,
    String? typeLine = 'Artifact',
    String? manaCost = '{1}',
    String? power,
    String? toughness,
    String? loyalty,
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode,
      imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      primaryBinderId: primaryBinderId,
      personalNotes: personalNotes ?? 'Staple card for testing.',
      dynamicData: dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'type_line': typeLine,
            'mana_cost': manaCost,
            'power': power,
            'toughness': toughness,
            'loyalty': loyalty,
            'oracle_text': '{T}: Add {C}{C}. Tap this artifact to generate two colorless mana for spells and abilities.',
            'flavor_text': 'Lost to time is the art of crafting such ancient wonders.',
            'cached_rulings': [
              {
                'published_at': '2020-11-10',
                'comment': '{C} is the colorless mana symbol.',
              },
            ],
            'deck_history': ['Commander Deck A', 'Cube 2024'],
          }),
    );
  }

  CardPrintCandidate createCandidate({
    required String setCode,
    required String setName,
    required String collectorNumber,
    required double price,
    List<String> finishes = const ['nonfoil'],
  }) {
    return CardPrintCandidate(
      setCode: setCode.toLowerCase(),
      setName: setName,
      collectorNumber: collectorNumber,
      imageUrl: 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
      artCropUrl: 'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
      marketPrice: price,
      rarity: 'uncommon',
      finishes: finishes,
      frameEffects: const [],
      rawData: {
        'id': '$setCode-$collectorNumber',
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'collector_number': collectorNumber,
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
          'art_crop': 'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
        },
        'prices': {'usd': price.toString()},
        'finishes': finishes,
      },
    );
  }

  Widget createTestWidget(
    Widget child, {
    ScryfallService? scryfallService,
    Size viewportSize = const Size(320, 568),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        if (scryfallService != null)
          scryfallServiceProvider.overrideWithValue(scryfallService),
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

  void configureViewport(WidgetTester tester, {double width = 320, double height = 568, double ratio = 1.0}) {
    tester.view.physicalSize = Size(width * ratio, height * ratio);
    tester.view.devicePixelRatio = ratio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Adversarial Category 1: 320x568 Viewport & TextScaler Matrix (1.0x, 1.5x, 2.0x)', () {
    const scalers = [
      (1.0, '1.0x (standard)'),
      (1.5, '1.5x (large)'),
      (2.0, '2.0x (extreme accessibility)'),
    ];

    for (final (scale, label) in scalers) {
      testWidgets('CardDetailSheet on 320x568 with textScaler $label renders and scrolls without RenderFlex overflows', (tester) async {
        configureViewport(tester, width: 320, height: 568);

        final item = createTestCard(
          name: 'Atraxa, Praetors\' Voice',
          typeLine: 'Legendary Creature — Phyrexian Angel Horror',
          manaCost: '{G}{W}{U}{B}',
          power: '4',
          toughness: '4',
          dynamicData: jsonEncode({
            'collector_number': '028',
            'set': '2xm',
            'oracle_text': 'Flying, vigilance, deathtouch, lifelink\nAt the beginning of your end step, choose any number of counters on anything, then give each another counter of a kind already there.',
            'flavor_text': 'A terrifying triumph of unified Phyrexian perfection.',
            'cached_rulings': [
              {
                'published_at': '2020-08-07',
                'comment': 'You can choose any permanent, player, or card in exile with counters on it.',
              },
            ],
            'deck_history': ['Commander Deck - Superfriends', 'Infect Competitive'],
          }),
        );

        final List<FlutterErrorDetails> errors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          originalOnError?.call(details);
        };

        try {
          await tester.pumpWidget(createTestWidget(
            CardDetailSheet(item: item, fetchOnlinePrintings: false),
            viewportSize: const Size(320, 568),
            textScaler: TextScaler.linear(scale),
          ));
          await tester.pumpAndSettle();

          final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
          expect(listFinder, findsOneWidget);

          // Scroll down in steps to force all lazy children and layout sections to render
          for (int i = 0; i < 5; i++) {
            await tester.drag(listFinder, const Offset(0, -250));
            await tester.pumpAndSettle();
          }

          // Scroll back up to the top
          for (int i = 0; i < 5; i++) {
            await tester.drag(listFinder, const Offset(0, 250));
            await tester.pumpAndSettle();
          }

          final overflowErrors = errors.where((e) {
            final msg = e.exceptionAsString();
            return msg.contains('RenderFlex overflowed') ||
                msg.contains('A RenderFlex overflowed') ||
                msg.contains('overflowed by');
          }).toList();

          expect(
            overflowErrors,
            isEmpty,
            reason: 'CardDetailSheet must have 0 RenderFlex overflows on 320x568 at $label. '
                'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      });
    }

    testWidgets('CardDetailSheet on 320x568 with textScaler 2.0x scrolls to VariantPriceChart without RenderFlex overflow', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(name: 'Sol Ring');

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));

        // Scroll down to reveal sections 1, 2, 3, 4
        for (int i = 0; i < 4; i++) {
          await tester.drag(listFinder, const Offset(0, -300));
          await tester.pumpAndSettle();
        }

        final overflowErrors = errors.where((e) {
          final msg = e.exceptionAsString();
          return msg.contains('RenderFlex overflowed') ||
              msg.contains('A RenderFlex overflowed') ||
              msg.contains('overflowed by');
        }).toList();

        expect(
          overflowErrors,
          isEmpty,
          reason: 'CardDetailSheet must not overflow when scrolling down on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });

  group('Adversarial Category 2: Extreme High Price Values & Profit/Loss Deltas', () {
    testWidgets('handles massive price tag \$999,999.00 and +\$100,000.00 profit delta on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(
        id: 'black-lotus-alpha',
        name: 'Black Lotus',
        setCode: 'LEA',
        collectorNumber: '232',
        acquiredPrice: 899999.00,
        marketPrice: 999999.00,
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        // Scroll down to Portfolio Metrics section
        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
        await tester.drag(listFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'High price render must not cause RenderFlex overflow');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('handles astronomical percentage gain (+\$100,000.00 / +9999.9%+) from penny buy on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(
        id: 'crypto-penny-card',
        name: 'Mox Diamond',
        setCode: 'STH',
        acquiredPrice: 1.00,
        marketPrice: 100001.00,
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
        await tester.drag(listFinder, const Offset(0, -320));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'Astronomical percentage gain must fit inside FittedBox without overflow');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('handles catastrophic loss delta (-\$999,998.00 / -100.0%) on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(
        id: 'crashed-asset',
        name: 'Speculative Asset Card',
        acquiredPrice: 999999.00,
        marketPrice: 1.00,
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
        await tester.drag(listFinder, const Offset(0, -320));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'Massive loss delta must render safely');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('VariantPriceChart renders extreme prices (\$999,999.00 and \$0.00 unlisted) without overflow at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(marketPrice: 999999.00);
      final variants = [
        createCandidate(setCode: 'ALPHA', setName: 'Limited Edition Alpha', collectorNumber: '001', price: 999999.00, finishes: ['foil']),
        createCandidate(setCode: 'BETA', setName: 'Limited Edition Beta', collectorNumber: '002', price: 125000.00, finishes: ['etched']),
        createCandidate(setCode: 'UNL', setName: 'Unlimited Edition', collectorNumber: '003', price: 0.00, finishes: ['nonfoil']),
      ];

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          VariantPriceChart(
            item: item,
            initialVariants: variants,
            enableOnlineFetch: false,
          ),
          viewportSize: const Size(320, 250),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'VariantPriceChart must not overflow with extreme prices on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });

  group('Adversarial Category 3: Unusually Long Card and Set Names', () {
    testWidgets('CardDetailSheet handles 100+ character card name and 80+ character set name on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      const longCardName = 'The Ultimate Super Mega Ultra-Legendary Cosmic Artifact Creature — Eldrazi Phyrexian Dragon God of the Multiverse and Infinite Realms Beyond';
      const longSetName = 'Universes Beyond: The Lord of the Rings: Tales of Middle-earth Special Holiday Collector Extended Art Foil Edition 2026';
      const longTypeLine = 'Legendary Artifact Enchantment Planeswalker Creature — Eldrazi Phyrexian Human Wizard Soldier Praetor Noble';
      const longBinder = 'Ultra-Pro Collectors Vault Deluxe Leatherette 12-Pocket Mythic Rare Foil Vault Binder 2026';

      final item = createTestCard(
        id: 'super-long-card',
        name: longCardName,
        setCode: longSetName,
        typeLine: longTypeLine,
        primaryBinderId: longBinder,
        personalNotes: 'This card was specially designed to break text measurement engines and flex containers that fail to wrap properly.',
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
        for (int i = 0; i < 5; i++) {
          await tester.drag(listFinder, const Offset(0, -250));
          await tester.pumpAndSettle();
        }

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Long card/set names must not cause overflow. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('VariantPriceChart handles long set codes and numbers (e.g. SLD-EXT-2026 #999999/1000000) on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard();
      final variants = [
        createCandidate(
          setCode: 'SLD-EXT-2026',
          setName: 'Secret Lair Drop: Special Guest Extended Collector Foil Series Edition 2026',
          collectorNumber: '999999/1000000',
          price: 99.99,
          finishes: ['foil', 'etched'],
        ),
      ];

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          VariantPriceChart(
            item: item,
            initialVariants: variants,
            enableOnlineFetch: false,
          ),
          viewportSize: const Size(320, 250),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'VariantPriceChart must not overflow with long candidate strings on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });

  group('Adversarial Category 4: Zero Available Printings vs 50 Printings Stress Test', () {
    testWidgets('renders empty variant state gracefully (0 printings) on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard();

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          VariantPriceChart(
            item: item,
            initialVariants: const [],
            enableOnlineFetch: false,
          ),
          viewportSize: const Size(320, 250),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Zero printings empty state must not overflow at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('renders 50 printings in VariantPriceChart and supports horizontal scrolling on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(setCode: 'SET0', collectorNumber: '0');

      final finishesPool = [
        ['nonfoil'],
        ['foil'],
        ['etched'],
        ['foil', 'etched'],
      ];

      final variants = List.generate(50, (i) {
        return createCandidate(
          setCode: 'SET$i',
          setName: 'Expansion Set Number $i With A Descriptive Title',
          collectorNumber: (i + 1).toString().padLeft(3, '0'),
          price: (i + 1) * 2.50,
          finishes: finishesPool[i % finishesPool.length],
        );
      });

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          VariantPriceChart(
            item: item,
            initialVariants: variants,
            enableOnlineFetch: false,
          ),
          viewportSize: const Size(320, 250),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final scrollerFinder = find.byKey(const Key('variant_price_chart_list'));
        if (scrollerFinder.evaluate().isNotEmpty) {
          for (int step = 0; step < 6; step++) {
            await tester.drag(scrollerFinder, const Offset(-300, 0));
            await tester.pumpAndSettle();
          }
        }

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: '50-printing chart must not overflow on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('full CardDetailSheet with 50 printings scrolls seamlessly on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final item = createTestCard(setCode: 'SET0', collectorNumber: '001');

      for (int i = 0; i < 50; i++) {
        await db.into(db.vaultItems).insert(VaultItem(
          id: 'catalog-item-$i',
          collectionType: 'mtg',
          name: item.name,
          setOrSeries: 'SET$i',
          imageUrl: 'https://cards.scryfall.io/set$i/001.jpg',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: i == 0 ? 1 : 0,
          condition: 'NM',
          isGraded: false, isAltered: false, isMisprint: false, isSigned: false, isDeleted: false,
          currentMarketPrice: (i + 1) * 3.0,
          lastPriceUpdate: DateTime(2023, 1, 1),
          dynamicData: jsonEncode({'collector_number': '001', 'set': 'set$i'}),
        ));
      }

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: item, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));

        for (int i = 0; i < 4; i++) {
          await tester.drag(listFinder, const Offset(0, -300));
          await tester.pumpAndSettle();
        }

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Full sheet with 50 printings must not overflow on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });

  group('Adversarial Category 5: Unowned Catalog Items & Double-Faced Cards on 320x568 at 2.0x Text Scale', () {
    testWidgets('unowned catalog card (quantity: 0) displays action bar and metrics without overflow on 320x568 at 2.0x text scale', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final catalogItem = createTestCard(
        id: 'unowned-catalog-card',
        quantity: 0,
        acquiredPrice: 0.0,
        marketPrice: 349.99,
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: catalogItem, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Add to Vault / Inbox'), findsOneWidget);

        final listFinder = find.byKey(PageStorageKey('card_detail_list_${catalogItem.id}'));
        await tester.drag(listFinder, const Offset(0, -400));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'Unowned catalog card must render without overflow on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('double-faced transforming card flips smoothly on 320x568 at 2.0x text scale with 0 overflows', (tester) async {
      configureViewport(tester, width: 320, height: 568);

      final dfc = createTestCard(
        id: 'dfc-delver-adversarial',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: jsonEncode({
          'collector_number': '051',
          'set': 'isd',
          'oracle_text': 'At the beginning of your upkeep, look at the top card of your library. You may reveal that card. If an instant or sorcery card is revealed this way, transform Delver of Secrets.',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
              'type_line': 'Creature — Human Wizard',
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
              'type_line': 'Creature — Human Insect',
            },
          ],
        }),
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(createTestWidget(
          CardDetailSheet(item: dfc, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();

        final flipBtn = find.byKey(const Key('card_detail_flip_button'));
        expect(flipBtn, findsOneWidget);

        // Trigger 3D flip animation and pump mid-animation frames
        await tester.tap(flipBtn);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'DFC flip animation must have 0 overflows on 320x568 at 2.0x text scale. '
              'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });
}
