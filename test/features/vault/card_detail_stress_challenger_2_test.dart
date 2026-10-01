import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
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
    String? setName,
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
      setOrSeries: setName ?? setCode,
      imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      primaryBinderId: primaryBinderId,
      personalNotes: personalNotes ?? 'Staple card for testing.',
      dynamicData:
          dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'type_line': typeLine,
            'mana_cost': manaCost,
            'power': power,
            'toughness': toughness,
            'loyalty': loyalty,
            'oracle_text':
                '{T}: Add {C}{C}. Tap this artifact to generate two colorless mana for spells and abilities.',
            'flavor_text':
                'Lost to time is the art of crafting such ancient wonders.',
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
      imageUrl:
          'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
      artCropUrl:
          'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
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
          'normal':
              'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
          'art_crop':
              'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
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
          data: MediaQueryData(size: viewportSize, textScaler: textScaler),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  void configureViewport(
    WidgetTester tester, {
    double width = 320,
    double height = 568,
    double ratio = 1.0,
  }) {
    tester.view.physicalSize = Size(width * ratio, height * ratio);
    tester.view.devicePixelRatio = ratio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group(
    'Adversarial Category 1: 320x568 Viewport & TextScaler Matrix (1.0x, 1.5x, 2.0x)',
    () {
      const scalers = [
        (1.0, '1.0x (standard)'),
        (1.5, '1.5x (large)'),
        (2.0, '2.0x (extreme accessibility)'),
      ];

      for (final (scale, label) in scalers) {
        testWidgets(
          'CardDetailSheet on 320x568 with textScaler $label renders and scrolls without RenderFlex overflows',
          (tester) async {
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
                'oracle_text':
                    'Flying, vigilance, deathtouch, lifelink\nAt the beginning of your end step, choose any number of counters on anything, then give each another counter of a kind already there.',
                'flavor_text':
                    'A terrifying triumph of unified Phyrexian perfection.',
                'cached_rulings': [
                  {
                    'published_at': '2020-08-07',
                    'comment':
                        'You can choose any permanent, player, or card in exile with counters on it.',
                  },
                ],
                'deck_history': [
                  'Commander Deck - Superfriends',
                  'Infect Competitive',
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
              await tester.pumpWidget(
                createTestWidget(
                  CardDetailSheet(item: item, fetchOnlinePrintings: false),
                  viewportSize: const Size(320, 568),
                  textScaler: TextScaler.linear(scale),
                ),
              );
              await tester.pumpAndSettle();

              final listFinder = find.byKey(
                PageStorageKey('card_detail_list_${item.id}'),
              );
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
                reason:
                    'CardDetailSheet must have 0 RenderFlex overflows on 320x568 at $label. '
                    'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
              );
              expect(tester.takeException(), isNull);
            } finally {
              FlutterError.onError = originalOnError;
            }
          },
        );
      }

      testWidgets(
        'CardDetailSheet on 320x568 with textScaler 2.0x scrolls to VariantPriceChart without RenderFlex overflow',
        (tester) async {
          configureViewport(tester, width: 320, height: 568);

          final item = createTestCard(name: 'Sol Ring');

          final List<FlutterErrorDetails> errors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            originalOnError?.call(details);
          };

          try {
            await tester.pumpWidget(
              createTestWidget(
                CardDetailSheet(item: item, fetchOnlinePrintings: false),
                viewportSize: const Size(320, 568),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            final listFinder = find.byKey(
              PageStorageKey('card_detail_list_${item.id}'),
            );

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
              reason:
                  'CardDetailSheet must not overflow when scrolling down on 320x568 at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    },
  );

  group('Adversarial Category 2: Extreme High Price Values & Profit/Loss Deltas', () {
    testWidgets(
      'handles massive price tag \$999,999.00 and +\$100,000.00 profit delta on 320x568 at 2.0x text scale',
      (tester) async {
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
          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: item, fetchOnlinePrintings: false),
              viewportSize: const Size(320, 568),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          // Scroll down to Portfolio Metrics section
          final listFinder = find.byKey(
            PageStorageKey('card_detail_list_${item.id}'),
          );
          await tester.drag(listFinder, const Offset(0, -300));
          await tester.pumpAndSettle();

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason: 'High price render must not cause RenderFlex overflow',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'handles astronomical percentage gain (+\$100,000.00 / +9999.9%+) from penny buy on 320x568 at 2.0x text scale',
      (tester) async {
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
          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: item, fetchOnlinePrintings: false),
              viewportSize: const Size(320, 568),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          final listFinder = find.byKey(
            PageStorageKey('card_detail_list_${item.id}'),
          );
          await tester.drag(listFinder, const Offset(0, -320));
          await tester.pumpAndSettle();

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'Astronomical percentage gain must fit inside FittedBox without overflow',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'handles catastrophic loss delta (-\$999,998.00 / -100.0%) on 320x568 at 2.0x text scale',
      (tester) async {
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
          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: item, fetchOnlinePrintings: false),
              viewportSize: const Size(320, 568),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          final listFinder = find.byKey(
            PageStorageKey('card_detail_list_${item.id}'),
          );
          await tester.drag(listFinder, const Offset(0, -320));
          await tester.pumpAndSettle();

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason: 'Massive loss delta must render safely',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'VariantPriceChart renders extreme prices (\$999,999.00 and \$0.00 unlisted) without overflow at 2.0x text scale',
      (tester) async {
        configureViewport(tester, width: 320, height: 568);

        final item = createTestCard(marketPrice: 999999.00);
        final variants = [
          createCandidate(
            setCode: 'ALPHA',
            setName: 'Limited Edition Alpha',
            collectorNumber: '001',
            price: 999999.00,
            finishes: ['foil'],
          ),
          createCandidate(
            setCode: 'BETA',
            setName: 'Limited Edition Beta',
            collectorNumber: '002',
            price: 125000.00,
            finishes: ['etched'],
          ),
          createCandidate(
            setCode: 'UNL',
            setName: 'Unlimited Edition',
            collectorNumber: '003',
            price: 0.00,
            finishes: ['nonfoil'],
          ),
        ];

        final List<FlutterErrorDetails> errors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          originalOnError?.call(details);
        };

        try {
          await tester.pumpWidget(
            createTestWidget(
              VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
              ),
              viewportSize: const Size(320, 250),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'VariantPriceChart must not overflow with extreme prices on 320x568 at 2.0x text scale. '
                'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });

  group('Adversarial Category 3: Unusually Long Card and Set Names', () {
    testWidgets(
      'CardDetailSheet handles 100+ character card name and 80+ character set name on 320x568 at 2.0x text scale',
      (tester) async {
        configureViewport(tester, width: 320, height: 568);

        const longCardName =
            'The Ultimate Super Mega Ultra-Legendary Cosmic Artifact Creature — Eldrazi Phyrexian Dragon God of the Multiverse and Infinite Realms Beyond';
        const longSetName =
            'Universes Beyond: The Lord of the Rings: Tales of Middle-earth Special Holiday Collector Extended Art Foil Edition 2026';
        const longTypeLine =
            'Legendary Artifact Enchantment Planeswalker Creature — Eldrazi Phyrexian Human Wizard Soldier Praetor Noble';
        const longBinder =
            'Ultra-Pro Collectors Vault Deluxe Leatherette 12-Pocket Mythic Rare Foil Vault Binder 2026';

        final item = createTestCard(
          id: 'super-long-card',
          name: longCardName,
          setCode: longSetName,
          typeLine: longTypeLine,
          primaryBinderId: longBinder,
          personalNotes:
              'This card was specially designed to break text measurement engines and flex containers that fail to wrap properly.',
        );

        final List<FlutterErrorDetails> errors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          originalOnError?.call(details);
        };

        try {
          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: item, fetchOnlinePrintings: false),
              viewportSize: const Size(320, 568),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          final listFinder = find.byKey(
            PageStorageKey('card_detail_list_${item.id}'),
          );
          for (int i = 0; i < 5; i++) {
            await tester.drag(listFinder, const Offset(0, -250));
            await tester.pumpAndSettle();
          }

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'Long card/set names must not cause overflow. '
                'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'VariantPriceChart handles long set codes and numbers (e.g. SLD-EXT-2026 #999999/1000000) on 320x568 at 2.0x text scale',
      (tester) async {
        configureViewport(tester, width: 320, height: 568);

        final item = createTestCard();
        final variants = [
          createCandidate(
            setCode: 'SLD-EXT-2026',
            setName:
                'Secret Lair Drop: Special Guest Extended Collector Foil Series Edition 2026',
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
          await tester.pumpWidget(
            createTestWidget(
              VariantPriceChart(
                item: item,
                initialVariants: variants,
                enableOnlineFetch: false,
              ),
              viewportSize: const Size(320, 250),
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pumpAndSettle();

          final overflowErrors = errors
              .where((e) => e.exceptionAsString().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'VariantPriceChart must not overflow with long candidate strings on 320x568 at 2.0x text scale. '
                'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
          );
          expect(tester.takeException(), isNull);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });

  group(
    'Adversarial Category 4: Zero Available Printings vs 50 Printings Stress Test',
    () {
      testWidgets(
        'renders empty variant state gracefully (0 printings) on 320x568 at 2.0x text scale',
        (tester) async {
          configureViewport(tester, width: 320, height: 568);

          final item = createTestCard();

          final List<FlutterErrorDetails> errors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            originalOnError?.call(details);
          };

          try {
            await tester.pumpWidget(
              createTestWidget(
                VariantPriceChart(
                  item: item,
                  initialVariants: const [],
                  enableOnlineFetch: false,
                ),
                viewportSize: const Size(320, 250),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            final overflowErrors = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Zero printings empty state must not overflow at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'renders 50 printings in VariantPriceChart and supports horizontal scrolling on 320x568 at 2.0x text scale',
        (tester) async {
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
            await tester.pumpWidget(
              createTestWidget(
                VariantPriceChart(
                  item: item,
                  initialVariants: variants,
                  enableOnlineFetch: false,
                ),
                viewportSize: const Size(320, 250),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            final scrollerFinder = find.byKey(
              const Key('variant_price_chart_list'),
            );
            if (scrollerFinder.evaluate().isNotEmpty) {
              for (int step = 0; step < 6; step++) {
                await tester.drag(scrollerFinder, const Offset(-300, 0));
                await tester.pumpAndSettle();
              }
            }

            final overflowErrors = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  '50-printing chart must not overflow on 320x568 at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'full CardDetailSheet with 50 printings scrolls seamlessly on 320x568 at 2.0x text scale',
        (tester) async {
          configureViewport(tester, width: 320, height: 568);

          final item = createTestCard(setCode: 'SET0', collectorNumber: '001');

          for (int i = 0; i < 50; i++) {
            await db
                .into(db.vaultItems)
                .insert(
                  VaultItem(
                    id: 'catalog-item-$i',
                    collectionType: 'mtg',
                    name: item.name,
                    setOrSeries: 'SET$i',
                    imageUrl: 'https://cards.scryfall.io/set$i/001.jpg',
                    acquiredPrice: 1.0,
                    acquiredDate: DateTime(2023, 1, 1),
                    quantity: i == 0 ? 1 : 0,
                    condition: 'NM',
                    isGraded: false,
                    isAltered: false,
                    isMisprint: false,
                    isSigned: false,
                    isDeleted: false,
                    currentMarketPrice: (i + 1) * 3.0,
                    lastPriceUpdate: DateTime(2023, 1, 1),
                    dynamicData: jsonEncode({
                      'collector_number': '001',
                      'set': 'set$i',
                    }),
                  ),
                );
          }

          final List<FlutterErrorDetails> errors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            originalOnError?.call(details);
          };

          try {
            await tester.pumpWidget(
              createTestWidget(
                CardDetailSheet(item: item, fetchOnlinePrintings: false),
                viewportSize: const Size(320, 568),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            final listFinder = find.byKey(
              PageStorageKey('card_detail_list_${item.id}'),
            );

            for (int i = 0; i < 4; i++) {
              await tester.drag(listFinder, const Offset(0, -300));
              await tester.pumpAndSettle();
            }

            final overflowErrors = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Full sheet with 50 printings must not overflow on 320x568 at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    },
  );

  group(
    'Adversarial Category 5: Unowned Catalog Items & Double-Faced Cards on 320x568 at 2.0x Text Scale',
    () {
      testWidgets(
        'unowned catalog card (quantity: 0) displays action bar and metrics without overflow on 320x568 at 2.0x text scale',
        (tester) async {
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
            await tester.pumpWidget(
              createTestWidget(
                CardDetailSheet(item: catalogItem, fetchOnlinePrintings: false),
                viewportSize: const Size(320, 568),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Add to Vault'), findsOneWidget);

            final listFinder = find.byKey(
              PageStorageKey('card_detail_list_${catalogItem.id}'),
            );
            await tester.drag(listFinder, const Offset(0, -400));
            await tester.pumpAndSettle();

            final overflowErrors = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Unowned catalog card must render without overflow on 320x568 at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'double-faced transforming card flips smoothly on 320x568 at 2.0x text scale with 0 overflows',
        (tester) async {
          configureViewport(tester, width: 320, height: 568);

          final dfc = createTestCard(
            id: 'dfc-delver-adversarial',
            name: 'Delver of Secrets // Insectile Aberration',
            dynamicData: jsonEncode({
              'collector_number': '051',
              'set': 'isd',
              'oracle_text':
                  'At the beginning of your upkeep, look at the top card of your library. You may reveal that card. If an instant or sorcery card is revealed this way, transform Delver of Secrets.',
              'card_faces': [
                {
                  'name': 'Delver of Secrets',
                  'image_uris': {
                    'normal': 'https://cards.scryfall.io/front/delver.jpg',
                  },
                  'type_line': 'Creature — Human Wizard',
                },
                {
                  'name': 'Insectile Aberration',
                  'image_uris': {
                    'normal': 'https://cards.scryfall.io/back/insectile.jpg',
                  },
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
            await tester.pumpWidget(
              createTestWidget(
                CardDetailSheet(item: dfc, fetchOnlinePrintings: false),
                viewportSize: const Size(320, 568),
                textScaler: const TextScaler.linear(2.0),
              ),
            );
            await tester.pumpAndSettle();

            final flipBtn = find.byKey(const Key('card_detail_flip_button'));
            expect(flipBtn, findsOneWidget);

            // Trigger 3D flip animation and pump mid-animation frames
            await tester.tap(flipBtn);
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pumpAndSettle();

            final overflowErrors = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'DFC flip animation must have 0 overflows on 320x568 at 2.0x text scale. '
                  'Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    },
  );

  group(
    'Adversarial Category 6: Empirical Challenger 2 Stress Suite - Unowned vs Owned, Tab Toggle, DB Updates',
    () {
      testWidgets(
        '6.1 Unowned card (quantity: 0) pre-existing in DB displays "Add to Vault", tapping updates DB quantity to 1, binder to INBOX, shows SnackBar, and pops sheet',
        (tester) async {
          final catalogCard = createTestCard(
            id: 'db-unowned-catalog-1',
            name: 'The One Ring',
            quantity: 0,
            setCode: 'LTR',
            marketPrice: 120.00,
          );

          // Pre-seed into database with quantity = 0 and binder CATALOG
          await db
              .into(db.vaultItems)
              .insert(
                VaultItemsCompanion.insert(
                  id: catalogCard.id,
                  collectionType: catalogCard.collectionType,
                  name: catalogCard.name,
                  setOrSeries: catalogCard.setOrSeries,
                  imageUrl: catalogCard.imageUrl,
                  acquiredPrice: catalogCard.acquiredPrice,
                  acquiredDate: catalogCard.acquiredDate,
                  quantity: const drift.Value(0),
                  condition: catalogCard.condition,
                  isGraded: drift.Value(catalogCard.isGraded),
                  primaryBinderId: const drift.Value('CATALOG'),
                  currentMarketPrice: catalogCard.currentMarketPrice,
                  lastPriceUpdate: catalogCard.lastPriceUpdate,
                  dynamicData: catalogCard.dynamicData,
                  isDeleted: const drift.Value(false),
                  updatedAt: drift.Value(DateTime(2023, 1, 1)),
                ),
              );

          // Verify pre-condition in DB
          final before = await db.vaultDao.getItemById('db-unowned-catalog-1');
          expect(before, isNotNull);
          expect(before!.quantity, equals(0));
          expect(before.primaryBinderId, equals('CATALOG'));

          // Launch sheet using CardDetailSheet.show
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                vaultDaoProvider.overrideWithValue(db.vaultDao),
              ],
              child: MaterialApp(
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => CardDetailSheet.show(ctx, catalogCard),
                        child: const Text('Open Detail Sheet'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Detail Sheet'));
          await tester.pumpAndSettle();

          // Verify unowned card displays 'Add to Vault' button
          final addBtnFinder = find.byKey(
            const Key('card_detail_add_to_vault'),
          );
          expect(addBtnFinder, findsOneWidget);
          expect(find.text('Add to Vault'), findsOneWidget);
          expect(find.text('Add to Vault / Inbox'), findsNothing);

          // Tap 'Add to Vault'
          await tester.tap(addBtnFinder);
          await tester.pumpAndSettle();

          // Sheet should be popped and SnackBar displayed
          expect(find.byType(CardDetailSheet), findsNothing);
          expect(find.text('Added "The One Ring" to Inbox'), findsOneWidget);

          // Database quantity must now be updated to 1, binder to INBOX
          final after = await db.vaultDao.getItemById('db-unowned-catalog-1');
          expect(after, isNotNull);
          expect(after!.quantity, equals(1));
          expect(after.primaryBinderId, equals('INBOX'));
        },
      );

      testWidgets(
        '6.2 Unowned card (quantity: 0) not pre-existing in DB inserts new record with quantity 1 into INBOX upon tapping "Add to Vault"',
        (tester) async {
          final unseededCard = createTestCard(
            id: 'new-unseeded-catalog-2',
            name: 'Mox Diamond',
            quantity: 0,
            setCode: 'STH',
            marketPrice: 650.00,
          );

          // Verify not yet in DB
          final initial = await db.vaultDao.getItemById(
            'new-unseeded-catalog-2',
          );
          expect(initial, isNull);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                vaultDaoProvider.overrideWithValue(db.vaultDao),
              ],
              child: MaterialApp(
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () =>
                            CardDetailSheet.show(ctx, unseededCard),
                        child: const Text('Open Detail Sheet'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Detail Sheet'));
          await tester.pumpAndSettle();

          final addBtnFinder = find.byKey(
            const Key('card_detail_add_to_vault'),
          );
          expect(addBtnFinder, findsOneWidget);
          expect(find.text('Add to Vault'), findsOneWidget);

          await tester.tap(addBtnFinder);
          await tester.pumpAndSettle();

          expect(find.byType(CardDetailSheet), findsNothing);
          expect(find.text('Added "Mox Diamond" to Inbox'), findsOneWidget);

          final inserted = await db.vaultDao.getItemById(
            'new-unseeded-catalog-2',
          );
          expect(inserted, isNotNull);
          expect(inserted!.quantity, equals(1));
          expect(inserted.primaryBinderId, equals('INBOX'));
        },
      );

      testWidgets(
        '6.3 Owned cards across quantity boundaries (1, 2, 5, 100) strictly omit "Add to Vault" button and display portfolio metrics',
        (tester) async {
          for (final qty in [1, 2, 5, 100]) {
            final ownedCard = createTestCard(
              id: 'owned-card-qty-$qty',
              name: 'Force of Will',
              quantity: qty,
              setCode: 'ALL',
              marketPrice: 95.00,
            );

            await tester.pumpWidget(
              createTestWidget(
                CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false),
                viewportSize: const Size(390, 844),
              ),
            );
            await tester.pumpAndSettle();

            // Must NOT render Add to Vault button or text
            expect(
              find.byKey(const Key('card_detail_add_to_vault')),
              findsNothing,
              reason:
                  'Card with quantity $qty must NOT show Add to Vault button',
            );
            expect(
              find.text('Add to Vault'),
              findsNothing,
              reason: 'Card with quantity $qty must NOT show Add to Vault text',
            );
            expect(
              find.text('Add to Vault / Inbox'),
              findsNothing,
              reason:
                  'Card with quantity $qty must NOT show legacy button text',
            );

            // Segmented control and tab content must be directly adjacent without button
            final segmentFinder = find.byKey(
              const Key('card_detail_segmented_control'),
            );
            final rulesFinder = find.byKey(const Key('section_oracle_rules'));
            expect(segmentFinder, findsOneWidget);
            expect(rulesFinder, findsOneWidget);
            expect(
              tester.getBottomLeft(segmentFinder).dy,
              lessThanOrEqualTo(tester.getTopLeft(rulesFinder).dy),
              reason:
                  'Tab content must immediately follow segmented control when button is omitted',
            );
          }
        },
      );

      testWidgets(
        '6.4 Tab switching between Details and Values retains Top Hero basic info at exact coordinates without flickering or unmounting',
        (tester) async {
          final card = createTestCard(
            id: 'hero-retention-test',
            name: 'Urza, Lord High Artificer',
            manaCost: '{2}{U}{U}',
            setCode: 'MH1',
            setName: 'Modern Horizons',
            marketPrice: 18.50,
            typeLine: 'Legendary Creature — Human Artificer',
            power: '1',
            toughness: '4',
          );

          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: card, fetchOnlinePrintings: false),
            ),
          );
          await tester.pumpAndSettle();

          final artFinder = find.byKey(Key('card_artwork_${card.id}'));
          final nameFinder = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data == 'Urza, Lord High Artificer' &&
                w.style?.fontSize == 18,
          );
          final manaFinder = find.byType(ManaCostBar);
          final setCodeFinder = find.text('MH1');
          final setNameFinder = find.text('Modern Horizons');
          final priceFinder = find.text('Market: \$18.50');
          final typeLineFinder = find.text(
            'Legendary Creature — Human Artificer',
          );
          final ptFinder = find.text('P/T: 1 / 4');

          // Check initial Details tab state
          expect(artFinder, findsOneWidget);
          expect(nameFinder, findsOneWidget);
          expect(manaFinder, findsOneWidget);
          expect(setCodeFinder, findsOneWidget);
          expect(setNameFinder, findsOneWidget);
          expect(priceFinder, findsOneWidget);
          expect(typeLineFinder, findsOneWidget);
          expect(ptFinder, findsOneWidget);
          expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);

          final initialArtRect = tester.getRect(artFinder);
          final initialNameRect = tester.getRect(nameFinder);
          final initialPriceRect = tester.getRect(priceFinder);

          // Switch to Values tab
          await tester.tap(find.byKey(const Key('card_detail_tab_values')));
          await tester.pumpAndSettle();

          // Top Hero elements must remain visible
          expect(artFinder, findsOneWidget);
          expect(nameFinder, findsOneWidget);
          expect(manaFinder, findsOneWidget);
          expect(setCodeFinder, findsOneWidget);
          expect(setNameFinder, findsOneWidget);
          expect(priceFinder, findsOneWidget);
          expect(typeLineFinder, findsOneWidget);
          expect(ptFinder, findsOneWidget);

          // Geometry and positioning must remain completely stable
          expect(tester.getRect(artFinder), equals(initialArtRect));
          expect(tester.getRect(nameFinder), equals(initialNameRect));
          expect(tester.getRect(priceFinder), equals(initialPriceRect));

          // Tab contents must be swapped
          expect(find.byKey(const Key('section_oracle_rules')), findsNothing);

          // Switch back to Details tab
          await tester.tap(find.byKey(const Key('card_detail_tab_details')));
          await tester.pumpAndSettle();

          // Hero remains stable and Details content returns
          expect(artFinder, findsOneWidget);
          expect(nameFinder, findsOneWidget);
          expect(tester.getRect(artFinder), equals(initialArtRect));
          expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
        },
      );

      testWidgets(
        '6.5 Rapid tab thrashing (10 alternating taps) preserves Top Hero integrity with 0 exceptions or layout shifts',
        (tester) async {
          final card = createTestCard(
            id: 'tab-thrash-card',
            name: 'Grief',
            manaCost: '{2}{B}{B}',
            setCode: 'MH2',
            marketPrice: 3.25,
          );

          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: card, fetchOnlinePrintings: false),
            ),
          );
          await tester.pumpAndSettle();

          final detailsTabFinder = find.byKey(
            const Key('card_detail_tab_details'),
          );
          final valuesTabFinder = find.byKey(
            const Key('card_detail_tab_values'),
          );
          final nameFinder = find.byWidgetPredicate(
            (w) => w is Text && w.data == 'Grief' && w.style?.fontSize == 18,
          );

          for (int i = 0; i < 10; i++) {
            final targetTab = (i % 2 == 0) ? valuesTabFinder : detailsTabFinder;
            await tester.tap(targetTab);
            await tester.pump(const Duration(milliseconds: 50));
            expect(nameFinder, findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          await tester.pumpAndSettle();
          expect(nameFinder, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '6.6 DFC transforming card retains Face 2 hero metadata across Details and Values tab switching',
        (tester) async {
          final dfc = createTestCard(
            id: 'dfc-tab-switch-test',
            name: 'Delver of Secrets // Insectile Aberration',
            dynamicData: jsonEncode({
              'collector_number': '051',
              'set': 'isd',
              'oracle_text': 'Transform Delver of Secrets.',
              'card_faces': [
                {
                  'name': 'Delver of Secrets',
                  'image_uris': {
                    'normal': 'https://cards.scryfall.io/front/delver.jpg',
                  },
                  'type_line': 'Creature — Human Wizard',
                  'mana_cost': '{U}',
                  'power': '1',
                  'toughness': '1',
                },
                {
                  'name': 'Insectile Aberration',
                  'image_uris': {
                    'normal': 'https://cards.scryfall.io/back/insectile.jpg',
                  },
                  'type_line': 'Creature — Human Insect',
                  'mana_cost': '',
                  'power': '3',
                  'toughness': '2',
                },
              ],
            }),
          );

          await tester.pumpWidget(
            createTestWidget(
              CardDetailSheet(item: dfc, fetchOnlinePrintings: false),
            ),
          );
          await tester.pumpAndSettle();

          // Initial face 1
          expect(find.text('Delver of Secrets'), findsOneWidget);

          // Flip card to Face 2
          final flipBtn = find.byKey(const Key('card_detail_flip_button'));
          await tester.tap(flipBtn);
          await tester.pumpAndSettle();

          // Face 2 is now shown in hero
          expect(find.text('Insectile Aberration'), findsOneWidget);

          // Switch to Values tab while on Face 2
          await tester.tap(find.byKey(const Key('card_detail_tab_values')));
          await tester.pumpAndSettle();

          // Hero should STILL show Face 2 (Insectile Aberration)
          expect(find.text('Insectile Aberration'), findsOneWidget);

          // Switch back to Details tab
          await tester.tap(find.byKey(const Key('card_detail_tab_details')));
          await tester.pumpAndSettle();

          // Hero must still show Face 2
          expect(find.text('Insectile Aberration'), findsOneWidget);
        },
      );

      testWidgets(
        '6.7 Unowned card with \$0.00 price, missing dynamic fields, and long name adds to vault cleanly',
        (tester) async {
          final edgeCard = createTestCard(
            id: 'edge-unowned-card',
            name:
                'Asmoranomardicadaistinaculdacar with Extremely Extended Name for Stress Testing',
            quantity: 0,
            acquiredPrice: 0.0,
            marketPrice: 0.0,
            manaCost: '',
            dynamicData: '{}',
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                vaultDaoProvider.overrideWithValue(db.vaultDao),
              ],
              child: MaterialApp(
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => CardDetailSheet.show(ctx, edgeCard),
                        child: const Text('Open Edge Card Sheet'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Edge Card Sheet'));
          await tester.pumpAndSettle();

          final addBtnFinder = find.byKey(
            const Key('card_detail_add_to_vault'),
          );
          expect(addBtnFinder, findsOneWidget);

          await tester.tap(addBtnFinder);
          await tester.pumpAndSettle();

          expect(find.byType(CardDetailSheet), findsNothing);
          final item = await db.vaultDao.getItemById('edge-unowned-card');
          expect(item, isNotNull);
          expect(item!.quantity, equals(1));
        },
      );

      testWidgets(
        '6.8 Unowned card on compact 320x568 viewport at 2.0x text scale renders Add to Vault and responds to tap without overflow',
        (tester) async {
          configureViewport(tester, width: 320, height: 568);

          final unownedCard = createTestCard(
            id: 'unowned-compact-a11y',
            name: 'Ragavan, Nimble Pilferer',
            quantity: 0,
            marketPrice: 42.00,
          );

          final List<FlutterErrorDetails> errors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            originalOnError?.call(details);
          };

          try {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  vaultDaoProvider.overrideWithValue(db.vaultDao),
                ],
                child: MaterialApp(
                  home: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(320, 568),
                      textScaler: TextScaler.linear(2.0),
                    ),
                    child: Builder(
                      builder: (ctx) => Scaffold(
                        body: Center(
                          child: ElevatedButton(
                            onPressed: () =>
                                CardDetailSheet.show(ctx, unownedCard),
                            child: const Text('Open'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();

            final addBtnFinder = find.byKey(
              const Key('card_detail_add_to_vault'),
            );
            expect(addBtnFinder, findsOneWidget);

            await tester.tap(addBtnFinder);
            await tester.pumpAndSettle();

            final overflows = errors
                .where((e) => e.exceptionAsString().contains('overflowed'))
                .toList();
            expect(overflows, isEmpty);

            final item = await db.vaultDao.getItemById('unowned-compact-a11y');
            expect(item, isNotNull);
            expect(item!.quantity, equals(1));
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    },
  );
}
