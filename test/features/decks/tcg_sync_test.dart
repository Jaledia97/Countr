import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/core/state/tcg_context_sync.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';

void main() {
  group('R2: TcgContextSync Canonical Bridging & Normalization Unit Tests', () {
    test('gameToDomain correctly translates all known game context titles to domain codes', () {
      expect(TcgContextSync.gameToDomain('Magic: The Gathering'), equals('mtg'));
      expect(TcgContextSync.gameToDomain('magic'), equals('mtg'));
      expect(TcgContextSync.gameToDomain('MTG'), equals('mtg'));
      expect(TcgContextSync.gameToDomain('Pokémon TCG'), equals('pokemon'));
      expect(TcgContextSync.gameToDomain('Pokemon TCG'), equals('pokemon'));
      expect(TcgContextSync.gameToDomain('pokemon'), equals('pokemon'));
      expect(TcgContextSync.gameToDomain('Disney Lorcana'), equals('lorcana'));
      expect(TcgContextSync.gameToDomain('lorcana'), equals('lorcana'));
      expect(TcgContextSync.gameToDomain('All Collections'), equals('all'));
      expect(TcgContextSync.gameToDomain('Comic Books'), equals('all'));
      expect(TcgContextSync.gameToDomain('Sports Cards'), equals('all'));
      expect(TcgContextSync.gameToDomain(null), equals('all'));
      expect(TcgContextSync.gameToDomain(''), equals('all'));
      expect(TcgContextSync.gameToDomain('Unknown Non-TCG'), equals('all'));
    });

    test('domainToGame correctly translates all domain codes to canonical collection titles', () {
      expect(TcgContextSync.domainToGame('mtg'), equals('Magic: The Gathering'));
      expect(TcgContextSync.domainToGame('magic'), equals('Magic: The Gathering'));
      expect(TcgContextSync.domainToGame('pokemon'), equals('Pokémon TCG'));
      expect(TcgContextSync.domainToGame('pokémon'), equals('Pokémon TCG'));
      expect(TcgContextSync.domainToGame('lorcana'), equals('Disney Lorcana'));
      expect(TcgContextSync.domainToGame('all'), equals('All Collections'));
      expect(TcgContextSync.domainToGame(null), equals('All Collections'));
      expect(TcgContextSync.domainToGame(''), equals('All Collections'));
      expect(TcgContextSync.domainToGame('other'), equals('All Collections'));
    });

    test('normalizeCollectionType produces consistent domain strings', () {
      expect(TcgContextSync.normalizeCollectionType('Magic: The Gathering'), equals('mtg'));
      expect(TcgContextSync.normalizeCollectionType('Pokémon TCG'), equals('pokemon'));
      expect(TcgContextSync.normalizeCollectionType('Disney Lorcana'), equals('lorcana'));
      expect(TcgContextSync.normalizeCollectionType('Comic Books'), equals('comic'));
      expect(TcgContextSync.normalizeCollectionType('Sports Cards'), equals('sport'));
      expect(TcgContextSync.normalizeCollectionType('All Collections'), equals('all'));
      expect(TcgContextSync.normalizeCollectionType(null), equals('all'));
    });

    test('normalizeGameContext produces canonical collection titles', () {
      expect(TcgContextSync.normalizeGameContext('mtg'), equals('Magic: The Gathering'));
      expect(TcgContextSync.normalizeGameContext('pokemon'), equals('Pokémon TCG'));
      expect(TcgContextSync.normalizeGameContext('lorcana'), equals('Disney Lorcana'));
      expect(TcgContextSync.normalizeGameContext('comic'), equals('Comic Books'));
      expect(TcgContextSync.normalizeGameContext('sport'), equals('Sports Cards'));
      expect(TcgContextSync.normalizeGameContext('all'), equals('All Collections'));
      expect(TcgContextSync.normalizeGameContext(null), equals('All Collections'));
    });

    test('isTcgDomain identifies true TCGs correctly', () {
      expect(TcgContextSync.isTcgDomain('mtg'), isTrue);
      expect(TcgContextSync.isTcgDomain('pokemon'), isTrue);
      expect(TcgContextSync.isTcgDomain('lorcana'), isTrue);
      expect(TcgContextSync.isTcgDomain('all'), isFalse);
      expect(TcgContextSync.isTcgDomain('comic'), isFalse);
      expect(TcgContextSync.isTcgDomain('sport'), isFalse);
    });

    test('collectionDefinitions contains complete metadata including Disney Lorcana', () {
      final titles = TcgContextSync.collectionDefinitions.map((d) => d['title']).toList();
      expect(titles, contains('Magic: The Gathering'));
      expect(titles, contains('Pokémon TCG'));
      expect(titles, contains('Disney Lorcana'));
      expect(titles, contains('All Collections'));
      expect(titles, contains('Comic Books'));
      expect(titles, contains('Sports Cards'));
    });
  });

  group('R2: Bidirectional TCG Context Synchronization Between State Providers', () {
    test('Selecting MTG in activeGameContextProvider synchronizes activeDeckTcgFilterProvider to mtg', () {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'all'),
        ],
      );
      addTearDown(container.dispose);

      // Listen to activeGameContextProvider to sync to activeDeckTcgFilterProvider
      container.listen(activeGameContextProvider, (previous, next) {
        final domain = TcgContextSync.gameToDomain(next);
        if (container.read(activeDeckTcgFilterProvider) != domain) {
          container.read(activeDeckTcgFilterProvider.notifier).state = domain;
        }
      });

      // Initially
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));

      // Change game context to Pokémon TCG
      container.read(activeGameContextProvider.notifier).state = 'Pokémon TCG';
      expect(container.read(activeDeckTcgFilterProvider), equals('pokemon'));

      // Change game context to Disney Lorcana
      container.read(activeGameContextProvider.notifier).state = 'Disney Lorcana';
      expect(container.read(activeDeckTcgFilterProvider), equals('lorcana'));

      // Change game context to All Collections
      container.read(activeGameContextProvider.notifier).state = 'All Collections';
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));

      // Change game context back to Magic: The Gathering
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
      expect(container.read(activeDeckTcgFilterProvider), equals('mtg'));
    });

    test('Selecting domain in activeDeckTcgFilterProvider synchronizes activeGameContextProvider to title', () {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'all'),
        ],
      );
      addTearDown(container.dispose);

      // Listen to activeDeckTcgFilterProvider to sync to activeGameContextProvider
      container.listen(activeDeckTcgFilterProvider, (previous, next) {
        final game = TcgContextSync.domainToGame(next);
        if (container.read(activeGameContextProvider) != game) {
          container.read(activeGameContextProvider.notifier).state = game;
        }
      });

      // Change deck filter to pokemon
      container.read(activeDeckTcgFilterProvider.notifier).state = 'pokemon';
      expect(container.read(activeGameContextProvider), equals('Pokémon TCG'));

      // Change deck filter to lorcana
      container.read(activeDeckTcgFilterProvider.notifier).state = 'lorcana';
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));

      // Change deck filter to mtg
      container.read(activeDeckTcgFilterProvider.notifier).state = 'mtg';
      expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));

      // Change deck filter to all
      container.read(activeDeckTcgFilterProvider.notifier).state = 'all';
      expect(container.read(activeGameContextProvider), equals('All Collections'));
    });
  });

  group('R2: DecksScreen TCG Context Selection & Cross-Screen Synchronization UI', () {
    testWidgets('Selecting Pokémon in DecksScreen updates both activeDeckTcgFilterProvider and activeGameContextProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'all'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      // Tap Pokémon
      await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
      await tester.pumpAndSettle();

      // Verify activeDeckTcgFilterProvider updated to pokemon
      expect(container.read(activeDeckTcgFilterProvider), equals('pokemon'));

      // Verify activeGameContextProvider synchronized to 'Pokémon TCG'
      expect(container.read(activeGameContextProvider), equals('Pokémon TCG'));

      // Verify deck list filtered to Pokémon decks (2 decks)
      expect(find.text('All Decks (2)'), findsOneWidget);
    });

    testWidgets('Selecting Disney Lorcana in DecksScreen updates both activeDeckTcgFilterProvider and activeGameContextProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'all'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      // Tap Disney Lorcana
      await tester.tap(find.byKey(const Key('tcg_filter_lorcana')));
      await tester.pumpAndSettle();

      // Verify both providers updated
      expect(container.read(activeDeckTcgFilterProvider), equals('lorcana'));
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));

      // Verify deck list filtered to Lorcana decks (1 deck)
      expect(find.text('All Decks (1)'), findsOneWidget);
    });

    testWidgets('Selecting All Decks in DecksScreen updates both activeDeckTcgFilterProvider and activeGameContextProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'Disney Lorcana'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'lorcana'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      // Tap All Decks
      await tester.tap(find.byKey(const Key('tcg_filter_all')));
      await tester.pumpAndSettle();

      // Verify both providers updated
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));
      expect(container.read(activeGameContextProvider), equals('All Collections'));

      // Verify all 6 decks shown
      expect(find.text('All Decks (6)'), findsOneWidget);
    });

    testWidgets('External update of activeGameContextProvider triggers reactive re-filtering in DecksScreen', (tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameContextProvider.overrideWith((ref) => 'All Collections'),
          activeDeckTcgFilterProvider.overrideWith((ref) => 'all'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Decks (6)'), findsOneWidget);

      // Vault screen changes active game to Magic: The Gathering
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
      await tester.pumpAndSettle();

      // Decks screen should reactively update filter to MTG (3 decks)
      expect(container.read(activeDeckTcgFilterProvider), equals('mtg'));
      expect(find.text('All Decks (3)'), findsOneWidget);
      expect(find.text('Magic: The Gathering'), findsWidgets);
    });
  });
}
