import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountrCachedImage Unit & URL Tests', () {
    test('buildScryfallNamedUrl generates canonical named image redirect URL', () {
      final url = CountrCachedImage.buildScryfallNamedUrl('Edgar Markov');
      expect(
        url,
        equals('https://api.scryfall.com/cards/named?exact=Edgar%20Markov&format=image&version=art_crop'),
      );

      final normalUrl = CountrCachedImage.buildScryfallNamedUrl('Sol Ring', version: 'normal');
      expect(
        normalUrl,
        equals('https://api.scryfall.com/cards/named?exact=Sol%20Ring&format=image&version=normal'),
      );
    });

    test('buildScryfallNamedUrl safely handles double-faced card names', () {
      final url = CountrCachedImage.buildScryfallNamedUrl('Delver of Secrets // Insectile Aberration');
      expect(
        url,
        equals('https://api.scryfall.com/cards/named?exact=Delver%20of%20Secrets&format=image&version=art_crop'),
      );
    });

    test('buildScryfallNamedUrl safely handles special characters and quotes in names', () {
      final url = CountrCachedImage.buildScryfallNamedUrl("Urza's Tower");
      expect(
        url,
        equals("https://api.scryfall.com/cards/named?exact=Urza's%20Tower&format=image&version=art_crop"),
      );
    });
  });

  group('CountrCachedImage Widget Tests', () {
    testWidgets('Renders network image when valid imageUrl is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/valid_art.jpg',
              cacheKey: 'card_art_test1',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      expect((img.image as NetworkImage).url, equals('https://example.com/valid_art.jpg'));
    });

    testWidgets('Supports local file:// paths and renders FileImage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'file:///local/storage/card_art.jpg',
              cacheKey: 'card_art_local',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<FileImage>());
      expect((img.image as FileImage).file.path, equals('/local/storage/card_art.jpg'));
    });

    testWidgets('Falls back to Scryfall named redirect for MTG cards when imageUrl points to 404 back.jpg', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://cards.scryfall.io/art_crop/back.jpg',
              cardName: 'Edgar Markov',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final resolvedUrl = (img.image as NetworkImage).url;
      expect(resolvedUrl, contains('api.scryfall.com/cards/named'));
      expect(resolvedUrl, contains('Edgar%20Markov'));
    });

    testWidgets('Falls back to Scryfall named redirect for MTG cards when imageUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Cruel Celebrant',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final resolvedUrl = (img.image as NetworkImage).url;
      expect(resolvedUrl, contains('api.scryfall.com/cards/named'));
      expect(resolvedUrl, contains('Cruel%20Celebrant'));
    });

    testWidgets('Renders elegant styled card placeholder with card initials when card art is unavailable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Edgar Markov',
              tcgDomain: 'other', // not mtg, so no named scryfall fallback
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      // Initials 'EM' should be rendered in the styled placeholder
      expect(find.text('EM'), findsOneWidget);
      // Icons.image_not_supported must NOT be displayed
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('Intercepts Icons.image_not_supported in errorWidget and replaces with styled card placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Vampire Nighthawk',
              tcgDomain: 'other',
              errorWidget: Icon(
                Icons.image_not_supported,
                size: 18,
                color: Colors.white24,
              ),
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      // Verify that the ugly broken icon is replaced with the elegant placeholder initials
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.text('VN'), findsOneWidget);
    });
  });
}
