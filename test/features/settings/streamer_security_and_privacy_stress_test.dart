import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

class MockNavigationShell extends StatefulWidget implements StatefulNavigationShell {
  @override
  final int currentIndex;

  const MockNavigationShell({super.key, this.currentIndex = 0});

  @override
  void goBranch(int index, {bool initialLocation = false}) {}

  @override
  State<MockNavigationShell> createState() => _MockNavigationShellState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNavigationShellState extends State<MockNavigationShell> {
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('mock_nav_body'));
}

VaultItem createStressItem({
  String id = 'stress_1',
  String name = 'Black Lotus',
  double currentMarketPrice = 9876.54,
  double acquiredPrice = 1234.56,
  int quantity = 2,
}) {
  return VaultItem(
    id: id,
    collectionType: 'mtg',
    name: name,
    setOrSeries: 'LEA',
    imageUrl: 'https://example.com/lotus.jpg',
    quantity: quantity,
    condition: 'NM',
    isGraded: true,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    acquiredPrice: acquiredPrice,
    acquiredDate: DateTime(2020, 1, 1),
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2026, 9, 24),
    dynamicData:
        '{"prices":{"usd":"${currentMarketPrice.toStringAsFixed(2)}"},"power":"0","toughness":"0","mana_cost":"{0}","oracle_text":"Add three mana of any one color."}',
  );
}

