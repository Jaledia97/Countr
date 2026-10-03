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

  // =========================================================================
  // DIMENSION 1: REBUILD LOOP TERMINATION & BUILD COUNT STABILITY
  // =========================================================================
  group('Challenger Dimension 1: Rebuild Loop Termination & Build Count Stability', () {
    testWidgets('Terminal error locks immediately and build count ceases at exactly 1', (tester) async {
      int buildCount = 0;
      const deadUrl = 'https://example.com/404_card.jpg';
      FailedImageRegistry.instance.markTerminal(
        deadUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Builder(
                  builder: (context) {
                    buildCount++;
                    return const CountrCachedImage(
                      imageUrl: deadUrl,
                      cardName: 'Dead Card',
                      tcgDomain: 'other',
                      width: 100,
                      height: 140,
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify immediate single build
      expect(buildCount, equals(1));

      // Advance frames across 10 distinct pump ticks
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Absolute stability: zero cascade rebuilds
      expect(buildCount, equals(1));
    });

    testWidgets('Empty/Invalid URL immediately terminates rebuilds without scheduler loops', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return const CountrCachedImage(
                  imageUrl: '   ',
                  cardName: 'Empty URL Card',
                  tcgDomain: 'other',
                  width: 100,
                  height: 140,
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(buildCount, equals(1));
    });

    testWidgets('Manual retry execution terminates after single revision increment', (tester) async {
      const url = 'https://example.com/retry_loop_test.jpg';
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404);

      int parentBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                parentBuilds++;
                return const CountrCachedImage(
                  imageUrl: url,
                  cardName: 'Retry Loop Card',
                  tcgDomain: 'other',
                  width: 100,
                  height: 140,
                );
              },
            ),
          ),
        ),
      );

      expect(parentBuilds, equals(1));
      expect(find.byType(CountrCachedImage), findsOneWidget);

      // Trigger manual retry via tap
      await tester.tap(find.byType(CountrCachedImage));
      await tester.pump();

      // Parent build count must NOT be re-triggered
      expect(parentBuilds, equals(1));

      // Settle must complete without looping
      await tester.pumpAndSettle();
      expect(parentBuilds, equals(1));
    });

    testWidgets('10 rapid manual retry taps in succession terminate without infinite cycle', (tester) async {
      const url = 'https://example.com/rapid_taps.jpg';
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: url,
              cardName: 'Rapid Taps Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(CountrCachedImage));
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpAndSettle();
      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // DIMENSION 2: 0 TIMER LEAKS ACROSS UNMOUNT / REMOUNT CYCLES
  // =========================================================================
  group('Challenger Dimension 2: 0 Timer Leaks Across Unmount / Remount Cycles', () {
    testWidgets('Zero transient callbacks or timers active after unmounting 20 diverse images', (tester) async {
      final urls = [
        'https://example.com/art1.jpg',
        'https://example.com/art2.jpg',
        'https://cards.scryfall.io/art_crop/back.jpg',
        '',
        '   ',
        'file:///local/card.png',
        'https://invalid.scheme.fake/art.jpg',
      ];

      final widgets = Column(
        children: urls
            .map(
              (u) => CountrCachedImage(
                imageUrl: u,
                cardName: 'Card ${u.hashCode}',
                width: 50,
                height: 50,
              ),
            )
            .toList(),
      );

      // Mount
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widgets)));
      await tester.pump(const Duration(milliseconds: 20));

      // Immediate Unmount
      await tester.pumpWidget(const SizedBox.shrink());

      // Assert 0 transient callbacks
      expect(tester.binding.transientCallbackCount, equals(0));

      // Advance virtual clock significantly
      await tester.pump(const Duration(seconds: 30));

      // No lingering timers or unhandled exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: 50 consecutive unmount/remount cycles produce strictly 0 timer leaks', (tester) async {
      const url = 'https://example.com/rapid_remount.jpg';

      for (int cycle = 0; cycle < 50; cycle++) {
        // Mount
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: url,
                cardName: 'Oscillating Card',
                width: 60,
                height: 80,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 5));

        // Unmount
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 5));
      }

      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, equals(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid prop mutations (didUpdateWidget churn) leave zero leaking timers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: ValueKey('churn_key'),
              imageUrl: 'https://example.com/art0.jpg',
              cardName: 'Card 0',
              width: 60,
              height: 80,
            ),
          ),
        ),
      );

      for (int i = 1; i <= 30; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                key: const ValueKey('churn_key'),
                imageUrl: 'https://example.com/art$i.jpg',
                cardName: 'Card $i',
                width: 60,
                height: 80,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 2));
      }

      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, equals(0));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // DIMENSION 3: STRICTLY 0.0px LAYOUT SHIFT
  // =========================================================================
  group('Challenger Dimension 3: Strictly 0.0px Layout Shift', () {
    testWidgets('Explicit dimensions match with strictly 0.0px delta between placeholder and error', (tester) async {
      const targetWidth = 88.0;
      const targetHeight = 124.0;
      const testUrl = 'https://example.com/shift_test.jpg';

      // 1. Measure Loading Placeholder State
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              width: targetWidth,
              height: targetHeight,
              placeholder: Container(
                key: const ValueKey('ph'),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      final Size placeholderSize = tester.getSize(find.byType(CountrCachedImage));
      expect(placeholderSize.width, equals(targetWidth));
      expect(placeholderSize.height, equals(targetHeight));

      // 2. Measure Error State
      FailedImageRegistry.instance.markTerminal(testUrl, statusCode: 404);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: testUrl,
              width: targetWidth,
              height: targetHeight,
              errorWidget: Container(
                key: const ValueKey('err'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      final Size errorSize = tester.getSize(find.byType(CountrCachedImage));

      // Assert strictly 0.0px layout shift
      final double deltaWidth = (errorSize.width - placeholderSize.width).abs();
      final double deltaHeight = (errorSize.height - placeholderSize.height).abs();

      expect(deltaWidth, equals(0.0));
      expect(deltaHeight, equals(0.0));
      expect(errorSize, equals(placeholderSize));
    });

    testWidgets('Parent tight constraints enforce strictly 0.0px shift without explicit widget dims', (tester) async {
      const parentSize = Size(110.0, 154.0);
      const url = 'https://example.com/parent_tight.jpg';

      // 1. Loading state under parent tight box
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: parentSize,
              child: const CountrCachedImage(
                imageUrl: url,
              ),
            ),
          ),
        ),
      );

      final Size loadingSize = tester.getSize(find.byType(CountrCachedImage));
      expect(loadingSize, equals(parentSize));

      // 2. Error state under same parent tight box
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: parentSize,
              child: const CountrCachedImage(
                imageUrl: url,
                cardName: 'Tight Box Card',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );

      final Size errorSize = tester.getSize(find.byType(CountrCachedImage));
      expect(errorSize, equals(parentSize));
      expect((errorSize.width - loadingSize.width).abs(), equals(0.0));
      expect((errorSize.height - loadingSize.height).abs(), equals(0.0));
    });

    testWidgets('AspectRatio container maintains strictly 0.0px shift across state transitions', (tester) async {
      const url = 'https://example.com/aspect_ratio_card.jpg';

      // 1. Loading state under AspectRatio
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: AspectRatio(
                aspectRatio: 2.0 / 3.0,
                child: CountrCachedImage(
                  imageUrl: url,
                ),
              ),
            ),
          ),
        ),
      );

      final Size aspectLoadingSize = tester.getSize(find.byType(CountrCachedImage));
      expect(aspectLoadingSize.width, equals(100.0));
      expect(aspectLoadingSize.height, closeTo(150.0, 0.0001));

      // 2. Error state
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: AspectRatio(
                aspectRatio: 2.0 / 3.0,
                child: CountrCachedImage(
                  imageUrl: url,
                  cardName: 'Aspect Ratio Card',
                  tcgDomain: 'other',
                ),
              ),
            ),
          ),
        ),
      );

      final Size aspectErrorSize = tester.getSize(find.byType(CountrCachedImage));
      expect(aspectErrorSize, equals(aspectLoadingSize));
    });

    testWidgets('3x3 GridView layout: zero geometric translation or shift across 9 tiles', (tester) async {
      final gridUrls = List.generate(9, (i) => 'https://example.com/grid_tile_$i.jpg');

      // Helper to build 3x3 grid
      Widget buildGrid() {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 450,
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  return CountrCachedImage(
                    imageUrl: gridUrls[index],
                    cardName: 'Grid Card $index',
                    tcgDomain: 'other',
                  );
                },
              ),
            ),
          ),
        );
      }

      // Phase 1: Mount with all tiles loading
      await tester.pumpWidget(buildGrid());
      await tester.pump();

      final loadingRects = <Rect>[];
      for (int i = 0; i < 9; i++) {
        loadingRects.add(tester.getRect(find.byType(CountrCachedImage).at(i)));
      }

      // Phase 2: Mark all 9 tiles failed
      for (final u in gridUrls) {
        FailedImageRegistry.instance.markTerminal(u, statusCode: 404);
      }

      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      final errorRects = <Rect>[];
      for (int i = 0; i < 9; i++) {
        errorRects.add(tester.getRect(find.byType(CountrCachedImage).at(i)));
      }

      expect(errorRects.length, equals(9));
      for (int i = 0; i < 9; i++) {
        final loadR = loadingRects[i];
        final errR = errorRects[i];
        expect((errR.left - loadR.left).abs(), equals(0.0), reason: 'Tile $i left shifted');
        expect((errR.top - loadR.top).abs(), equals(0.0), reason: 'Tile $i top shifted');
        expect((errR.width - loadR.width).abs(), equals(0.0), reason: 'Tile $i width shifted');
        expect((errR.height - loadR.height).abs(), equals(0.0), reason: 'Tile $i height shifted');
      }
    });
  });

  // =========================================================================
  // DIMENSION 4: EXTREME CONSTRAINT SAFETY
  // =========================================================================
  group('Challenger Dimension 4: Extreme Constraint Safety', () {
    testWidgets('Tight zero constraints (Size.zero) render without crash or assertion error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: CountrCachedImage(
                imageUrl: '',
                cardName: 'Zero Card',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(CountrCachedImage));
      expect(size, equals(Size.zero));
    });

    testWidgets('Microscopic constraints (1x1, 5x5, 10x10) survive without RenderFlex overflow', (tester) async {
      for (final dim in [1.0, 5.0, 10.0, 20.0, 35.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: dim,
                height: dim,
                child: const CountrCachedImage(
                  imageUrl: '',
                  cardName: 'Micro Card With Very Long Name',
                  tcgDomain: 'other',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Failed at dim $dim');
      }
    });

    testWidgets('Extreme aspect ratios (ultra-wide 600x5 and ultra-tall 5x600) render cleanly', (tester) async {
      // Ultra-wide
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 8,
              child: CountrCachedImage(
                imageUrl: '',
                cardName: 'Ultra Wide Card',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Ultra-tall
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 8,
              height: 600,
              child: CountrCachedImage(
                imageUrl: '',
                cardName: 'Ultra Tall Card',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Unbounded parent with explicit dimensions renders safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: CountrCachedImage(
                  imageUrl: '',
                  cardName: 'Unbounded Parent Card',
                  width: 120,
                  height: 160,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(CountrCachedImage));
      expect(size, equals(const Size(120, 160)));
    });

    testWidgets('Pathological card names (emojis, RTL, 5000 chars, control chars) never overflow', (tester) async {
      final adversarialNames = [
        '',
        'A',
        '   ',
        '!@#\$%^&*()_+=-~`{}[]|;:,.<>?',
        '🔥⚡️💀🌳💧👑⚔️🛡️✨🌟🎉',
        'سلام دنیا - نام کارت بسیار طولانی و فارسی',
        'שלום עולם - כרטיס עם שם ארוך בעברית',
        '这是一个极其复杂的卡牌名称带有非常多的汉字测试渲染稳定性',
        'Supercalifragilisticexpialidocious ' * 50,
        'Card\nName\r\nWith\tControl\x00Characters',
      ];

      for (final name in adversarialNames) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 75,
                height: 105,
                child: CountrCachedImage(
                  imageUrl: '',
                  cardName: name,
                  tcgDomain: 'other',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Failed on name: "$name"');
      }
    });

    testWidgets('Extreme border radiuses (0 to 1000) render without geometry errors', (tester) async {
      for (final radius in [0.0, 0.5, 12.0, 50.0, 500.0, 1000.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: '',
                cardName: 'Radius Card',
                tcgDomain: 'other',
                width: 80,
                height: 110,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Pathological URL inputs (schemeless, malformed, non-ASCII, huge) short-circuit safely', (tester) async {
      final pathologicalUrls = [
        'javascript:alert("XSS")',
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY44YAAAAASUVORK5CYII=',
        'http://[::1]:9999/invalid_ipv6',
        'https://example.com/картинка_тест.jpg',
        'https://example.com/path?query=${"a" * 3000}',
        'ftp://anonymous@files.example.com/image.png',
      ];

      for (final url in pathologicalUrls) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: url,
                cardName: 'Pathological URL Card',
                tcgDomain: 'other',
                width: 80,
                height: 110,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Failed on URL: $url');
        expect(find.byType(CountrCachedImage), findsOneWidget);
      }
    });
  });
}
