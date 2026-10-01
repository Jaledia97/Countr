import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  test('AppDatabase on disk upgrade from legacy schema with existing decks table', () async {
    final tempDir = await Directory.systemTemp.createTemp('vault_test_upgrade_');
    final dbFile = File('${tempDir.path}/test_vault.sqlite');
    
    // Create an initial db at version 5 that created decks table manually
    final rawDb = NativeDatabase(dbFile);
    final initDb = AppDatabase(rawDb);
    // Simulate legacy schema version 5
    await initDb.customStatement('PRAGMA user_version = 5;');
    await initDb.close();

    // Now open with AppDatabase (schemaVersion 10)
    final upgradedDb = AppDatabase(NativeDatabase(dbFile));
    final items = await upgradedDb.vaultDao.watchItemsByCollection('Magic: The Gathering').first;
    expect(items.length, greaterThanOrEqualTo(1));
    final binders = await upgradedDb.vaultDao.watchBindersByCollection('Magic: The Gathering').first;
    expect(binders, isNotNull);
    await upgradedDb.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('VaultScreen renders Singles and Binders views cleanly without persistent loading spinner', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    // Explicitly seed mock records
    await db.vaultDao.seedDatabase();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Verify Singles view is shown (default view mode) without loading spinner, showing saved cards
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('The One Ring'), findsWidgets);

    // 2. Switch to Binders view
    final bindersToggle = find.byKey(const Key('vault_view_binders_toggle'));
    expect(bindersToggle, findsOneWidget);
    await tester.tap(bindersToggle);
    await tester.pumpAndSettle();

    // 3. Verify Binders view displays seeded starter binder cleanly without persistent loading
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Personal Collection'), findsOneWidget);
  });

  testWidgets('VaultScreen renders prominent View Owned Singles button when binders are empty', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    // Clear binders to simulate empty binders state
    await db.customStatement('DELETE FROM vault_binders;');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.binders),
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify empty binders view
    expect(find.text('No Binders in Magic: The Gathering'), findsOneWidget);
    expect(find.text('+ Create First Binder'), findsOneWidget);
    final viewSinglesBtn = find.text('View Owned Singles');
    expect(viewSinglesBtn, findsOneWidget);

    // Tap View Owned Singles
    await tester.tap(viewSinglesBtn);
    await tester.pumpAndSettle();

    // Verify switched to Singles view and displays owned cards
    expect(find.textContaining('The One Ring'), findsWidgets);
  });
}
