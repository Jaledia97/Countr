// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommanderArtBackdrop Widget Tests (Feature 30)', () {
    testWidgets('T30.1: renders clean dark fallback gradient when imageUrl is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(imageUrl: null),
            ),
          ),
        ),
      );
      await tester.pump();

      // No CountrCachedImage or network image should be present
      expect(find.byType(CountrCachedImage), findsNothing);

      // Verify DecoratedBoxes for fallback gradient and vignettes exist
      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();
      expect(decoratedBoxes.length, greaterThanOrEqualTo(2));

      // First DecoratedBox has defaultFallbackGradient
      final baseBox = decoratedBoxes.first;
      final boxDecoration = baseBox.decoration as BoxDecoration;
      expect(boxDecoration.gradient, equals(CommanderArtBackdrop.defaultFallbackGradient));
    });

    testWidgets('T30.2: renders clean dark fallback gradient when imageUrl is empty or whitespace',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(imageUrl: '   '),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('T30.3: renders CountrCachedImage with default 0.30 opacity when imageUrl is valid',
        (tester) async {
      const testUrl = 'https://cards.scryfall.io/art_crop/front/d/5/d5806e68.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(imageUrl: testUrl),
            ),
          ),
        ),
      );
      await tester.pump();

      final cachedImageFinder = find.byType(CountrCachedImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImage.imageUrl, equals(testUrl));
      expect(cachedImage.fit, equals(BoxFit.cover));

      // Verify Opacity widget parent
      final opacityFinder = find.ancestor(
        of: cachedImageFinder,
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget);

      final opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, equals(0.30));
    });

    testWidgets('T30.4: supports custom opacity within calibrated range (0.25 to 0.35)',
        (tester) async {
      const testUrl = 'https://cards.scryfall.io/art_crop/atraxa.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(
                imageUrl: testUrl,
                opacity: 0.35,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final opacityWidget = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(CountrCachedImage),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(0.35));
    });

    testWidgets('T30.5: renders multi-stop dark vignette gradient overlay for WCAG AAA contrast',
        (tester) async {
      const testUrl = 'https://cards.scryfall.io/art_crop/urza.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(imageUrl: testUrl),
            ),
          ),
        ),
      );
      await tester.pump();

      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();

      // Find the linear vignette overlay
      final linearVignettes = decoratedBoxes.where((box) {
        final dec = box.decoration;
        return dec is BoxDecoration && dec.gradient is LinearGradient;
      }).toList();

      expect(linearVignettes.length, greaterThanOrEqualTo(1));

      final vignetteDec = linearVignettes.last.decoration as BoxDecoration;
      final gradient = vignetteDec.gradient as LinearGradient;

      expect(gradient.begin, equals(Alignment.topCenter));
      expect(gradient.end, equals(Alignment.bottomCenter));
      expect(gradient.colors.length, equals(3));
      // Confirms stops [0.0, 0.45, 1.0]
      expect(gradient.stops, equals([0.0, 0.45, 1.0]));
    });

    testWidgets('T30.6: root is wrapped in IgnorePointer ensuring transparent touch pass-through',
        (tester) async {
      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Underlying interactable button
                ElevatedButton(
                  key: const Key('underlying_button'),
                  onPressed: () => buttonTapped = true,
                  child: const Text('Tap Me'),
                ),
                // Overlaying CommanderArtBackdrop
                const Positioned.fill(
                  child: CommanderArtBackdrop(
                    imageUrl: 'https://cards.scryfall.io/art_crop/test.jpg',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on the button through the backdrop
      await tester.tap(find.byKey(const Key('underlying_button')));
      await tester.pump();

      expect(buttonTapped, isTrue);
    });

    testWidgets('T30.7: handles child overlay rendering cleanly above vignette',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CommanderArtBackdrop(
                imageUrl: 'https://cards.scryfall.io/art_crop/test.jpg',
                child: Text('Overlay Child Text'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Overlay Child Text'), findsOneWidget);
    });
  });
}