/// Helper executing valid Flutter lifecycle state machine transitions.
///
/// In Flutter 3.13+, transitions must follow state machine edges:
/// resumed <-> inactive <-> hidden <-> paused
void transitionLifecycle(WidgetTester tester, AppLifecycleState target) {
  final current = tester.binding.lifecycleState ?? AppLifecycleState.resumed;
  if (current == target) return;

  if (target == AppLifecycleState.paused) {
    if (current == AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    } else if (current == AppLifecycleState.inactive) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  } else if (target == AppLifecycleState.resumed) {
    if (current == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    } else if (current == AppLifecycleState.hidden) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  } else if (target == AppLifecycleState.inactive) {
    if (current == AppLifecycleState.paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  } else if (target == AppLifecycleState.hidden) {
    if (current == AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empirical Challenge 1: AppLifecycleState Rapid Transitions Stress Harness', () {
    testWidgets(
      'Rapid sequence of paused -> resumed -> inactive -> hidden -> resumed preserves lock until explicitly unlocked',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Streamer security enabled, privacy mode initially OFF
        container.read(streamerSecurityEnabledProvider.notifier).state = true;
        container.read(privacyModeProvider.notifier).state = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MainShellScreen(
                navigationShell: MockNavigationShell(),
              ),
            ),
          ),
        );

        expect(container.read(privacyModeProvider), isFalse,
            reason: 'Privacy mode should be initially false.');

        // Step 1: Paused -> triggers privacy mode lock
        transitionLifecycle(tester, AppLifecycleState.paused);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Paused state must lock privacy mode.');

        // Step 2: Resumed -> MUST STAY LOCKED
        transitionLifecycle(tester, AppLifecycleState.resumed);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Resuming to foreground must NOT auto-unlock privacy mode.');

        // Step 3: Inactive -> stays locked
        transitionLifecycle(tester, AppLifecycleState.inactive);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Inactive state must retain privacy mode.');

        // Step 4: Hidden -> stays locked
        transitionLifecycle(tester, AppLifecycleState.hidden);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Hidden state must retain privacy mode.');

        // Step 5: Resumed again -> MUST STILL STAY LOCKED
        transitionLifecycle(tester, AppLifecycleState.resumed);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Final resumed state must strictly keep privacy mode locked.');

        // Step 6: Explicit user unlock
        container.read(privacyModeProvider.notifier).state = false;
        await tester.pump();
        expect(container.read(privacyModeProvider), isFalse,
            reason: 'Explicit unlock by user must deactivate privacy mode.');

        // Step 7: Subsequent background transition immediately re-locks
        transitionLifecycle(tester, AppLifecycleState.inactive);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'New background event must re-lock privacy mode.');
      },
    );

    testWidgets(
      'Pathological rapid state flapping (100 transitions) maintains stability and correct lock semantics',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(streamerSecurityEnabledProvider.notifier).state = true;
        container.read(privacyModeProvider.notifier).state = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MainShellScreen(
                navigationShell: MockNavigationShell(),
              ),
            ),
          ),
        );

        final rng = Random(42);
        final targets = [
          AppLifecycleState.resumed,
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ];

        bool everBackgrounded = false;

        for (int i = 0; i < 100; i++) {
          final nextTarget = targets[rng.nextInt(targets.length)];
          if (nextTarget == AppLifecycleState.inactive ||
              nextTarget == AppLifecycleState.paused ||
              nextTarget == AppLifecycleState.hidden) {
            everBackgrounded = true;
          }
          transitionLifecycle(tester, nextTarget);
          if (i % 5 == 0) {
            await tester.pump();
          }

          if (everBackgrounded) {
            expect(container.read(privacyModeProvider), isTrue,
                reason:
                    'Iteration $i: Privacy mode must remain locked once backgrounded.');
          }
        }

        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue);
      },
    );

    testWidgets(
      'Immunity: When Streamer Security is disabled, transitions never alter privacy mode',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(streamerSecurityEnabledProvider.notifier).state = false;
        container.read(privacyModeProvider.notifier).state = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MainShellScreen(
                navigationShell: MockNavigationShell(),
              ),
            ),
          ),
        );

        final sequence = [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
          AppLifecycleState.paused,
          AppLifecycleState.resumed,
        ];

        for (final target in sequence) {
          transitionLifecycle(tester, target);
          await tester.pump();
          expect(container.read(privacyModeProvider), isFalse,
              reason: 'State $target should not trigger privacy mode when streamer security is disabled.');
        }
      },
    );

    testWidgets(
      'Mid-session toggle of Streamer Security from enabled to disabled does NOT unlock active privacy mode',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(streamerSecurityEnabledProvider.notifier).state = true;
        container.read(privacyModeProvider.notifier).state = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MainShellScreen(
                navigationShell: MockNavigationShell(),
              ),
            ),
          ),
        );

        // Lock via paused
        transitionLifecycle(tester, AppLifecycleState.paused);
        await tester.pump();
        expect(container.read(privacyModeProvider), isTrue);

        // Disable streamer security mid-session
        container.read(streamerSecurityEnabledProvider.notifier).state = false;
        await tester.pump();

        // Return to resumed
        transitionLifecycle(tester, AppLifecycleState.resumed);
        await tester.pump();

        // Privacy mode must remain true
        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Disabling streamer security must not inadvertently unlock privacy mode.');
      },
    );
  });

  group('Empirical Challenge 2: App-Wide UI Redaction & Zero Numeric Leakage', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'VaultItemTile: Price badge displays **** and leaks zero numeric digits or currency symbols under privacy mode',
      (tester) async {
        final item = createStressItem(currentMarketPrice: 9876.54);

        for (final curr in AppCurrency.values) {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          container.read(privacyModeProvider.notifier).state = true;
          container.read(baseCurrencyProvider.notifier).state = curr;

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 150,
                    height: 220,
                    child: VaultItemTile(item: item),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Exactly one price badge displaying '****'
          expect(find.text('****'), findsOneWidget,
              reason: 'Tile must display **** badge for currency ${curr.code}');

          // Zero numeric leakage check: verify no text widget contains raw or formatted price fragments
          final textWidgets = tester.widgetList<Text>(find.byType(Text));
          for (final t in textWidgets) {
            final content = t.data ?? '';
            expect(content.contains('9876'), isFalse,
                reason: 'Numeric leakage found in VaultItemTile: "$content" contains 9876');
            expect(content.contains('54'), isFalse,
                reason: 'Cents leakage found in VaultItemTile: "$content" contains 54');
          }
        }
      },
    );

    testWidgets(
      'VaultItemCard (Investor Persona): Strictly masks Acquired, Live TMV, and P&L with **** and zero numeric leaks',
      (tester) async {
        final item = createStressItem(
          acquiredPrice: 1234.56,
          currentMarketPrice: 9876.54,
          quantity: 2,
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(privacyModeProvider.notifier).state = true;
        container.read(userPersonaProvider.notifier).state = UserPersona.investor;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: VaultItemCard(
                  item: item,
                  persona: UserPersona.investor,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // There must be 3 '****' instances: Acquired, Live TMV, and P&L
        expect(find.text('****'), findsNWidgets(3),
            reason: 'Investor row must display 3 **** masks for Acquired, TMV, and P&L.');

        // Zero numeric leakage check across all Text widgets
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in textWidgets) {
          final content = t.data ?? '';
          expect(content.contains('1234'), isFalse,
              reason: 'Acquired price leakage in VaultItemCard: "$content"');
          expect(content.contains('9876'), isFalse,
              reason: 'TMV price leakage in VaultItemCard: "$content"');
          expect(content.contains('8641'), isFalse,
              reason: 'Delta dollar leakage in VaultItemCard: "$content"');
          expect(content.contains('700.'), isFalse,
              reason: 'Percentage return leakage in VaultItemCard: "$content"');
        }

        // Toggling privacy mode OFF restores exact financial figures
        container.read(privacyModeProvider.notifier).state = false;
        await tester.pumpAndSettle();

        expect(find.text('****'), findsNothing);
        expect(find.text(r'$1234.56'), findsOneWidget);
        expect(find.text(r'$9876.54'), findsOneWidget);
      },
    );

    testWidgets(
      'VaultItemCard (Catalog / Unowned): Masks Market Value to **** without leaking numbers',
      (tester) async {
        final catalogItem = createStressItem(
          quantity: 0,
          currentMarketPrice: 777.77,
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(privacyModeProvider.notifier).state = true;
        container.read(userPersonaProvider.notifier).state = UserPersona.investor;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: VaultItemCard(
                  item: catalogItem,
                  persona: UserPersona.investor,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('****'), findsOneWidget);
        expect(find.text('CATALOG / UNOWNED'), findsOneWidget);

        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in textWidgets) {
          final content = t.data ?? '';
          expect(content.contains('777'), isFalse,
              reason: 'Catalog market value leakage: "$content"');
        }
      },
    );

    testWidgets(
      'CardDetailSheet: Redacts header pill, metric boxes, and share dialog to ****',
      (tester) async {
        final item = createStressItem(
          currentMarketPrice: 852.00,
          acquiredPrice: 520.00,
          quantity: 1,
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);
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
                body: CardDetailSheet(
                  item: item,
                  fetchOnlinePrintings: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header pill must read "Market: ****"
        expect(find.text('Market: ****'), findsOneWidget);
        expect(find.text('Market: \$852.00'), findsNothing);

        // 2. Metric boxes for Acquired Price and Profit/Loss
        await tester.scrollUntilVisible(
          find.text('Acquired Price'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('****'), findsAtLeast(2));

        // 3. Test Share Dialog redaction
        final shareButton = find.byIcon(Icons.share_outlined);
        if (shareButton.evaluate().isNotEmpty) {
          await tester.tap(shareButton.first);
          await tester.pumpAndSettle();

          expect(find.text('Market Value: ****'), findsOneWidget);
          expect(find.textContaining('852'), findsNothing);

          // Close dialog
          await tester.tap(find.byKey(const Key('share_dialog_close')));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'EMPIRICAL BUG DETECTION: VariantPriceChart in CardDetailSheet leaks market price when privacy mode is active',
      (tester) async {
        final item = createStressItem(
          currentMarketPrice: 852.00,
          acquiredPrice: 520.00,
          quantity: 1,
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyModeProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: VariantPriceChart(
                  item: item,
                  enableOnlineFetch: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check whether VariantPriceChart masks price or leaks raw '$852.00'
        final leakedPriceFinder = find.text(r'$852.00');
        final maskedPriceFinder = find.text('****');

        // This test empirically documents whether VariantPriceChart redacts prices or leaks them.
        final bool leaksNumericPrice = leakedPriceFinder.evaluate().isNotEmpty;
        final bool masksWithStars = maskedPriceFinder.evaluate().isNotEmpty;

        debugPrint('[EMPIRICAL CHALLENGER] VariantPriceChart leakage test: leaksNumericPrice=$leaksNumericPrice, masksWithStars=$masksWithStars');

        // Verify privacy mode redaction:
        expect(leaksNumericPrice, isFalse,
            reason: 'VariantPriceChart must not leak raw market price when privacyModeProvider is active!');
        expect(masksWithStars, isTrue,
            reason: 'VariantPriceChart must mask market price with **** when privacyModeProvider is active!');
      },
    );

    testWidgets(
      'SwitchPrintingModal: Redacts active price, comparison was-price, and candidate prices under privacy mode',
      (tester) async {
        final item = createStressItem(
          currentMarketPrice: 852.00,
          acquiredPrice: 520.00,
          quantity: 1,
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyModeProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SwitchPrintingModal(item: item),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify active price is masked
        expect(find.text(r'$852.00'), findsNothing);
        expect(find.text('****'), findsAtLeast(1));

        // Zero numeric leakage check across all text
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in textWidgets) {
          final content = t.data ?? '';
          expect(content.contains('852'), isFalse,
              reason: 'Numeric leakage found in SwitchPrintingModal: "$content" contains 852');
        }
      },
    );

    testWidgets(
      'ManualAddBottomSheet: Redacts catalog card prices to **** under privacy mode',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);
        container.read(privacyModeProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ManualAddBottomSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify that any rendered prices are masked and zero cleartext prices appear
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in textWidgets) {
          final content = t.data ?? '';
          expect(content.contains(r'$'), isFalse,
              reason: 'Cleartext dollar price found in ManualAddBottomSheet: "$content"');
        }
      },
    );

    testWidgets(
      'VaultScreen: Redacts portfolio summary header to **** without leaking total value or return figures',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);
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

        // Portfolio summary card total and P&L return must be masked
        expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);
        expect(find.text('****'), findsAtLeast(1));

        // When toggling privacy mode via AppBar button, values unmask
        final toggleBtn = find.byKey(const Key('vault_privacy_mode_button'));
        expect(toggleBtn, findsOneWidget);

        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse,
            reason: 'Tapping AppBar privacy button must toggle privacy mode to false.');

        // Re-tap to re-enable privacy mode
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isTrue,
            reason: 'Tapping AppBar privacy button again must re-enable privacy mode.');
        expect(find.text('****'), findsAtLeast(1));
      },
    );
  });

  group('Empirical Challenge 3: LockedValuesView Verbatim Compliance & Interactive State', () {
    testWidgets(
      'LockedValuesView renders exact required copy: "Values hidden. Disable Privacy Mode to view market data."',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: LockedValuesView(),
              ),
            ),
          ),
        );

        // Verbatim copy verification
        const requiredText = 'Values hidden. Disable Privacy Mode to view market data.';
        expect(find.text(requiredText), findsOneWidget,
            reason: 'LockedValuesView must render the exact verbatim text required by specification.');

        // Lock icon verification
        expect(find.byKey(const Key('locked_values_lock_icon')), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

        // Unlock button verification
        expect(find.byKey(const Key('locked_values_disable_privacy_button')), findsOneWidget);
        expect(find.text('Disable Privacy Mode'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping unlock button in LockedValuesView reactively toggles privacyModeProvider to false',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(privacyModeProvider.notifier).state = true;
        expect(container.read(privacyModeProvider), isTrue);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: LockedValuesView(),
              ),
            ),
          ),
        );

        final unlockButton = find.byKey(const Key('locked_values_disable_privacy_button'));
        expect(unlockButton, findsOneWidget);

        await tester.tap(unlockButton);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse,
            reason: 'Tapping unlock button must set privacyModeProvider to false.');

        // Idempotent secondary tap
        await tester.tap(unlockButton);
        await tester.pumpAndSettle();

        expect(container.read(privacyModeProvider), isFalse,
            reason: 'Subsequent taps should maintain false state without error.');
      },
    );
  });
}
