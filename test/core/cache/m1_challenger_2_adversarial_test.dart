import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FailedImageRegistry.instance.clear();
  });

  tearDown(() {
    FailedImageRegistry.instance.clear();
  });

  // ===========================================================================
  // Section 1: Loop Termination & Zero Timer Leaks
  // ===========================================================================
  group('Adversarial Stress 1: Loop Termination & Zero Timer Leaks', () {
    testWidgets('Terminal failed URL terminates loop: 50 rapid frames with 0 transient callbacks and 0 timers', (tester) async {
      const failedUrl = 'https://cards.scryfall.io/art/terminal_404.jpg';
      FailedImageRegistry.instance.markTerminal(
        failedUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );

      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return const CountrCachedImage(
                  imageUrl: failedUrl,
                  cardName: 'Terminal Card',
                  tcgDomain: 'other',
                  width: 100,
                  height: 140,
                  errorWidget: Text('LOCKED_ERROR'),
                );
              },
            ),
          ),
        ),
      );

      // Frame 0: error is rendered immediately
      expect(find.text('LOCKED_ERROR'), findsOneWidget);
      expect(buildCount, equals(1));
      expect(tester.binding.transientCallbackCount, equals(0));

      // Rapidly pump 50 frames (simulating 60fps frame delta = ~16ms each)
      for (int frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.binding.transientCallbackCount, equals(0));
      }

      await tester.pumpAndSettle();

      // Assert error state remained completely locked
      expect(find.text('LOCKED_ERROR'), findsOneWidget);
      // No post-frame cascade triggered rebuild of parent builder
      expect(buildCount, equals(1));
      // Zero pending transient callbacks or active timers
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('URL with exhausted retries locks into error: 50 rapid pumps maintain 0 timers and 0 requests', (tester) async {
      const exhaustedUrl = 'https://cards.scryfall.io/art/exhausted_retries.jpg';
      // Record 3 failed attempts to exhaust session retries
      FailedImageRegistry.instance.recordAttempt(exhaustedUrl, statusCode: 500);
      FailedImageRegistry.instance.recordAttempt(exhaustedUrl, statusCode: 500);
      FailedImageRegistry.instance.recordAttempt(exhaustedUrl, statusCode: 500);

      expect(FailedImageRegistry.instance.isFailed(exhaustedUrl), isTrue);
      expect(FailedImageRegistry.instance.getAttempts(exhaustedUrl), equals(3));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: exhaustedUrl,
              cardName: 'Exhausted Card',
              tcgDomain: 'other',
              width: 120,
              height: 160,
              errorWidget: Text('EXHAUSTED_ERROR'),
            ),
          ),
        ),
      );

      // Error appears immediately at frame 0
      expect(find.text('EXHAUSTED_ERROR'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));

      // Pump 50 frames rapidly
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(find.text('EXHAUSTED_ERROR'), findsOneWidget);
      // Attempts remain strictly capped at 3 (no background network requests fired)
      expect(FailedImageRegistry.instance.getAttempts(exhaustedUrl), equals(3));
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Empty and invalid scheme URLs short-circuit immediately without timer scheduling', (tester) async {
      final invalidUrls = [
        '',
        '   ',
        'ftp://example.com/art.jpg',
        'javascript:void(0)',
        'data:image/png;base64,invalid',
      ];

      for (final badUrl in invalidUrls) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: badUrl,
                cardName: 'Invalid Scheme Card',
                tcgDomain: 'other',
                width: 100,
                height: 140,
                errorWidget: const Text('INVALID_SCHEME_ERROR'),
              ),
            ),
          ),
        );

        // Frame 0 shows error
        expect(find.text('INVALID_SCHEME_ERROR'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, equals(0));

        // Rapidly pump 10 frames per bad URL
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        expect(find.text('INVALID_SCHEME_ERROR'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, equals(0));
      }
    });

    testWidgets('Parent widget rapid setState storm (50 rapid updates) induces zero timer leaks', (tester) async {
      const failedUrl = 'https://cards.scryfall.io/art/parent_storm.jpg';
      FailedImageRegistry.instance.markTerminal(failedUrl, statusCode: 404);

      int parentRebuilds = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            parentRebuilds++;
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text('REBUILD_COUNT_$parentRebuilds'),
                    const CountrCachedImage(
                      imageUrl: failedUrl,
                      cardName: 'Storm Card',
                      tcgDomain: 'other',
                      width: 100,
                      height: 140,
                      errorWidget: Text('STORM_ERROR'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('TRIGGER_REBUILD'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('STORM_ERROR'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));

      // Trigger 50 rapid parent setState rebuild passes
      for (int i = 0; i < 50; i++) {
        await tester.tap(find.text('TRIGGER_REBUILD'));
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.pumpAndSettle();

      expect(find.text('STORM_ERROR'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
    });
  });

  // ===========================================================================
  // Section 2: Rapid Virtualization Thrashing
  // ===========================================================================
  group('Adversarial Stress 2: Rapid Virtualization Thrashing (20+ Cycles)', () {
    testWidgets('Unmount and remount 20 times in a loop maintains locked failure state and 0 retry loops', (tester) async {
      const failedUrl = 'https://cards.scryfall.io/art/thrash_unmount.jpg';
      FailedImageRegistry.instance.markTerminal(
        failedUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );

      for (int cycle = 1; cycle <= 20; cycle++) {
        // 1. Mount widget (simulating scroll item entering viewport)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                key: ValueKey('virtualized_image_key'),
                imageUrl: failedUrl,
                cardName: 'Thrash Item',
                tcgDomain: 'other',
                width: 100,
                height: 140,
                errorWidget: Text('CYCLE_ERROR'),
              ),
            ),
          ),
        );

        // Immediate locked error on frame 0
        expect(find.text('CYCLE_ERROR'), findsOneWidget, reason: 'Cycle $cycle mount failed to display error immediately');
        expect(tester.binding.transientCallbackCount, equals(0), reason: 'Cycle $cycle leaked callbacks on mount');

        // 2. Unmount widget immediately (simulating scroll item leaving viewport)
        await tester.pumpWidget(const SizedBox.shrink());

        expect(find.text('CYCLE_ERROR'), findsNothing);
        expect(tester.binding.transientCallbackCount, equals(0), reason: 'Cycle $cycle leaked callbacks on unmount');
      }

      // Remount on 21st cycle
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: ValueKey('virtualized_image_key'),
              imageUrl: failedUrl,
              cardName: 'Thrash Item',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: Text('CYCLE_ERROR'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CYCLE_ERROR'), findsOneWidget);
      expect(FailedImageRegistry.instance.isFailed(failedUrl), isTrue);
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Thrashing by cardId linked cacheKey keeps failure state locked across 20 cycles', (tester) async {
      const cardId = 'thrash-card-xyz';
      const url = 'https://cards.scryfall.io/art/thrash_card_xyz.jpg';
      final cacheKey = CountrImageCacheManager.cardArtKey(cardId);

      FailedImageRegistry.instance.linkKeys(url, cacheKey);
      FailedImageRegistry.instance.markTerminal(cacheKey, statusCode: 404);

      for (int cycle = 1; cycle <= 20; cycle++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                cardId: cardId,
                imageUrl: url,
                cardName: 'CacheKey Thrash',
                tcgDomain: 'other',
                width: 90,
                height: 120,
                errorWidget: const Text('CACHEKEY_LOCKED'),
              ),
            ),
          ),
        );
        expect(find.text('CACHEKEY_LOCKED'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, equals(0));

        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, equals(0));
      }

      expect(FailedImageRegistry.instance.isFailed(url, cacheKey: cacheKey), isTrue);
    });

    testWidgets('ListView.builder with 40 mixed failed items: violent scrolling thrash induces 0 timer leaks', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-mark half the items as failed
      for (int i = 0; i < 20; i++) {
        FailedImageRegistry.instance.markTerminal(
          'https://cards.scryfall.io/art/list_fail_$i.jpg',
          statusCode: 404,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 40,
              itemExtent: 80,
              itemBuilder: (context, index) {
                final isFailed = index < 20;
                final url = isFailed
                    ? 'https://cards.scryfall.io/art/list_fail_$index.jpg'
                    : 'https://cards.scryfall.io/art/list_ok_$index.jpg';

                return ListTile(
                  leading: CountrCachedImage(
                    imageUrl: url,
                    cardName: 'Card $index',
                    tcgDomain: 'other',
                    width: 50,
                    height: 70,
                    errorWidget: Text('FAIL_$index'),
                  ),
                  title: Text('Title $index'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Violent flings up and down 10 times (causing rapid unmount and remount of all 40 elements)
      for (int i = 0; i < 10; i++) {
        await tester.fling(find.byType(ListView), const Offset(0, -3000), 10000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.fling(find.byType(ListView), const Offset(0, 3000), 10000);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, equals(0));
    });
  });

  // ===========================================================================
  // Section 3: Strictly Zero Layout Shift (0.0px Delta Across All States)
  // ===========================================================================
  group('Adversarial Stress 3: Strictly Zero Layout Shift (0.0px Delta)', () {
    const dimensionPairs = [
      Size(100.0, 140.0), // Standard card ratio
      Size(150.0, 200.0), // Large preview
      Size(60.0, 84.0),   // Compact grid
      Size(35.0, 40.0),   // Micro thumbnail
      Size(250.0, 350.0), // Full detail card
      Size(48.0, 64.0),   // Tight binder view
    ];

    for (final dims in dimensionPairs) {
      testWidgets('Zero layout shift for ${dims.width}x${dims.height}: delta is strictly 0.0px across loading, rendered, and error states', (tester) async {
        final testUrl = 'https://example.com/dims_${dims.width}_${dims.height}.jpg';

        // ---------------------------------------------------------------------
        // 1. Loading State
        // ---------------------------------------------------------------------
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: testUrl,
                cardName: 'Shift Test Card',
                tcgDomain: 'other',
                width: dims.width,
                height: dims.height,
                placeholder: Container(
                  key: const ValueKey('loading_container'),
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),
        );

        final loadingSize = tester.getSize(find.byType(CountrCachedImage));
        expect(loadingSize.width, equals(dims.width));
        expect(loadingSize.height, equals(dims.height));

        // ---------------------------------------------------------------------
        // 2. Custom Error State
        // ---------------------------------------------------------------------
        FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: testUrl,
                cardName: 'Shift Test Card',
                tcgDomain: 'other',
                width: dims.width,
                height: dims.height,
                errorWidget: Container(
                  key: const ValueKey('error_container'),
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        final customErrorSize = tester.getSize(find.byType(CountrCachedImage));
        final deltaCustomW = (loadingSize.width - customErrorSize.width).abs();
        final deltaCustomH = (loadingSize.height - customErrorSize.height).abs();
        expect(deltaCustomW, equals(0.0), reason: 'Width shifted between loading and custom error!');
        expect(deltaCustomH, equals(0.0), reason: 'Height shifted between loading and custom error!');

        // ---------------------------------------------------------------------
        // 3. Default Styled Card Placeholder Error State
        // ---------------------------------------------------------------------
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: testUrl,
                cardName: 'Shift Test Card',
                tcgDomain: 'other',
                width: dims.width,
                height: dims.height,
              ),
            ),
          ),
        );

        final defaultErrorSize = tester.getSize(find.byType(CountrCachedImage));
        final deltaDefaultW = (loadingSize.width - defaultErrorSize.width).abs();
        final deltaDefaultH = (loadingSize.height - defaultErrorSize.height).abs();
        expect(deltaDefaultW, equals(0.0), reason: 'Width shifted between loading and default error!');
        expect(deltaDefaultH, equals(0.0), reason: 'Height shifted between loading and default error!');

        // ---------------------------------------------------------------------
        // 4. Default Loading Placeholder (no custom placeholder supplied)
        // ---------------------------------------------------------------------
        FailedImageRegistry.instance.reset(testUrl);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: testUrl,
                cardName: 'Shift Test Card',
                tcgDomain: 'other',
                width: dims.width,
                height: dims.height,
              ),
            ),
          ),
        );

        final defaultLoadingSize = tester.getSize(find.byType(CountrCachedImage));
        final deltaLoadingW = (defaultLoadingSize.width - dims.width).abs();
        final deltaLoadingH = (defaultLoadingSize.height - dims.height).abs();
        expect(deltaLoadingW, equals(0.0), reason: 'Width shifted on default loading placeholder!');
        expect(deltaLoadingH, equals(0.0), reason: 'Height shifted on default loading placeholder!');
      });
    }

    testWidgets('Zero layout shift with BorderRadius applied', (tester) async {
      const explicitWidth = 140.0;
      const explicitHeight = 190.0;
      const radius = BorderRadius.all(Radius.circular(16.0));
      const testUrl = 'https://example.com/radius_shift.jpg';

      // 1. Loading with radius
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              width: explicitWidth,
              height: explicitHeight,
              borderRadius: radius,
            ),
          ),
        ),
      );

      final loadingSize = tester.getSize(find.byType(CountrCachedImage));
      expect(find.byType(ClipRRect), findsOneWidget);
      final clipLoading = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipLoading.borderRadius, equals(radius));

      // 2. Error with radius
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              width: explicitWidth,
              height: explicitHeight,
              borderRadius: radius,
            ),
          ),
        ),
      );

      final errorSize = tester.getSize(find.byType(CountrCachedImage));
      expect(find.byType(ClipRRect), findsOneWidget);
      final clipError = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipError.borderRadius, equals(radius));

      expect((loadingSize.width - errorSize.width).abs(), equals(0.0));
      expect((loadingSize.height - errorSize.height).abs(), equals(0.0));
    });

    testWidgets('Single dimension specified: Width specified with parent constrained height has 0.0px delta', (tester) async {
      const testUrl = 'https://example.com/single_dim.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 180,
              child: CountrCachedImage(
                imageUrl: testUrl,
                width: 130,
                // height is null
              ),
            ),
          ),
        ),
      );

      final loadingSize = tester.getSize(find.byType(CountrCachedImage));
      expect(loadingSize.width, equals(130.0));

      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 180,
              child: CountrCachedImage(
                imageUrl: testUrl,
                width: 130,
                // height is null
              ),
            ),
          ),
        ),
      );

      final errorSize = tester.getSize(find.byType(CountrCachedImage));
      expect((loadingSize.width - errorSize.width).abs(), equals(0.0));
      expect((loadingSize.height - errorSize.height).abs(), equals(0.0));
    });
  });

  // ===========================================================================
  // Section 4: Extreme Constraints & Constraint Safety
  // ===========================================================================
  group('Adversarial Stress 4: Extreme Constraints & Adaptive Layout Safety', () {
    final tinyViewports = [
      const Size(20.0, 20.0),
      const Size(35.0, 40.0),
      const Size(60.0, 70.0),
      const Size(15.0, 15.0),
      const Size(8.0, 8.0),
      const Size(1.0, 1.0),
      const Size(0.0, 0.0),
    ];

    for (final size in tinyViewports) {
      testWidgets('Tiny viewport ${size.width}x${size.height}: mounts cleanly with 0 RenderFlex overflows', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: CountrCachedImage(
                  imageUrl: '',
                  cardName: 'Teferi, Hero of Dominaria',
                  tcgDomain: 'other',
                  width: size.width,
                  height: size.height,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CountrCachedImage), findsOneWidget);
      });
    }

    testWidgets('UnconstrainedBox mounting with and without dimensions causes 0 crashes or assertion failures', (tester) async {
      // 1. With explicit width/height inside UnconstrainedBox
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnconstrainedBox(
              child: CountrCachedImage(
                imageUrl: '',
                cardName: 'Black Lotus',
                tcgDomain: 'other',
                width: 80,
                height: 110,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CountrCachedImage)), equals(const Size(80.0, 110.0)));

      // 2. Loose constraints BoxConstraints.loose
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 0, maxWidth: 120, minHeight: 0, maxHeight: 160),
              child: const CountrCachedImage(
                imageUrl: '',
                cardName: 'Mox Sapphire',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Inside Row and Column flex layouts: mounts without unbounded height or width errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CountrCachedImage(
                        imageUrl: '',
                        cardName: 'Sol Ring',
                        tcgDomain: 'other',
                        height: 100,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 100,
                      child: CountrCachedImage(
                        imageUrl: '',
                        cardName: 'Mana Crypt',
                        tcgDomain: 'other',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pathological card name inputs in adaptive placeholder in compact 35x40 tile: 0 RenderFlex overflows', (tester) async {
      final pathologicalNames = [
        // 400+ characters long name
        'Our Market Research Shows That Players Like Really Long Card Names So We Made this Card Have The Most Absurdly Extended Name in All of Magic the Gathering History Just To Break Layout Engines With Huge Words Like Antidisestablishmentarianism And Supercalifragilisticexpialidocious',
        // Unicode Emojis
        '🔥💀💧🌳☀️✨🧙‍♂️🐲🛡️⚔️👑💎',
        // Non-Latin scripts
        '「黒の死神」 // Чёрный лотос // الرمز السحري',
        // Punctuation and symbols
        '///???!!!@@@###\$\$\$%%%^^^&&&***((()))___+++---===',
        // Single character
        'Z',
        // Whitespace only
        '     \t\n   ',
        // Empty string
        '',
        // Unknown Card fallback trigger
        'Unknown Card',
      ];

      for (final name in pathologicalNames) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 35,
                height: 40,
                child: CountrCachedImage(
                  imageUrl: '',
                  cardName: name,
                  tcgDomain: 'other',
                  width: 35,
                  height: 40,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Failed on pathological name: "$name"',
        );
        expect(find.byType(CountrCachedImage), findsOneWidget);
      }
    });
  });

  // ===========================================================================
  // Section 5: Manual Retry Protocol & Opaque Hit-Testing
  // ===========================================================================
  group('Adversarial Stress 5: Manual Retry Protocol & Gesture Hit-Testing', () {
    testWidgets('Tapping error widget resets registry, resets attempts, and reloads widget state', (tester) async {
      const testUrl = 'https://cards.scryfall.io/art/retry_test.jpg';
      FailedImageRegistry.instance.markTerminal(
        testUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );
      expect(FailedImageRegistry.instance.isFailed(testUrl), isTrue);
      expect(FailedImageRegistry.instance.getAttempts(testUrl), equals(3));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              cardName: 'Retry Target',
              tcgDomain: 'other',
              width: 120,
              height: 160,
              errorWidget: Text('CLICK_TO_RETRY'),
            ),
          ),
        ),
      );

      expect(find.text('CLICK_TO_RETRY'), findsOneWidget);

      // Perform tap to invoke manualRetry()
      await tester.tap(find.text('CLICK_TO_RETRY'));
      await tester.pump();

      // Verify registry was completely cleared for this URL
      expect(FailedImageRegistry.instance.isFailed(testUrl), isFalse);
      expect(FailedImageRegistry.instance.getAttempts(testUrl), equals(0));
    });

    testWidgets('HitTestBehavior.opaque: Tapping at outermost border pixels triggers manualRetry reliably', (tester) async {
      const testUrl = 'https://cards.scryfall.io/art/margin_tap.jpg';
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CountrCachedImage(
                imageUrl: testUrl,
                cardName: 'Opaque Test',
                tcgDomain: 'other',
                width: 140,
                height: 200,
              ),
            ),
          ),
        ),
      );

      expect(FailedImageRegistry.instance.isFailed(testUrl), isTrue);

      // Tap top-left pixel (+1, +1) inside widget bounds
      final topLeft = tester.getTopLeft(find.byType(CountrCachedImage)) + const Offset(1, 1);
      await tester.tapAt(topLeft);
      await tester.pump();

      expect(FailedImageRegistry.instance.isFailed(testUrl), isFalse);

      // 2. Test bottom-right pixel (-1, -1) with a distinct URL
      const testUrl2 = 'https://cards.scryfall.io/art/margin_tap_2.jpg';
      FailedImageRegistry.instance.markTerminal(testUrl2, statusCode: 404);
      expect(FailedImageRegistry.instance.isFailed(testUrl2), isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CountrCachedImage(
                imageUrl: testUrl2,
                cardName: 'Opaque Test 2',
                tcgDomain: 'other',
                width: 140,
                height: 200,
              ),
            ),
          ),
        ),
      );

      // Tap bottom-right pixel (-1, -1) inside widget bounds
      final bottomRight = tester.getBottomRight(find.byType(CountrCachedImage)) - const Offset(1, 1);
      await tester.tapAt(bottomRight);
      await tester.pump();

      expect(FailedImageRegistry.instance.isFailed(testUrl2), isFalse);
    });

    testWidgets(r'Manual retry with cardId clears both URL and card_art_$cardId cache keys in registry', (tester) async {
      const cardId = 'card-evict-999';
      const testUrl = 'https://cards.scryfall.io/art/evict_target.jpg';
      final cacheKey = CountrImageCacheManager.cardArtKey(cardId);

      FailedImageRegistry.instance.linkKeys(testUrl, cacheKey);
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);

      expect(FailedImageRegistry.instance.isFailed(testUrl, cacheKey: cacheKey), isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              cardId: cardId,
              imageUrl: testUrl,
              cardName: 'Dual Evict Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: Text('TAP_DUAL'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TAP_DUAL'));
      await tester.pump();

      // Both keys must be cleared
      expect(FailedImageRegistry.instance.isFailed(testUrl), isFalse);
      expect(FailedImageRegistry.instance.isFailed(cacheKey), isFalse);
    });

    testWidgets('Tapping error widget transitions cleanly from error to loading state, and re-locks if failed again', (tester) async {
      const testUrl = 'https://cards.scryfall.io/art/retry_cycle.jpg';
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              cardName: 'Retry Cycle Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              placeholder: Text('LOADING_NOW'),
              errorWidget: Text('TAP_TO_RELOAD'),
            ),
          ),
        ),
      );

      // 1. Initial error state
      expect(find.text('TAP_TO_RELOAD'), findsOneWidget);
      expect(find.text('LOADING_NOW'), findsNothing);

      // 2. User taps error widget
      await tester.tap(find.text('TAP_TO_RELOAD'));
      await tester.pump();

      // 3. Immediately transitions back to network loading state, registry cleared, remounted with revision 1
      expect(FailedImageRegistry.instance.isFailed(testUrl), isFalse);
      expect(find.text('TAP_TO_RELOAD'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.key, equals(const ValueKey('${testUrl}_rev1')));

      // 4. Suppose subsequent load also fails: error widget is redisplayed
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);
      // Update widget to simulate error callback / rebuild
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              cardName: 'Retry Cycle Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              placeholder: Text('LOADING_NOW'),
              errorWidget: Text('TAP_TO_RELOAD'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TAP_TO_RELOAD'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
    });
  });
}
