import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/app_settings_dialog.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;
  const currentUserId = 'user-privacy-tester';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: currentUserId,
        username: '@privacy_tester',
        displayName: 'Privacy Tester',
        bio: const Value('Testing collection privacy settings'),
        collectionVisibility: const Value('public'),
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Collection Privacy Settings Tests', () {
    testWidgets('AppSettingsDialog displays collection visibility toggle and persists toggle changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AppSettingsDialog(),
              ),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      );

      // Open AppSettingsDialog
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('command_center_collection_visibility_toggle'));
      expect(toggleFinder, findsOneWidget);

      // Verify initially public
      var switchWidget = tester.widget<Switch>(toggleFinder);
      expect(switchWidget.value, isTrue);
      expect(find.text('Public: Trade partners can browse full collection'), findsOneWidget);

      // Tap toggle to make private
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify persisted in DB
      var profile = await db.userProfileDao.getProfile(currentUserId);
      expect(profile!.collectionVisibility, equals('private'));

      // Verify UI updated
      switchWidget = tester.widget<Switch>(toggleFinder);
      expect(switchWidget.value, isFalse);
      expect(find.text('Private: Trade partners restricted to Trade Binder'), findsOneWidget);

      // Tap toggle again to return to public
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      profile = await db.userProfileDao.getProfile(currentUserId);
      expect(profile!.collectionVisibility, equals('public'));
      switchWidget = tester.widget<Switch>(toggleFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('Edit Profile dialog contains collection visibility dropdown and persists selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      await tester.pumpWidget(
        buildTestApp(
          const UserProfileScreen(profileId: currentUserId),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Profile modal
      final editBtnFinder = find.byKey(const Key('profile_btn_edit_profile'));
      expect(editBtnFinder, findsOneWidget);
      await tester.tap(editBtnFinder);
      await tester.pumpAndSettle();

      // Check dropdown exists
      final dropdownFinder = find.byKey(const Key('edit_profile_collection_visibility_dropdown'));
      expect(dropdownFinder, findsOneWidget);

      // Tap dropdown to select 'Private'
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final privateItemFinder = find.text('Private (Trade Binder Only)').last;
      await tester.tap(privateItemFinder);
      await tester.pumpAndSettle();

      // Save profile
      final saveBtnFinder = find.byKey(const Key('edit_profile_save_button'));
      expect(saveBtnFinder, findsOneWidget);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verify updated in DB
      final profile = await db.userProfileDao.getProfile(currentUserId);
      expect(profile!.collectionVisibility, equals('private'));
    });
  });
}
