import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountrImageCacheManager Unit Tests', () {
    test('Configures long-term disk cache duration of 30+ days and high object limit', () {
      expect(CountrImageCacheManager.stalePeriod.inDays, greaterThanOrEqualTo(30));
      expect(CountrImageCacheManager.stalePeriod.inDays, equals(35));
      expect(CountrImageCacheManager.maxNrOfCacheObjects, greaterThanOrEqualTo(5000));
      expect(CountrImageCacheManager.key, equals('countr_card_images'));
    });

    test('Attaches official User-Agent header for Scryfall and generic TCG APIs', () {
      expect(
        CountrImageCacheManager.userAgent,
        equals('Countr/1.0 (Flutter; Educational Portfolio App)'),
      );
      expect(
        CountrHttpFileService.userAgent,
        equals('Countr/1.0 (Flutter; Educational Portfolio App)'),
      );
    });

    test('cardArtKey generates deterministic cache key linked to cardId', () {
      expect(CountrImageCacheManager.cardArtKey('mtg-123'), equals('card_art_mtg-123'));
      expect(CountrImageCacheManager.cardArtKey('edgar-markov'), equals('card_art_edgar-markov'));
    });

    test('deckCoverKey generates deterministic cache key linked to deckId', () {
      expect(CountrImageCacheManager.deckCoverKey('deck-1'), equals('deck_cover_deck-1'));
      expect(CountrImageCacheManager.deckCoverKey('deck-edgar-markov'), equals('deck_cover_deck-edgar-markov'));
    });

    test('generateCardKey alias produces identical result to cardArtKey', () {
      final manager = CountrImageCacheManager();
      expect(manager.generateCardKey('card-xyz'), equals(CountrImageCacheManager.cardArtKey('card-xyz')));
    });
  });
}
