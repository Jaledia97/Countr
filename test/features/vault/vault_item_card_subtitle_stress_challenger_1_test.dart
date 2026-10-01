import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Replicates the exact subtitle row from VaultItemCard line 299-378 to directly stress-test
/// BUG-M1-RESPONSIVE-01 in complete isolation under pure horizontal constraints.
Widget buildExactSubtitleRow({
  required String setAndNameText,
  required String rarity,
  required Color rarityColor,
  required String typeLine,
  required double effectivePrice,
  required bool isPrivacyMode,
  required UserPersona activePersona,
  required bool isExpanded,
}) {
  return Row(
    children: [
      Expanded(
        child: Text(
          setAndNameText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9E9E9E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (rarity.isNotEmpty) ...[
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: rarityColor.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: rarityColor,
                ),
              ),
            ),
          ),
        ),
      ],
      if (typeLine.isNotEmpty) ...[
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            typeLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF757575),
            ),
          ),
        ),
      ],
      if (activePersona != UserPersona.player && !isExpanded) ...[
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isPrivacyMode
                  ? '****'
                  : (effectivePrice > 0
                      ? '\$${effectivePrice.toStringAsFixed(2)}'
                      : 'Unlisted'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem buildTestVaultItem({
    String id = 'vault-test-item-1',
    String name = 'The One Ring',
    String? flavorName,
    String setOrSeries = 'LTR',
    String rarity = 'mythic',
    String typeLine = 'Legendary Artifact',
    double currentMarketPrice = 2000000.0,
    int quantity = 1,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: flavorName,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: 100.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: '{"rarity":"$rarity","type_line":"$typeLine","mana_cost":"{4}"}',
    );
  }

  group('Pillar 1: Isolated Subtitle Row Elasticity (120px to 400px, 2.0x to 3.0x scales)', () {
    final widths = [120.0, 140.0, 160.0, 180.0, 200.0, 250.0, 300.0, 320.0, 360.0, 390.0, 400.0];
    final textScales = [2.0, 2.5, 3.0];

    for (final scale in textScales) {
      for (final width in widths) {
        testWidgets('Subtitle row does not overflow at ${width.toInt()}px under ${scale}x scale (Extreme text lengths)', (tester) async {
          final List<FlutterErrorDetails> overflowErrors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
              overflowErrors.add(details);
            }
          };

          try {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: buildExactSubtitleRow(
                          setAndNameText: '[Ash Nazg durbatuluk] • Universes Beyond: The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
                          rarity: 'mythic rare special',
                          rarityColor: Colors.deepOrange,
                          typeLine: 'Legendary Artifact — Ring of Power Equipment',
                          effectivePrice: 2000000.0,
                          isPrivacyMode: false,
                          activePersona: UserPersona.investor,
                          isExpanded: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pumpAndSettle();

            expect(
              overflowErrors,
              isEmpty,
              reason: 'RenderFlex overflow in isolated subtitle row at ${width}px, ${scale}x',
            );
          } finally {
            FlutterError.onError = originalOnError;
          }
        });
      }
    }
  });

  group('Pillar 2: Full VaultItemCard Widget in List Mode across Widths (200px to 400px)', () {
    // Tests VaultItemCard across realistic and extreme card widths down to 200px.
    // (Note: On mobile, minimum screen width is 320px. At <185px card width, outer ListTile chrome
    // leaves <14px for subtitle, encountering the 14px spacer threshold).
    final widths = [200.0, 240.0, 280.0, 320.0, 360.0, 390.0, 400.0];
    final textScales = [2.0, 2.5, 3.0];

    for (final scale in textScales) {
      for (final width in widths) {
        testWidgets('VaultItemCard renders with zero RenderFlex overflow at ${width.toInt()}px under ${scale}x scale', (tester) async {
          final List<FlutterErrorDetails> overflowErrors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
              overflowErrors.add(details);
            }
          };

          try {
            final item = buildTestVaultItem(
              name: 'The One Ring',
              flavorName: 'Ash Nazg durbatuluk',
              setOrSeries: 'Tales of Middle-earth',
              rarity: 'mythic',
              typeLine: 'Legendary Artifact',
              currentMarketPrice: 2000000.0,
            );

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: VaultItemCard(
                          item: item,
                          persona: UserPersona.investor,
                          isPrivacyMode: false,
                          initiallyExpanded: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pumpAndSettle();

            if (overflowErrors.isNotEmpty) {
              debugPrint('OVERFLOW DETECTED: width=$width, scale=$scale, error=${overflowErrors.first.exception}');
            }
            expect(
              overflowErrors,
              isEmpty,
              reason: 'RenderFlex overflow in VaultItemCard at ${width}px, ${scale}x: ${overflowErrors.map((e) => e.exception).toList()}',
            );
          } finally {
            FlutterError.onError = originalOnError;
          }
        });
      }
    }
  });

  group('Pillar 3: VaultScreen Complete List Layout under 2.0x, 2.5x, 3.0x on Real Viewports', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createScreenHarness({
      required double width,
      required double height,
      required double textScale,
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          userPersonaProvider.overrideWith((ref) => UserPersona.investor),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const VaultScreen(),
          ),
        ),
      );
    }

    final screenWidths = [320.0, 360.0, 390.0, 400.0];
    final screenScales = [2.0, 2.5, 3.0];

    for (final scale in screenScales) {
      for (final width in screenWidths) {
        testWidgets('VaultScreen List mode renders cleanly at ${width.toInt()}px with scale ${scale}x', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await db.vaultDao.seedDatabase();

          final List<FlutterErrorDetails> overflowErrors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex')) {
              overflowErrors.add(details);
            }
          };

          try {
            await tester.pumpWidget(createScreenHarness(
              width: width,
              height: 844,
              textScale: scale,
            ));
            await tester.pump();
            await tester.pumpAndSettle();

            // Switch to List layout
            final listBtn = find.byKey(const Key('vault_layout_list_button'));
            expect(listBtn, findsOneWidget);
            await tester.tap(listBtn);
            await tester.pumpAndSettle();

            // Verify VaultItemCard is mounted
            expect(find.byType(VaultItemCard), findsWidgets);

            // Assert zero RenderFlex overflows occurred
            expect(
              overflowErrors,
              isEmpty,
              reason: 'RenderFlex overflow in VaultScreen List layout at ${width}px, ${scale}x',
            );
          } finally {
            FlutterError.onError = originalOnError;
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 100));
        });
      }
    }
  });
}
