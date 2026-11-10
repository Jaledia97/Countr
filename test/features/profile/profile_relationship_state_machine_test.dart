// Copyright (c) 2026 Countr. All rights reserved.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await db.vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({required String profileId}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
      ],
      child: MaterialApp(
        home: UserProfileScreen(profileId: profileId),
      ),
    );
  }

  group('Profile Relationship State Machine', () {
    testWidgets('State 1 (none): shows Add Friend button, tapping transitions to pending_sent with cancel option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      // user-spicy-brew-master starts with no friendship record with user-current-me
      await tester.pumpWidget(createWidgetUnderTest(profileId: 'user-spicy-brew-master'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final addFriendBtn = find.byKey(const Key('profile_btn_add_friend'));
      expect(addFriendBtn, findsOneWidget);

      // Tap Add Friend
      await tester.tap(addFriendBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Transforms into Request Sent button
      final requestSentBtn = find.byKey(const Key('profile_btn_request_sent'));
      expect(requestSentBtn, findsOneWidget);

      // Tap Request Sent to cancel
      await tester.tap(requestSentBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Reverts back to Add Friend
      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget);
    });

    testWidgets('State 2 (pending_received): renders inline Approve and Deny buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      // Have user-spicy-brew-master send request to current user
      await db.friendsDao.sendFriendRequest('user-spicy-brew-master', 'user-current-me');

      await tester.pumpWidget(createWidgetUnderTest(profileId: 'user-spicy-brew-master'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final approveBtn = find.byKey(const Key('profile_btn_approve_friend'));
      final denyBtn = find.byKey(const Key('profile_btn_deny_friend'));
      expect(approveBtn, findsOneWidget);
      expect(denyBtn, findsOneWidget);

      // Tap Approve
      await tester.tap(approveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Transitions to Friends state
      expect(find.byKey(const Key('profile_btn_friends_dropdown')), findsOneWidget);
    });

    testWidgets('State 3 (friends): Friends dropdown opens menu with Unfriend, Block, and Report', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      // Establish mutual friendship
      await db.friendsDao.sendFriendRequest('user-spicy-brew-master', 'user-current-me');
      await db.friendsDao.respondToFriendRequest('user-current-me', 'user-spicy-brew-master', accept: true);

      await tester.pumpWidget(createWidgetUnderTest(profileId: 'user-spicy-brew-master'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final friendsDropdown = find.byKey(const Key('profile_btn_friends_dropdown'));
      expect(friendsDropdown, findsOneWidget);

      // Tap Friends dropdown
      await tester.tap(friendsDropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('profile_menu_unfriend')), findsOneWidget);
      expect(find.byKey(const Key('profile_menu_block_user')), findsOneWidget);
      expect(find.byKey(const Key('profile_menu_report_profile')), findsOneWidget);

      // Tap Unfriend
      await tester.tap(find.byKey(const Key('profile_menu_unfriend')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Transitions to none (Add Friend)
      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget);
    });

    testWidgets('Secondary Menu in AppBar provides Block User and Report Profile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createWidgetUnderTest(profileId: 'user-spicy-brew-master'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final secondaryMenuBtn = find.byKey(const Key('profile_btn_secondary_menu'));
      expect(secondaryMenuBtn, findsOneWidget);

      // Tap secondary menu
      await tester.tap(secondaryMenuBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('profile_menu_block_user')), findsOneWidget);
      expect(find.byKey(const Key('profile_menu_report_profile')), findsOneWidget);

      // Tap Block User
      await tester.tap(find.byKey(const Key('profile_menu_block_user')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Button transforms to Unblock
      expect(find.byKey(const Key('profile_btn_unblock')), findsOneWidget);
    });
  });
}
