import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/data/guest_migration_service.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late MockAuthRepository mockAuthRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    // Clear auto-seeded guest items to test true 0-item guest migration
    await db.delete(db.vaultItems).go();
    await db.delete(db.vaultBinders).go();
    await db.delete(db.decks).go();
    await db.delete(db.exploreDeckVotes).go();
    mockAuthRepo = MockAuthRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({int initialStep = 0}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
      ],
      child: MaterialApp(
        home: OnboardingWelcomeScreen(initialStep: initialStep),
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('M4 Challenger: Feature 18 Adversarial Verification (UI & Boundaries)', () {
    // =========================================================================
    // 1. DISCORD CTA BRANDING & INTERACTION
    // =========================================================================
    testWidgets('Adversarial: Discord CTA branding (#5865F2, "Continue with Discord")',
        (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Navigate to Individual Flow
      await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
      await tester.pumpAndSettle();

      // Find Discord CTA button
      final discordSubtreeFinder = find.byKey(const Key('onboarding_auth_discord'));
      final discordBtnFinder = find.byKey(const Key('onboarding_discord_cta_button'));
      expect(discordSubtreeFinder, findsOneWidget);
      expect(discordBtnFinder, findsOneWidget);

      // Verify exact branding color #5865F2
      final button = tester.widget<ElevatedButton>(discordBtnFinder);
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, equals(const Color(0xFF5865F2)),
          reason: 'Discord CTA must use Discord brand blurple #5865F2');

      // Verify button label
      expect(
          find.descendant(
              of: discordBtnFinder, matching: find.text('Continue with Discord')),
          findsOneWidget);
      expect(find.text('COMMUNITY PICK'), findsOneWidget);

      // Tap Discord CTA and verify profile fields populated
      await tester.tap(discordBtnFinder);
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextFormField>(
          find.byKey(const Key('profile_setup_display_name_input')));
      expect(nameField.controller?.text, equals('Discord Planeswalker'));

      final usernameField = tester.widget<TextFormField>(
          find.byKey(const Key('profile_setup_username_input')));
      expect(usernameField.controller?.text, equals('@discord_champion'));
    });

    // =========================================================================
    // 2. B18.1: PHONE NUMBER < 10 DIGITS REJECTION
    // =========================================================================
    group('B18.1: Phone number < 10 digits rejection', () {
      testWidgets('Individual flow: Rejects phone < 10 digits and accepts >= 10 digits',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        // Switch to Phone tab
        await tester.tap(find.byKey(const Key('onboarding_auth_phone_tab')));
        await tester.pumpAndSettle();

        final phoneInput = find.byKey(const Key('onboarding_auth_phone_input'));
        final sendOtpBtn = find.byKey(const Key('onboarding_auth_send_otp'));
        expect(phoneInput, findsOneWidget);
        expect(sendOtpBtn, findsOneWidget);

        // Adversarial 1: Empty phone
        await tester.enterText(phoneInput, '');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'),
            findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsNothing);

        // Adversarial 2: 9 digits with dashes
        await tester.enterText(phoneInput, '123-456-789');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'),
            findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsNothing);

        // Adversarial 3: Alphabetic string
        await tester.enterText(phoneInput, 'invalidphone');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'),
            findsOneWidget);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsNothing);

        // Valid phone with 10 digits
        await tester.enterText(phoneInput, '(850) 555-0199');
        await tester.tap(sendOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid phone number (min 10 digits).'),
            findsNothing);
        expect(find.byKey(const Key('onboarding_auth_otp_input')), findsOneWidget);
      });

      testWidgets('Business flow: Rejects store phone < 10 digits',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
        await tester.pumpAndSettle();

        // Populate valid store details but short phone (8 digits)
        await tester.enterText(
            find.byKey(const Key('business_store_lookup_input')), 'Game Haven');
        await tester.enterText(
            find.byKey(const Key('business_store_address_input')), '100 Main St');
        await tester.enterText(
            find.byKey(const Key('business_store_phone_input')), '850-555-01');
        await tester.enterText(
            find.byKey(const Key('business_store_website_input')),
            'https://gamehaven.com');
        await tester.enterText(
            find.byKey(const Key('business_otp_input')), '123456');

        await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('business_verify_otp_button')));
        await tester.pumpAndSettle();

        // Verify rejected and cannot advance
        expect(find.text('Store phone must be at least 10 digits.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);
      });
    });

    // =========================================================================
    // 3. B18.2: INCORRECT OTP REJECTION (ONLY 123456 ACCEPTED)
    // =========================================================================
    group('B18.2: Incorrect OTP rejection (only 123456 accepted)', () {
      testWidgets('Individual flow: Rejects invalid OTP and accepts 123456',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_auth_phone_tab')));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('onboarding_auth_phone_input')), '8505550199');
        await tester.tap(find.byKey(const Key('onboarding_auth_send_otp')));
        await tester.pumpAndSettle();

        final otpInput = find.byKey(const Key('onboarding_auth_otp_input'));
        final verifyOtpBtn = find.byKey(const Key('onboarding_auth_verify_otp'));

        // Adversarial 1: Wrong 6 digits
        await tester.enterText(otpInput, '000000');
        await tester.tap(verifyOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsOneWidget);

        // Adversarial 2: 5 digits
        await tester.enterText(otpInput, '12345');
        await tester.tap(verifyOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsOneWidget);

        // Adversarial 3: Off-by-one 123457
        await tester.enterText(otpInput, '123457');
        await tester.tap(verifyOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsOneWidget);

        // Valid OTP 123456
        await tester.enterText(otpInput, '123456');
        await tester.tap(verifyOtpBtn);
        await tester.pumpAndSettle();
        expect(find.text('Invalid OTP code. Use 123456.'), findsNothing);
      });

      testWidgets('Business flow: Rejects invalid OTP and accepts 123456',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('business_store_lookup_input')), 'TBS Comics');
        await tester.enterText(
            find.byKey(const Key('business_store_address_input')), '68 SW Eglin Pkwy');
        await tester.enterText(
            find.byKey(const Key('business_store_phone_input')), '(850) 244-4445');
        await tester.enterText(
            find.byKey(const Key('business_store_website_input')),
            'https://tbscomics.com');

        final verifyBtn = find.byKey(const Key('business_verify_otp_button'));
        await tester.ensureVisible(verifyBtn);
        await tester.pumpAndSettle();

        // Adversarial: Wrong OTP
        await tester.enterText(find.byKey(const Key('business_otp_input')), '999999');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();

        expect(find.text('Invalid OTP code. Use 123456.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Correct OTP 123456
        await tester.enterText(find.byKey(const Key('business_otp_input')), '123456');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();

        expect(find.text('Invalid OTP code. Use 123456.'), findsNothing);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // 4. B18.3: USERNAME REGEX REJECTION
    // =========================================================================
    group('B18.3: Username regex rejection', () {
      testWidgets('Rejects display name empty and username regex violations',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
        await tester.pumpAndSettle();

        final nameInput = find.byKey(const Key('profile_setup_display_name_input'));
        final usernameInput = find.byKey(const Key('profile_setup_username_input'));
        final submitBtn = find.byKey(const Key('profile_setup_submit_button'));

        // Adversarial 1: Empty display name
        await tester.enterText(nameInput, '');
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please enter your display name.'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Fill valid display name
        await tester.enterText(nameInput, 'Planeswalker');

        // Adversarial 2: Username < 3 alphanumeric chars after @ (e.g. '@ab')
        await tester.enterText(usernameInput, '@ab');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsNothing);

        // Adversarial 3: Username with spaces (e.g. '@has space')
        await tester.enterText(usernameInput, '@has space');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );

        // Adversarial 4: Username with illegal special chars (e.g. '@bad!char')
        await tester.enterText(usernameInput, '@bad!char');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );

        // Adversarial 5: Username exceeding 20 characters after @
        await tester.enterText(usernameInput, '@a123456789012345678901'); // 21 chars
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsOneWidget,
        );

        // Valid username without leading @ (auto-prepends @ -> @valid_user)
        await tester.enterText(usernameInput, 'valid_user');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
              'Username must start with @ and be 3-20 alphanumeric characters or underscores.'),
          findsNothing,
        );
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // 5. B18.4: BUSINESS VALIDATION
    // =========================================================================
    group('B18.4: Business validation', () {
      testWidgets('Rejects missing store details (name, address, phone, website)',
          (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
        await tester.pumpAndSettle();

        final nameInput = find.byKey(const Key('business_store_lookup_input'));
        final addrInput = find.byKey(const Key('business_store_address_input'));
        final phoneInput = find.byKey(const Key('business_store_phone_input'));
        final webInput = find.byKey(const Key('business_store_website_input'));
        final otpInput = find.byKey(const Key('business_otp_input'));
        final verifyBtn = find.byKey(const Key('business_verify_otp_button'));

        await tester.ensureVisible(verifyBtn);
        await tester.pumpAndSettle();

        // Subcase 1: Missing name
        await tester.enterText(nameInput, '');
        await tester.enterText(addrInput, '123 Main St');
        await tester.enterText(phoneInput, '(850) 555-0100');
        await tester.enterText(webInput, 'https://teststore.com');
        await tester.enterText(otpInput, '123456');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);

        // Subcase 2: Missing address
        await tester.enterText(nameInput, 'Test Store');
        await tester.enterText(addrInput, '');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);

        // Subcase 3: Missing phone
        await tester.enterText(addrInput, '123 Main St');
        await tester.enterText(phoneInput, '');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);

        // Subcase 4: Missing website
        await tester.enterText(phoneInput, '(850) 555-0100');
        await tester.enterText(webInput, '');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsOneWidget);

        // All fields filled -> passes validation
        await tester.enterText(webInput, 'https://teststore.com');
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(find.text('Please complete all store details.'), findsNothing);
        expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // 6. B18.5: 0-ITEM GUEST MIGRATION IN STEP 3
    // =========================================================================
    testWidgets('B18.5: 0-item guest migration renders clean summary and zero counts',
        (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
      await tester.pumpAndSettle();

      // Submit valid individual profile
      final submitBtn = find.byKey(const Key('profile_setup_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Step 3 transition
      final summaryFinder = find.byKey(const Key('onboarding_migration_summary'));
      expect(summaryFinder, findsOneWidget);
      expect(find.text('GUEST DATA AUTO-MERGED'), findsOneWidget);
      expect(find.textContaining('0 vault cards migrated to account'), findsOneWidget);
      expect(find.textContaining('0 custom binders preserved'), findsOneWidget);
      expect(find.textContaining('0 decks synced'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
    });

    // =========================================================================
    // 7. GOOGLE PLACES LOOKUP & 3-STEP TRANSITION INTO SHELL
    // =========================================================================
    testWidgets('Google Places lookup filters results, populates fields, and transitions to shell',
        (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Step 1: Account Type
      await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
      await tester.pumpAndSettle();

      // Step 2: Places search
      final lookupInput = find.byKey(const Key('business_store_lookup_input'));
      await tester.enterText(lookupInput, 'tbs');
      await tester.pumpAndSettle();

      expect(find.text('TBS Comics - Fort Walton Beach'), findsOneWidget);

      // Select place
      await tester.tap(find.text('TBS Comics - Fort Walton Beach'));
      await tester.pumpAndSettle();

      // Verify fields auto-populated
      final addrField = tester.widget<TextFormField>(
          find.byKey(const Key('business_store_address_input')));
      expect(addrField.controller?.text,
          equals('68 SW Eglin Pkwy, Fort Walton Beach, FL 32548'));

      final phoneField = tester.widget<TextFormField>(
          find.byKey(const Key('business_store_phone_input')));
      expect(phoneField.controller?.text, equals('(850) 244-4445'));

      final webField = tester.widget<TextFormField>(
          find.byKey(const Key('business_store_website_input')));
      expect(webField.controller?.text, equals('https://tbscomics.com'));

      // Verify OTP and transition to Step 3
      final verifyBtn = find.byKey(const Key('business_verify_otp_button'));
      await tester.ensureVisible(verifyBtn);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('business_otp_input')), '123456');
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      // Step 3 reached
      expect(find.text('LGS Store Verified!'), findsOneWidget);
      final enterAppBtn = find.byKey(const Key('onboarding_enter_app_button'));
      expect(enterAppBtn, findsOneWidget);

      // Enter app transition executes without crash
      await tester.tap(enterAppBtn);
      await tester.pumpAndSettle();
    });
  });

  // ===========================================================================
  // 8. ADVERSARIAL GUEST MIGRATION & COLLISION HANDLING (EMPIRICAL ORACLES)
  // ===========================================================================
  group('M4 Challenger: Guest Migration Collision & Invariant Stress Tests', () {
    late ProviderContainer container;
    late GuestMigrationService service;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      service = container.read(guestMigrationServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    VaultItemsCompanion makeTestCard({
      required String id,
      required String name,
      String? userId,
      String primaryBinderId = '',
    }) {
      final now = DateTime.now();
      return VaultItemsCompanion.insert(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'LEA',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: now,
        condition: 'NM',
        currentMarketPrice: 10.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        userId: userId != null ? drift.Value(userId) : const drift.Value.absent(),
        primaryBinderId: drift.Value(primaryBinderId),
      );
    }

    test('Adversarial: Explore Deck Vote collision is safely resolved without UNIQUE constraint violation', () async {
      final now = DateTime.now();
      const registeredUser = 'user_registered_alpha';

      // 1. Seed registered user's existing vote on deck_1 (+1 upvote)
      await db.into(db.exploreDeckVotes).insert(ExploreDeckVotesCompanion.insert(
            id: 'vote_registered_1',
            userId: const drift.Value(registeredUser),
            exploreDeckId: 'deck_shared_collision_1',
            vote: const drift.Value(1),
            updatedAt: now,
          ));

      // 2. Seed guest votes:
      // - deck_shared_collision_1 (-1 downvote, CONFLICTING with registered user)
      // - deck_guest_exclusive_2 (+1 upvote, NON-CONFLICTING)
      await db.into(db.exploreDeckVotes).insert(ExploreDeckVotesCompanion.insert(
            id: 'vote_guest_conflict',
            userId: const drift.Value('guest'),
            exploreDeckId: 'deck_shared_collision_1',
            vote: const drift.Value(-1),
            updatedAt: now,
          ));
      await db.into(db.exploreDeckVotes).insert(ExploreDeckVotesCompanion.insert(
            id: 'vote_guest_clean',
            userId: const drift.Value('guest'),
            exploreDeckId: 'deck_guest_exclusive_2',
            vote: const drift.Value(1),
            updatedAt: now,
          ));

      // 3. Execute migration
      final summary = await service.migrateGuestData(
        registeredUserId: registeredUser,
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);
      // Non-conflicting vote should be migrated
      expect(summary.migratedVotes, equals(1));

      // 4. Verify in SQLite that registered user's vote on deck_1 remains +1 (NOT overwritten by guest -1)
      final vote1 = await (db.select(db.exploreDeckVotes)
            ..where((t) =>
                t.userId.equals(registeredUser) &
                t.exploreDeckId.equals('deck_shared_collision_1')))
          .getSingle();
      expect(vote1.vote, equals(1),
          reason: 'Registered user existing vote must be preserved over guest vote');

      // 5. Verify non-conflicting guest vote is now owned by registeredUser
      final vote2 = await (db.select(db.exploreDeckVotes)
            ..where((t) =>
                t.userId.equals(registeredUser) &
                t.exploreDeckId.equals('deck_guest_exclusive_2')))
          .getSingle();
      expect(vote2.vote, equals(1));

      // 6. Verify conflicting guest vote was purged from database
      final remainingGuestVotes = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.userId.equals('guest')))
          .get();
      expect(remainingGuestVotes, isEmpty);
    });

    test('Adversarial: Multi-guest alias migration absorbs null, guest, local_user, and empty string', () async {
      final now = DateTime.now();
      const targetUser = 'user_consolidated_target';

      // Seed cards under 4 different legacy/guest ID variations
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_null', name: 'Card Null', userId: null));
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_guest', name: 'Card Guest', userId: 'guest'));
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_local', name: 'Card Local', userId: 'local_user'));
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_empty', name: 'Card Empty', userId: ''));

      // Seed decks under guest and local_user
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_guest',
            name: 'Guest Deck',
            format: 'Modern',
            createdAt: now,
            userId: const drift.Value('guest'),
          ));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_local',
            name: 'Local Deck',
            format: 'Legacy',
            createdAt: now,
            userId: const drift.Value('local_user'),
          ));

      // Perform migration
      final summary = await service.migrateGuestData(
        newUserId: targetUser,
      );

      expect(summary.isSuccess, isTrue);
      expect(summary.migratedVaultItems, equals(4));
      expect(summary.migratedDecks, equals(2));

      // Query database: All 4 cards must now be owned by targetUser
      final migratedCards = await (db.select(db.vaultItems)
            ..where((t) => t.userId.equals(targetUser)))
          .get();
      expect(migratedCards.length, equals(4));

      // No cards remain unowned or guest-owned
      final unownedCards = await (db.select(db.vaultItems)
            ..where((t) =>
                t.userId.isNull() |
                t.userId.equals('guest') |
                t.userId.equals('local_user') |
                t.userId.equals('')))
          .get();
      expect(unownedCards, isEmpty);
    });

    test('Adversarial: Re-anchoring cards from guest system binders into authenticated system binders', () async {
      const targetUser = 'user_reanchor_test';

      // Guest card in guest "Looking For" binder
      await db.into(db.vaultItems).insert(makeTestCard(
            id: 'c_looking_for',
            name: 'Looking For Card',
            userId: 'guest',
            primaryBinderId: 'system_looking_for_guest',
          ));
      // Guest card in guest "Trade Block" binder
      await db.into(db.vaultItems).insert(makeTestCard(
            id: 'c_trade_block',
            name: 'Trade Block Card',
            userId: 'guest',
            primaryBinderId: 'system_trade_block_guest',
          ));

      // Migrate as individual
      final summary = await service.migrateGuestData(
        registeredUserId: targetUser,
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);

      final card1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('c_looking_for'))).getSingle();
      final card2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('c_trade_block'))).getSingle();

      expect(card1.primaryBinderId, equals('system_looking_for_$targetUser'));
      expect(card2.primaryBinderId, equals('system_trade_block_$targetUser'));

      // Check system binders for targetUser are not duplicated
      final binders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(targetUser) & t.isSystemBinder.equals(true)))
          .get();
      // Should have exactly 2 system binders: Looking For and Trade Block
      expect(binders.length, equals(2));
    });

    test('Adversarial: ArgumentError is thrown when invalid or guest user ID is passed', () async {
      expect(
        () => service.migrateGuestData(registeredUserId: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.migrateGuestData(registeredUserId: 'guest'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.migrateGuestData(registeredUserId: null, newUserId: null),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Adversarial: Purging guest data preserves registered user data with zero leakage', () async {
      final now = DateTime.now();
      const existingUser = 'user_preserve_me';

      // Registered user data
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_reg', name: 'Reg Card', userId: existingUser));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_reg',
            name: 'Reg Deck',
            format: 'Standard',
            createdAt: now,
            userId: const drift.Value(existingUser),
          ));
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
            id: 'b_reg',
            name: 'Reg Custom Binder',
            collectionType: 'mtg',
            createdAt: now,
            userId: const drift.Value(existingUser),
            isSystemBinder: const drift.Value(false),
          ));

      // Guest data
      await db.into(db.vaultItems).insert(makeTestCard(id: 'c_gst', name: 'Gst Card', userId: 'guest'));
      await db.into(db.decks).insert(DecksCompanion.insert(
            id: 'd_gst',
            name: 'Gst Deck',
            format: 'Standard',
            createdAt: now,
            userId: const drift.Value('guest'),
          ));
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
            id: 'b_gst',
            name: 'Gst Custom Binder',
            collectionType: 'mtg',
            createdAt: now,
            userId: const drift.Value('guest'),
            isSystemBinder: const drift.Value(false),
          ));

      // Purge
      await service.purgeGuestData();

      // Guest data removed
      expect(await (db.select(db.vaultItems)..where((t) => t.id.equals('c_gst'))).get(), isEmpty);
      expect(await (db.select(db.decks)..where((t) => t.id.equals('d_gst'))).get(), isEmpty);
      expect(await (db.select(db.vaultBinders)..where((t) => t.id.equals('b_gst'))).get(), isEmpty);

      // Registered user data untouched
      expect(await (db.select(db.vaultItems)..where((t) => t.id.equals('c_reg'))).get(), isNotEmpty);
      expect(await (db.select(db.decks)..where((t) => t.id.equals('d_reg'))).get(), isNotEmpty);
      expect(await (db.select(db.vaultBinders)..where((t) => t.id.equals('b_reg'))).get(), isNotEmpty);
    });
  });
}
