import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

VaultItem createTestItem({
  String id = 'v1',
  String name = 'Mox Diamond',
  double currentMarketPrice = 650.00,
  double acquiredPrice = 450.00,
  int quantity = 1,
}) {
  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'STH',
    imageUrl: 'https://example.com/mox.jpg',
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime.now(),
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    dynamicData: '{"prices":{"usd":"${currentMarketPrice.toStringAsFixed(2)}"}}',
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('App-Wide Financial Data Redaction Tests', () {
    testWidgets('VaultItemCard: Shows real price when privacy mode is off', (tester) async {
      final item = createTestItem(currentMarketPrice: 650.00);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(
                item: item,
                isPrivacyMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$650.00'), findsAtLeast(1));
      expect(find.text('****'), findsNothing);
    });

    testWidgets('VaultItemCard: Redacts financial figures to **** when privacy mode is on', (tester) async {
      final item = createTestItem(currentMarketPrice: 650.00, acquiredPrice: 450.00);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(
                item: item,
                isPrivacyMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that **** is rendered and real monetary amounts are redacted
      expect(find.text('****'), findsAtLeast(1));
      expect(find.text(r'$650.00'), findsNothing);
      expect(find.text(r'$450.00'), findsNothing);
    });

    testWidgets('VaultItemTile: Shows real price badge when privacy mode is off', (tester) async {
      final item = createTestItem(currentMarketPrice: 125.00);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150,
                height: 220,
                child: VaultItemTile(
                  item: item,
                  isPrivacyMode: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$125.00'), findsOneWidget);
      expect(find.text('****'), findsNothing);
    });

    testWidgets('VaultItemTile: Redacts price badge to **** when privacy mode is on', (tester) async {
      final item = createTestItem(currentMarketPrice: 125.00);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150,
                height: 220,
                child: VaultItemTile(
                  item: item,
                  isPrivacyMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
      expect(find.text(r'$125.00'), findsNothing);
    });

    testWidgets('CardDetailSheet: Redacts market header and metric boxes when privacy mode is on', (tester) async {
      final item = createTestItem(currentMarketPrice: 85.00, acquiredPrice: 50.00);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      // Turn privacy mode ON
      container.read(privacyModeProvider.notifier).state = true;

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header pill should say "Market: ****"
      expect(find.text('Market: ****'), findsOneWidget);
      expect(find.text('Market: \$85.00'), findsNothing);

      // Scroll to ensure metrics boxes are fully rendered
      await tester.scrollUntilVisible(
        find.text('Acquired Price'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Financial metric boxes (Acquired Price & Profit/Loss) should display ****
      expect(find.text('****'), findsAtLeast(2));
    });

    testWidgets('VaultScreen: Redacts portfolio summary when privacy mode is on', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);

      // Start with privacy mode ON
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In portfolio summary card, total value and delta must be ****
      expect(find.text('****'), findsAtLeast(1));
    });
  });
}
