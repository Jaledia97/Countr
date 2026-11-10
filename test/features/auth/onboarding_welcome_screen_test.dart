import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/data/mock_auth_repository.dart';
import 'package:countr/features/auth/presentation/screens/onboarding_welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthRepository mockAuthRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
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

  group('Feature 18: OnboardingWelcomeScreen 3-Step Wizard', () {
    testWidgets('Step 1: Renders account type selection and guest option',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_welcome_screen')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_account_type_individual')),
          findsOneWidget);
      expect(find.byKey(const Key('onboarding_account_type_business')),
          findsOneWidget);
      expect(find.byKey(const Key('onboarding_continue_as_guest')), findsOneWidget);
    });

    testWidgets('Step 2 (Individual): Auth buttons & Profile setup fields',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Select Individual
      await tester.tap(find.byKey(const Key('onboarding_account_type_individual')));
      await tester.pumpAndSettle();

      // Auth buttons
      expect(find.byKey(const Key('onboarding_auth_discord')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_discord_cta_button')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_auth_google')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_auth_apple')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_auth_facebook')), findsOneWidget);

      // Verify Discord CTA button color is #5865F2
      final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('onboarding_discord_cta_button')));
      expect(button.style?.backgroundColor?.resolve({}),
          equals(const Color(0xFF5865F2)));

      // Tap Discord CTA
      await tester.tap(find.byKey(const Key('onboarding_auth_discord')));
      await tester.pumpAndSettle();

      // Profile setup fields
      expect(find.byKey(const Key('profile_setup_display_name_input')),
          findsOneWidget);
      expect(find.byKey(const Key('profile_setup_username_input')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_avatar_picker')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_favorite_format_picker')),
          findsOneWidget);
      expect(
          find.byKey(const Key('profile_setup_submit_button')), findsOneWidget);

      // Scroll to submit button and tap
      await tester.ensureVisible(find.byKey(const Key('profile_setup_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_setup_submit_button')));
      await tester.pumpAndSettle();

      // Step 3 transition
      expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
    });

    testWidgets('Step 2 (Business): Store lookup & 6-digit OTP verification',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Select Business
      await tester.tap(find.byKey(const Key('onboarding_account_type_business')));
      await tester.pumpAndSettle();

      // Places lookup input
      expect(find.byKey(const Key('business_store_lookup_input')), findsOneWidget);
      expect(find.byKey(const Key('business_otp_input')), findsOneWidget);
      expect(find.byKey(const Key('business_verify_otp_button')), findsOneWidget);

      // Enter store lookup & details
      await tester.enterText(
          find.byKey(const Key('business_store_lookup_input')), 'TBS Comics');
      await tester.enterText(
          find.byKey(const Key('business_store_address_input')),
          '68 SW Eglin Pkwy');
      await tester.enterText(
          find.byKey(const Key('business_store_phone_input')), '(850) 244-4445');
      await tester.enterText(
          find.byKey(const Key('business_store_website_input')),
          'https://tbscomics.com');

      // Scroll to OTP section
      await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
      await tester.pumpAndSettle();

      // Enter OTP code 123456
      await tester.enterText(
          find.byKey(const Key('business_otp_input')), '123456');
      await tester.ensureVisible(find.byKey(const Key('business_verify_otp_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('business_verify_otp_button')));
      await tester.pumpAndSettle();

      // Step 3 transition
      expect(find.byKey(const Key('onboarding_enter_app_button')), findsOneWidget);
      expect(find.textContaining('LGS Store Verified!'), findsOneWidget);
    });

    testWidgets('Step 1 (Guest): Continue as Guest transitions smoothly',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_continue_as_guest')));
      await tester.pumpAndSettle();

      // Guest action completes without crash
      expect(find.byKey(const Key('onboarding_welcome_screen')), findsOneWidget);
    });
  });
}
