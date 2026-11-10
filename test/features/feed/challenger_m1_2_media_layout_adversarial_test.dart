// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial empirical challenge test suite for Milestone 1 (F3 & F5):
// 1. SinglePullPostBody: aspect ratio 63/88, 8px padding, BoxFit.contain without cropping, stress tests.
// 2. MediaPostBody: 16:9, 1:1, 4:5 aspect ratios across constrained widths (320px, 390px, 480px),
//    zero RenderFlex overflows, maxHeight 460 boundary condition stress testing.
// 3. MediaLightboxViewer: InteractiveViewer scale limits [0.5, 4.0], close button dismissal,
//    and interactive gestures.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/feed/presentation/widgets/media_lightbox_viewer.dart';
import 'package:countr/features/feed/presentation/widgets/media_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGE 1: SinglePullPostBody Geometry & BoxFit Invariants', () {
    testWidgets('Outer AspectRatio is strictly 63 / 88 (0.715909...) and padding is 8px horizontal', (tester) async {
      const testWidth = 390.0;
      await tester.binding.setSurfaceSize(const Size(testWidth, 900));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SinglePullPostBody(
              commentary: 'Testing exact geometry',
              cardTitle: 'Black Lotus (Alpha)',
              cardSubtitle: 'Limited Edition Alpha',
              cardRarity: 'Rare',
              estimatedValue: '\$15,000.00',
              cardId: 'item-card-black-lotus',
              imageUrl: 'https://cards.scryfall.io/large/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
            ),
          ),
        ),
      ));
      await tester.pump();

      // 1. Verify padding widget around card
      final paddingFinder = find.byWidgetPredicate((widget) {
        return widget is Padding && widget.padding == const EdgeInsets.symmetric(horizontal: 8);
      });
      expect(paddingFinder, findsOneWidget, reason: 'Must have outer 8px symmetric horizontal padding');

      final paddingWidget = tester.widget<Padding>(paddingFinder);
      expect(paddingWidget.padding, equals(const EdgeInsets.symmetric(horizontal: 8)));

      // 2. Verify AspectRatio widgets have exact ratio 63 / 88
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio)).toList();
      expect(aspectRatios.length, greaterThanOrEqualTo(2),
          reason: 'Must contain both outer card frame and inner card art AspectRatio widgets');

      for (final ar in aspectRatios) {
        expect(ar.aspectRatio, closeTo(63.0 / 88.0, 0.000001),
            reason: 'AspectRatio must strictly match 63 / 88');
      }

      // 3. Verify actual rendered layout dimensions
      // Screen width is 390. Horizontal padding is 8 on each side -> Available width = 390 - 16 = 374.
      final inkWellFinder = find.byKey(const Key('single_pull_card_item-card-black-lotus'));
      expect(inkWellFinder, findsOneWidget);

      final cardSize = tester.getSize(inkWellFinder);
      expect(cardSize.width, equals(testWidth - 16.0),
          reason: 'Card width must be screen width minus 16px padding');

      final expectedHeight = (testWidth - 16.0) / (63.0 / 88.0);
      expect(cardSize.height, closeTo(expectedHeight, 0.01),
          reason: 'Card height must equal width / (63/88)');

      // Verify global position
      final cardTopLeft = tester.getTopLeft(inkWellFinder);
      expect(cardTopLeft.dx, equals(8.0), reason: 'Left edge must be at x = 8px');
    });

    testWidgets('Card artwork renders with BoxFit.contain without cropping frame across different viewports', (tester) async {
      final viewports = [
        const Size(320, 600), // Narrow iPhone SE
        const Size(390, 844), // Standard iPhone 14
        const Size(480, 960), // Wide phone / phablet
      ];

      for (final viewport in viewports) {
        await tester.binding.setSurfaceSize(viewport);

        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardTitle: 'Mox Diamond',
                cardSubtitle: 'Stronghold',
                cardRarity: 'Rare',
                estimatedValue: '\$650.00',
                cardId: 'item-card-mox-diamond',
                imageUrl: 'https://cards.scryfall.io/large/front/d/e/deadbeef.jpg',
              ),
            ),
          ),
        ));
        await tester.pump();

        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget);

        final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
        expect(cachedImage.fit, equals(BoxFit.contain),
            reason: 'Card art must render with BoxFit.contain to prevent cropping card border');

        // Verify no layout overflows occurred
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Realistic MTG Stress Test: long commentary, long titles, long subtitle, Mythic Rare, high values under 320px width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));

      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                commentary: 'A' * 600 + ' Mana symbols: {W}{U}{B}{R}{G}{C} ' * 10,
                cardTitle: 'The Lord of the Rings: Tales of Middle-earth Special Edition Collector Booster Pull',
                cardSubtitle: 'The Lord of the Rings: Tales of Middle-earth Special Edition',
                cardRarity: 'Mythic Rare',
                estimatedValue: '\$1,250,000.00',
                cardId: 'item-card-extreme-test',
                imageUrl: 'https://cards.scryfall.io/large/front/e/x/extreme.jpg',
              ),
            ),
          ),
        ));
        await tester.pump();

        expect(errors.where((e) => e.toString().contains('RenderFlex overflowed')), isEmpty,
            reason: 'Production MTG text in SinglePullPostBody must not cause RenderFlex overflow even on 320px width');
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets('Adversarial Stress Verification: cardRarity in Flexible with ellipsis prevents Row RenderFlex overflow on 320px viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));

      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardTitle: 'Mox Opal',
                cardSubtitle: 'Scars of Mirrodin',
                cardRarity: 'Special Mythic Masterpiece Rare Foil Etched Promo',
                cardId: 'item-card-adversarial-rarity',
              ),
            ),
          ),
        ));
        await tester.pump();

        // This verifies that the Flexible wrapper with ellipsis prevents overflow:
        final overflowErrors = errors.where((e) => e.toString().contains('RenderFlex overflowed')).toList();
        expect(overflowErrors, isEmpty,
            reason: 'Flexible with TextOverflow.ellipsis guarantees zero RenderFlex overflow on 320px viewport');
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  });

  group('CHALLENGE 2: MediaPostBody Aspect Ratios & Responsive Zero-Overflow Invariants', () {
    const testCases = [
      (tag: '16:9', ratio: 16.0 / 9.0, desc: '16:9 landscape'),
      (tag: '1:1', ratio: 1.0, desc: '1:1 square'),
      (tag: '4:5', ratio: 4.0 / 5.0, desc: '4:5 portrait'),
    ];

    const widths = [320.0, 390.0, 480.0];

    for (final tc in testCases) {
      for (final w in widths) {
        testWidgets('MediaPostBody with ${tc.desc} (${tc.tag}) at width ${w}px renders cleanly with zero overflow', (tester) async {
          await tester.binding.setSurfaceSize(Size(w, 850));

          final List<FlutterErrorDetails> errors = [];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details);

          try {
            final mediaWidget = MediaPostBody(
              imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800',
              aspectRatioTag: tc.tag,
              caption: 'Adversarial responsive test for ${tc.tag} at ${w}px with {T}{R}{G} mana',
            );

            expect(mediaWidget.resolvedAspectRatio, closeTo(tc.ratio, 0.001),
                reason: 'Tag ${tc.tag} must resolve to ${tc.ratio}');

            await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: mediaWidget,
                ),
              ),
            ));
            await tester.pump();

            // Verify rendered widget
            expect(find.byType(MediaPostBody), findsOneWidget);

            // Verify zero RenderFlex overflow
            final overflowErrors = errors.where((e) => e.toString().contains('RenderFlex overflowed')).toList();
            expect(overflowErrors, isEmpty,
                reason: 'Must have zero RenderFlex overflow for ${tc.tag} at ${w}px');
            expect(tester.takeException(), isNull);

            // Verify rendered inner aspect ratio container
            final innerAspectRatioFinder = find.descendant(
              of: find.byType(MediaPostBody),
              matching: find.byType(AspectRatio),
            );
            expect(innerAspectRatioFinder, findsOneWidget);

            final innerSize = tester.getSize(innerAspectRatioFinder);
            final expectedMaxWidth = w - 32.0;

            // Width cannot exceed available width (w - 32)
            expect(innerSize.width, lessThanOrEqualTo(expectedMaxWidth + 0.01));

            // Aspect ratio must be faithfully preserved
            expect(innerSize.width / innerSize.height, closeTo(tc.ratio, 0.02),
                reason: 'Rendered aspect ratio must match resolved aspect ratio');

            // Verify maxHeight 460 constraint is respected: height cannot exceed 460
            expect(innerSize.height, lessThanOrEqualTo(460.01));
          } finally {
            FlutterError.onError = oldHandler;
          }
        });
      }
    }

    test('MediaPostBody resolvedAspectRatio handles edge cases, aliases, and bad inputs defensively', () {
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '16:9').resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: ' 16:9 ').resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '16/9').resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));

      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '1:1').resolvedAspectRatio, closeTo(1.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: 'square').resolvedAspectRatio, closeTo(1.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '1/1').resolvedAspectRatio, closeTo(1.0, 0.001));

      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '4:5').resolvedAspectRatio, closeTo(4.0 / 5.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: 'portrait').resolvedAspectRatio, closeTo(4.0 / 5.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '4/5').resolvedAspectRatio, closeTo(4.0 / 5.0, 0.001));

      // Fallback defaults
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: null).resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: '').resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(const MediaPostBody(imageUrl: '', aspectRatioTag: 'invalid_gibberish').resolvedAspectRatio, closeTo(16.0 / 9.0, 0.001));
    });

    testWidgets('MediaPostBody 4:5 under width 480px respects maxHeight 460 without distortion or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 900));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaPostBody(
              imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe',
              aspectRatioTag: '4:5',
              caption: 'Portrait deckbox setup',
            ),
          ),
        ),
      ));
      await tester.pump();

      final constrainedBoxFinder = find.descendant(
        of: find.byType(MediaPostBody),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBoxFinder, findsOneWidget);

      final box = tester.widget<ConstrainedBox>(constrainedBoxFinder);
      expect(box.constraints.maxHeight, equals(460.0));

      final size = tester.getSize(constrainedBoxFinder);
      expect(size.height, lessThanOrEqualTo(460.0));
      expect(tester.takeException(), isNull);
    });
  });

  group('CHALLENGE 3: MediaLightboxViewer Scale Limits, Gestures & Dismissal Invariants', () {
    testWidgets('InteractiveViewer enforces minScale: 0.5 and maxScale: 4.0 strictly', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaLightboxViewer(
            imageUrl: 'https://images.unsplash.com/photo-test',
            caption: 'Scale test',
          ),
        ),
      ));
      await tester.pump();

      final ivFinder = find.byType(InteractiveViewer);
      expect(ivFinder, findsOneWidget);

      final iv = tester.widget<InteractiveViewer>(ivFinder);
      expect(iv.minScale, equals(0.5), reason: 'InteractiveViewer minScale must be 0.5x');
      expect(iv.maxScale, equals(4.0), reason: 'InteractiveViewer maxScale must be 4.0x');
      expect(iv.clipBehavior, equals(Clip.none));
    });

    testWidgets('InteractiveViewer pan/zoom scale gestures behave without exceptions', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaLightboxViewer(
            imageUrl: 'https://images.unsplash.com/photo-test',
            caption: 'Interactive gesture test',
          ),
        ),
      ));
      await tester.pump();

      final center = tester.getCenter(find.byType(InteractiveViewer));

      // Perform a pinch/scale gesture simulation using multiple pointers
      final touch1 = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
      final touch2 = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
      await tester.pump();

      // Zoom in gesture
      await touch1.moveBy(const Offset(-40, 0));
      await touch2.moveBy(const Offset(40, 0));
      await tester.pump();

      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();

      // Verify no exceptions occurred during zoom gesture
      expect(tester.takeException(), isNull);

      // Perform pan drag gesture
      await tester.drag(find.byType(InteractiveViewer), const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Close button dismisses MediaLightboxViewer route cleanly', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('launch_lightbox'),
              onPressed: () {
                MediaLightboxViewer.show(
                  context,
                  imageUrl: 'https://images.unsplash.com/photo-test',
                  caption: 'Test dismissal',
                ).then((_) => dismissed = true);
              },
              child: const Text('Launch'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Open lightbox
      await tester.tap(find.byKey(const Key('launch_lightbox')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MediaLightboxViewer), findsOneWidget);
      expect(dismissed, isFalse);

      // Tap close button
      final closeButton = find.byKey(const Key('media_lightbox_close_button'));
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MediaLightboxViewer), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets('Full post integration: tapping MediaPostBody opens MediaLightboxViewer and close button dismisses', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaPostBody(
              imageUrl: 'https://images.unsplash.com/photo-test',
              aspectRatioTag: '16:9',
              caption: 'Full Pod View',
            ),
          ),
        ),
      ));
      await tester.pump();

      // Tap on image
      final gestureDetector = find.byType(GestureDetector);
      expect(gestureDetector, findsAtLeastNWidgets(1));
      await tester.tap(gestureDetector.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Lightbox must be displayed
      expect(find.byType(MediaLightboxViewer), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MediaLightboxViewer), matching: find.text('Full Pod View')),
        findsOneWidget,
      );

      // Close it via close button
      final closeButton = find.byKey(const Key('media_lightbox_close_button'));
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MediaLightboxViewer), findsNothing);
    });
  });
}
