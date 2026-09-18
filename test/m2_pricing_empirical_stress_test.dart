import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

VaultItem createHarnessCard({
  required String id,
  required String name,
  int quantity = 1,
  double currentMarketPrice = 0.0,
  double acquiredPrice = 0.0,
  dynamic dynamicPayload,
}) {
  final String dynString = dynamicPayload is String
      ? dynamicPayload
      : jsonEncode(dynamicPayload ?? {});

  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'MH3',
    imageUrl: '',
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2026, 9, 18),
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 18),
    dynamicData: dynString,
  );
}

Widget wrapHarness(
  Widget child, {
  AppDatabase? db,
  UserPersona persona = UserPersona.investor,
}) {
  final database = db ?? AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      vaultDaoProvider.overrideWithValue(database.vaultDao),
      userPersonaProvider.overrideWith((ref) => persona),
      cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
      activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 2 Pricing Logic Empirical Stress Tests', () {
    // =========================================================================
    // 1. ALL CURRENCIES NULL / MISSING PERMUTATIONS
    // =========================================================================
    group('1. Null / Missing Currency Permutations', () {
      test('1.1: null prices map returns 0.0', () {
        expect(VaultPricingHelper.resolveHierarchicalPrice(null), equals(0.0));
      });

      test('1.2: empty prices map returns 0.0', () {
        expect(VaultPricingHelper.resolveHierarchicalPrice({}), equals(0.0));
      });

      test('1.3: all 5 canonical keys explicitly null returns 0.0', () {
        final prices = {
          'usd': null,
          'usd_foil': null,
          'usd_etched': null,
          'eur': null,
          'eur_foil': null,
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(0.0));
      });

      test('1.4: map with unrelated keys and null canonical keys returns 0.0', () {
        final prices = {
          'tix': '0.02',
          'usd': null,
          'usd_foil': null,
          'usd_etched': null,
          'eur': null,
          'eur_foil': null,
          'unknown_currency': '99.99',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(0.0));
      });
    });

    // =========================================================================
    // 2. STRING ZEROS & SHORT-CIRCUIT PERMUTATIONS
    // =========================================================================
    group('2. String Zeros and Short-Circuit Prevention', () {
      final zeroVariants = [
        '0',
        '0.0',
        '0.00',
        '0.000',
        '0.0000',
        '-0',
        '-0.0',
        '-0.00',
        '+0',
        '+0.00',
        ' 0 ',
        ' 0.00 ',
        '\t0.00\n',
      ];

      for (final zeroStr in zeroVariants) {
        test('2.1: parsePositivePrice returns null for "$zeroStr"', () {
          expect(VaultPricingHelper.parsePositivePrice(zeroStr), isNull);
        });
      }

      test('2.2: all 5 keys containing zero variants resolves to 0.0', () {
        final prices = {
          'usd': '0',
          'usd_foil': '0.00',
          'usd_etched': '0.000',
          'eur': '-0.00',
          'eur_foil': ' 0.00 ',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(0.0));
      });

      test('2.3: zero in higher-tier currency falls through to every subsequent tier', () {
        // usd is '0.00', usd_foil is valid
        expect(
          VaultPricingHelper.resolveHierarchicalPrice({
            'usd': '0.00',
            'usd_foil': '11.11',
          }),
          equals(11.11),
        );

        // usd is '0.000', usd_foil is '0.0', usd_etched is valid
        expect(
          VaultPricingHelper.resolveHierarchicalPrice({
            'usd': '0.000',
            'usd_foil': '0.0',
            'usd_etched': '22.22',
          }),
          equals(22.22),
        );

        // usd, foil, etched are zero variants, eur is valid
        expect(
          VaultPricingHelper.resolveHierarchicalPrice({
            'usd': '-0.00',
            'usd_foil': '0',
            'usd_etched': ' 0.00 ',
            'eur': '33.33',
          }),
          equals(33.33),
        );

        // usd, foil, etched, eur are zero variants, eur_foil is valid
        expect(
          VaultPricingHelper.resolveHierarchicalPrice({
            'usd': '0.00',
            'usd_foil': '0.000',
            'usd_etched': '0.0',
            'eur': '0',
            'eur_foil': '44.44',
          }),
          equals(44.44),
        );
      });
    });

    // =========================================================================
    // 3. NEGATIVE NUMBERS PERMUTATIONS
    // =========================================================================
    group('3. Negative Numbers Permutations', () {
      final negativeVariants = [
        '-0.01',
        '-1',
        '-1.00',
        '-10.50',
        '-99999.99',
        '-1e2',
        '-1e-5',
        ' -50.00 ',
        -0.01,
        -10,
        -100.5,
      ];

      for (final neg in negativeVariants) {
        test('3.1: parsePositivePrice returns null for negative $neg', () {
          expect(VaultPricingHelper.parsePositivePrice(neg), isNull);
        });
      }

      test('3.2: negative in higher-tier currency falls through to subsequent tiers', () {
        final prices = {
          'usd': '-15.00',
          'usd_foil': '-0.50',
          'usd_etched': '29.99',
          'eur': '19.00',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(29.99));
      });

      test('3.3: all negative prices resolves to 0.0', () {
        final prices = {
          'usd': '-10.00',
          'usd_foil': '-20.00',
          'usd_etched': '-30.00',
          'eur': '-40.00',
          'eur_foil': '-50.00',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(0.0));
      });
    });

    // =========================================================================
    // 4. STRINGS WITH CURRENCY SYMBOLS ('$10.50')
    // =========================================================================
    group('4. Strings with Currency Symbols', () {
      final symbolStrings = [
        r'$10.50',
        r'$ 10.50',
        r' $10.50 ',
        r'$0.00',
        r'$-10.50',
        '€10.50',
        '£10.50',
        '10.50 USD',
        r'10.50$',
      ];

      for (final sym in symbolStrings) {
        test('4.1: parsePositivePrice safely returns null without throwing on "$sym"', () {
          expect(() => VaultPricingHelper.parsePositivePrice(sym), returnsNormally);
          expect(VaultPricingHelper.parsePositivePrice(sym), isNull);
        });
      }

      test('4.2: currency symbol string in higher tier gracefully falls through to clean tier', () {
        final prices = {
          'usd': r'$10.50', // Non-standard symbol string
          'usd_foil': '14.75', // Clean standard Scryfall string
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(14.75));
      });

      test('4.3: all symbol-corrupted keys gracefully resolve to 0.0 (Unlisted) without crash', () {
        final prices = {
          'usd': r'$10.50',
          'usd_foil': r'$20.00',
          'usd_etched': r'$30.00',
          'eur': '€40.00',
          'eur_foil': '£50.00',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(prices), equals(0.0));
      });
    });

    // =========================================================================
    // 5. SCIENTIFIC NOTATION & SPECIAL FLOATS
    // =========================================================================
    group('5. Scientific Notation & Special Float Permutations', () {
      test('5.1: Positive scientific notation parses correctly to positive double', () {
        expect(VaultPricingHelper.parsePositivePrice('1e2'), equals(100.0));
        expect(VaultPricingHelper.parsePositivePrice('1.5e1'), equals(15.0));
        expect(VaultPricingHelper.parsePositivePrice('2.5E+2'), equals(250.0));
        expect(VaultPricingHelper.parsePositivePrice('1e-2'), equals(0.01));
        expect(VaultPricingHelper.parsePositivePrice(1e2), equals(100.0));
      });

      test('5.2: Zero or negative scientific notation returns null', () {
        expect(VaultPricingHelper.parsePositivePrice('0e0'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('0e5'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('-1e2'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('-1.5e-3'), isNull);
      });

      test('5.3: NaN, Infinity, -Infinity strings and doubles return null', () {
        expect(VaultPricingHelper.parsePositivePrice('NaN'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('nan'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('Infinity'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('-Infinity'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('1e999'), isNull); // overflows to Infinity
        expect(VaultPricingHelper.parsePositivePrice('-1e999'), isNull); // overflows to -Infinity
        expect(VaultPricingHelper.parsePositivePrice(double.nan), isNull);
        expect(VaultPricingHelper.parsePositivePrice(double.infinity), isNull);
        expect(VaultPricingHelper.parsePositivePrice(double.negativeInfinity), isNull);
      });

      test('5.4: Max finite double and min positive double return correctly', () {
        expect(VaultPricingHelper.parsePositivePrice(double.maxFinite), equals(double.maxFinite));
        expect(VaultPricingHelper.parsePositivePrice(double.minPositive), equals(double.minPositive));
      });
    });

    // =========================================================================
    // 6. SPACES & WHITESPACE PERMUTATIONS
    // =========================================================================
    group('6. Spaces & Whitespace Permutations', () {
      test('6.1: Leading, trailing, and mixed whitespace trimmed and parsed', () {
        expect(VaultPricingHelper.parsePositivePrice('   15.99   '), equals(15.99));
        expect(VaultPricingHelper.parsePositivePrice('\t\n 42.50 \r\n'), equals(42.50));
        expect(VaultPricingHelper.parsePositivePrice('  0.05  '), equals(0.05));
      });

      test('6.2: Internal spaces or broken numbers return null', () {
        expect(VaultPricingHelper.parsePositivePrice('1 5.99'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('15 . 99'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('15. 99'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('15 .99'), isNull);
        expect(VaultPricingHelper.parsePositivePrice('   '), isNull);
        expect(VaultPricingHelper.parsePositivePrice(''), isNull);
      });
    });

    // =========================================================================
    // 7. CORRUPTED JSON & DYNAMIC DATA EDGE CASES
    // =========================================================================
    group('7. Corrupted JSON & Dynamic Data Extraction', () {
      test('7.1: Non-string and non-map inputs return 0.0 without throwing', () {
        expect(VaultPricingHelper.extractFromDynamicData(null), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData(12345), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData(true), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData([1, 2, 3]), equals(0.0));
      });

      test('7.2: Corrupted or truncated JSON strings return 0.0 without throwing', () {
        expect(VaultPricingHelper.extractFromDynamicData('NOT_A_JSON'), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData('{ "prices": '), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData('{"prices": [1, 2, 3]}'), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData('{"prices": "50.00"}'), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData('{"prices": null}'), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData(''), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData('    '), equals(0.0));
      });

      test('7.3: Deeply corrupted values inside prices map return 0.0', () {
        final corruptedMap = {
          'prices': {
            'usd': {'nested': 'object'},
            'usd_foil': [1, 2, 3],
            'usd_etched': true,
            'eur': null,
            'eur_foil': 'not_a_number',
          },
        };
        expect(VaultPricingHelper.extractFromDynamicData(corruptedMap), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData(jsonEncode(corruptedMap)), equals(0.0));
      });

      test('7.4: Direct numeric types inside JSON (num/int/double) parse correctly', () {
        final numericMap = {
          'prices': {
            'usd': 15.50,
            'usd_foil': 25,
          },
        };
        expect(VaultPricingHelper.extractFromDynamicData(numericMap), equals(15.50));
      });

      test('7.5: Card faces fallback in dynamicData when top-level prices missing', () {
        // Multi-faced card where prices exist only in first card_face
        final dfcData = {
          'card_faces': [
            {
              'name': 'Front Face',
              'prices': {
                'usd': '0.00',
                'usd_foil': '37.50',
              },
            },
            {
              'name': 'Back Face',
              'prices': {
                'usd': '10.00',
              },
            },
          ],
        };
        expect(VaultPricingHelper.extractFromDynamicData(dfcData), equals(37.50));
      });

      test('7.6: Card faces corrupted list handles gracefully', () {
        expect(VaultPricingHelper.extractFromDynamicData({'card_faces': []}), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData({'card_faces': [null]}), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData({'card_faces': ['string_face']}), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData({'card_faces': [{}]}), equals(0.0));
        expect(VaultPricingHelper.extractFromDynamicData({'card_faces': [{'prices': null}]}), equals(0.0));
      });
    });

    // =========================================================================
    // 8. EXHAUSTIVE 32-CASE BINARY TRUTH TABLE: FALLBACK HIERARCHY
    // =========================================================================
    group('8. Exhaustive 32-Case Fallback Hierarchy Truth Table', () {
      // Tiers and their canonical priority:
      // Index 0: 'usd'        (Priority 1, Price = 10.0)
      // Index 1: 'usd_foil'   (Priority 2, Price = 20.0)
      // Index 2: 'usd_etched' (Priority 3, Price = 30.0)
      // Index 3: 'eur'        (Priority 4, Price = 40.0)
      // Index 4: 'eur_foil'   (Priority 5, Price = 50.0)
      final keys = VaultPricingHelper.pricingHierarchy;
      final tierPrices = [10.0, 20.0, 30.0, 40.0, 50.0];

      for (int mask = 0; mask < 32; mask++) {
        final maskStr = mask.toRadixString(2).padLeft(5, '0');
        test('8.1: Mask $maskStr ($mask/31) strictly obeys hierarchy priority', () {
          final prices = <String, dynamic>{};
          double expectedPrice = 0.0;

          // Populate map based on mask bits
          for (int i = 0; i < 5; i++) {
            final isEnabled = (mask & (1 << (4 - i))) != 0;
            if (isEnabled) {
              prices[keys[i]] = tierPrices[i].toStringAsFixed(2);
              // Expected price is the first enabled tier
              if (expectedPrice == 0.0) {
                expectedPrice = tierPrices[i];
              }
            } else {
              // Test both null and '0.00' randomly across disabled bits
              prices[keys[i]] = (i % 2 == 0) ? '0.00' : null;
            }
          }

          final actualPrice = VaultPricingHelper.resolveHierarchicalPrice(prices);
          expect(
            actualPrice,
            equals(expectedPrice),
            reason: 'Failed for binary mask $maskStr: expected $expectedPrice, got $actualPrice',
          );
        });
      }
    });

    // =========================================================================
    // 9. VAULTITEM EFFECTIVE MARKET PRICE PRECEDENCE
    // =========================================================================
    group('9. VaultItem Effective Market Price Precedence', () {
      test('9.1: Positive currentMarketPrice strictly overrides dynamicData prices', () {
        final item = createHarnessCard(
          id: 'p1',
          name: 'Override Test Card',
          currentMarketPrice: 77.50,
          dynamicPayload: {
            'prices': {'usd': '12.00', 'usd_foil': '25.00'},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(item), equals(77.50));
        expect(item.effectiveMarketPrice, equals(77.50));
      });

      test('9.2: 0.0 currentMarketPrice falls back to dynamicData prices', () {
        final item = createHarnessCard(
          id: 'p2',
          name: 'Fallback Test Card',
          currentMarketPrice: 0.0,
          dynamicPayload: {
            'prices': {'usd': '0.00', 'usd_foil': '34.20'},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(item), equals(34.20));
        expect(item.effectiveMarketPrice, equals(34.20));
      });

      test('9.3: Negative currentMarketPrice falls back to dynamicData prices', () {
        final item = createHarnessCard(
          id: 'p3',
          name: 'Negative SQLite Price Card',
          currentMarketPrice: -5.00,
          dynamicPayload: {
            'prices': {'usd': '18.90'},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(item), equals(18.90));
      });

      test('9.4: NaN or Infinity currentMarketPrice falls back to dynamicData prices', () {
        final itemNan = createHarnessCard(
          id: 'p4-nan',
          name: 'NaN Price Card',
          currentMarketPrice: double.nan,
          dynamicPayload: {
            'prices': {'usd': '21.00'},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(itemNan), equals(21.00));

        final itemInf = createHarnessCard(
          id: 'p4-inf',
          name: 'Infinity Price Card',
          currentMarketPrice: double.infinity,
          dynamicPayload: {
            'prices': {'usd': '29.00'},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(itemInf), equals(29.00));
      });

      test('9.5: Both currentMarketPrice <= 0 and dynamicData unpriced yields 0.0', () {
        final item = createHarnessCard(
          id: 'p5',
          name: 'Completely Unpriced Card',
          currentMarketPrice: 0.0,
          dynamicPayload: {
            'prices': {'usd': '0.00', 'usd_foil': null},
          },
        );
        expect(VaultPricingHelper.resolveEffectiveMarketPrice(item), equals(0.0));
      });
    });

    // =========================================================================
    // 10. FORMATTING GUARANTEES & STRICT ELIMINATION OF "CHECK"
    // =========================================================================
    group('10. Formatting Guarantees & Absence of "Check"', () {
      final testPrices = [
        0.0,
        -0.0,
        -1.0,
        -999.99,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final p in testPrices) {
        test('10.1: formatMarketPriceLabel for $p returns "Unlisted" and NEVER "Check"', () {
          final label = VaultPricingHelper.formatMarketPriceLabel(p);
          expect(label, equals('Unlisted'));
          expect(label.toLowerCase().contains('check'), isFalse);
        });

        test('10.2: formatMarketHeaderLabel for $p returns "Market: Unlisted" and NEVER "Check"', () {
          final header = VaultPricingHelper.formatMarketHeaderLabel(p);
          expect(header, equals('Market: Unlisted'));
          expect(header.toLowerCase().contains('check'), isFalse);
        });
      }

      test('10.3: formatMarketPriceLabel with custom fallback returns custom fallback', () {
        expect(VaultPricingHelper.formatMarketPriceLabel(0.0, fallback: '—'), equals('—'));
        expect(VaultPricingHelper.formatMarketHeaderLabel(0.0, fallback: '—'), equals('Market: —'));
      });

      test('10.4: Valid positive prices formatted with exact 2 decimal places', () {
        expect(VaultPricingHelper.formatMarketPriceLabel(1.0), equals(r'$1.00'));
        expect(VaultPricingHelper.formatMarketPriceLabel(12.5), equals(r'$12.50'));
        expect(VaultPricingHelper.formatMarketPriceLabel(0.01), equals(r'$0.01'));
        expect(VaultPricingHelper.formatMarketPriceLabel(1234567.89), equals(r'$1234567.89'));

        expect(VaultPricingHelper.formatMarketHeaderLabel(12.5), equals(r'Market: $12.50'));
      });
    });

    // =========================================================================
    // 11. WIDGET ADVERSARIAL STRESS: CORRUPTED DATA ACROSS PRESENTATION
    // =========================================================================
    group('11. Widget Adversarial Stress Tests with Malformed Data', () {
      testWidgets('11.1: VaultItemTile under all corrupted price inputs renders "Unlisted" and NEVER "Check"', (tester) async {
        final corruptedInputs = [
          {'usd': r'$10.50'}, // Currency symbol
          {'usd': '-100.00'}, // Negative
          {'usd': '0.000'}, // Multiple zero decimals
          {'usd': '   '}, // Whitespace
          {'usd': 'NaN'}, // Special float
          {'usd': '1e999'}, // Overflow to infinity
        ];

        for (int i = 0; i < corruptedInputs.length; i++) {
          final card = createHarnessCard(
            id: 'corrupted-tile-$i',
            name: 'Corrupted Tile $i',
            quantity: 1,
            currentMarketPrice: 0.0,
            dynamicPayload: {'prices': corruptedInputs[i]},
          );

          await tester.pumpWidget(wrapHarness(
            SizedBox(width: 140, height: 200, child: VaultItemTile(item: card)),
          ));
          await tester.pumpAndSettle();

          expect(find.text('Unlisted'), findsOneWidget, reason: 'Failed for input ${corruptedInputs[i]}');
          expect(find.textContaining('Check'), findsNothing, reason: 'Check found for input ${corruptedInputs[i]}');
        }
      });

      testWidgets('11.2: VaultItemCard under all corrupted price inputs renders "Unlisted" and NEVER "Check"', (tester) async {
        final card = createHarnessCard(
          id: 'corrupted-card-1',
          name: 'Corrupted Card Investor',
          quantity: 0,
          currentMarketPrice: -1.0,
          dynamicPayload: 'COMPLETELY_MALFORMED_JSON_STRING!@#\$%',
        );

        await tester.pumpWidget(wrapHarness(
          VaultItemCard(item: card, persona: UserPersona.investor),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Unlisted'), findsOneWidget);
        expect(find.textContaining('Check'), findsNothing);
      });

      testWidgets('11.3: CardDetailSheet under corrupted JSON displays "Market: Unlisted" with zero errors', (tester) async {
        final card = createHarnessCard(
          id: 'corrupted-sheet-1',
          name: 'Corrupted Detail Card',
          quantity: 1,
          currentMarketPrice: 0.0,
          dynamicPayload: '{"prices": "invalid"}',
        );

        await tester.pumpWidget(wrapHarness(
          CardDetailSheet(item: card),
          db: db,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Market: Unlisted'), findsOneWidget);
        expect(find.textContaining('Check'), findsNothing);
      });

      testWidgets('11.4: FullScreenCardViewer under corrupted JSON renders cleanly without throwing', (tester) async {
        final card = createHarnessCard(
          id: 'corrupted-fs-1',
          name: 'Corrupted FullScreen Card',
          quantity: 1,
          currentMarketPrice: 0.0,
          dynamicPayload: '{"prices": null, "card_faces": [null]}',
        );

        await tester.pumpWidget(wrapHarness(
          FullScreenCardViewer(item: card),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Check'), findsNothing);
      });
    });
  });
}
