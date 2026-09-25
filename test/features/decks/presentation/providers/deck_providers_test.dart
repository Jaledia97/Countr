import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('deckProvider error propagation and reactive streaming', () {
    test('transitions cleanly to AsyncError when deck does not exist in SQLite', () async {
      // Non-existent deck ID causes Drift's watchSingle() to throw StateError
      final subscription = container.listen(deckProvider('nonexistent-deck-id'), (_, _) {});
      addTearDown(subscription.close);

      // Initially it's loading
      expect(container.read(deckProvider('nonexistent-deck-id')), isA<AsyncLoading>());

      // Await until provider emits or throws - reading .future should reject with StateError
      expect(
        () => container.read(deckProvider('nonexistent-deck-id').future),
        throwsA(isA<StateError>()),
      );

      // Allow microtask queue to settle provider state
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(deckProvider('nonexistent-deck-id'));
      expect(state, isA<AsyncError>());
      expect(state.error, isA<StateError>());
    });

    test('emits AsyncData when deck exists and updates reactively', () async {
      final deck = await db.vaultDao.createDeck('Commander Deck Alpha', format: 'Commander');

      final subscription = container.listen(deckProvider(deck.id), (_, _) {});
      addTearDown(subscription.close);

      final loadedDeck = await container.read(deckProvider(deck.id).future);
      expect(loadedDeck.id, deck.id);
      expect(loadedDeck.name, 'Commander Deck Alpha');

      final state = container.read(deckProvider(deck.id));
      expect(state, isA<AsyncData<Deck>>());
      expect(state.value?.name, 'Commander Deck Alpha');
    });
  });
}
