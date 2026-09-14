import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/collections_accordion.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/main.dart';

void main() {
  group('Countr Phase 1 Shell & Foundation Tests', () {
    testWidgets('Renders Main Shell with 5 bottom navigation targets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CountrApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header App Bar
      expect(find.text('Countr'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Verify Bottom Navigation 5 Targets
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
      expect(find.text('Decks'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);
    });

    testWidgets('Reusable PostHeader and PostActionBar render correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PostHeader(
                  username: '@Jomel',
                  avatarInitials: 'JA',
                  timestamp: '2 Hours ago',
                  locationTag: 'TBS Comics',
                ),
                PostActionBar(
                  initialHypeCount: 42,
                  commentCount: 14,
                ),
              ],
            ),
          ),
        ),
      );

      // PostHeader assertions
      expect(find.text('@Jomel'), findsOneWidget);
      expect(find.text('JA'), findsOneWidget);
      expect(find.text('2 Hours ago'), findsOneWidget);
      expect(find.text('TBS Comics'), findsOneWidget);

      // PostActionBar 4 distinct action buttons
      expect(find.text('HYPE (42)'), findsOneWidget);
      expect(find.text('COMMENT (14)'), findsOneWidget);
      expect(find.text('WISHLIST'), findsOneWidget);
      expect(find.text('TRADE'), findsOneWidget);
    });

    testWidgets('Tapping Center Scanner opens full-screen modal labeled "Scanner Camera Active"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CountrApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Center Scanner button
      await tester.tap(find.text('Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify full-screen placeholder modal label
      expect(find.text('Scanner Camera Active'), findsOneWidget);
      expect(find.text('RAW CARD'), findsOneWidget);
      expect(find.text('SLAB / GRADED'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Scanner Camera Active'), findsNothing);
    });

    testWidgets('Tapping Menu opens Morphing Global Command Center',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CountrApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Menu (Far Right, Index 4)
      await tester.tap(find.text('Menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Command Center modal content
      expect(find.text('COMMAND CENTER'), findsOneWidget);
      expect(find.text('Collections +'), findsOneWidget);

      // Scroll down inside the Command Center modal
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pump();
      expect(find.text('Play / Track +'), findsOneWidget);

      // Close Command Center
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('COMMAND CENTER'), findsNothing);
    });

    testWidgets('Command Center Collections accordion updates Riverpod activeGameContextProvider',
        (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CollectionsAccordion(
                onGameSelected: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default state
      expect(container.read(activeGameContextProvider), 'Magic: The Gathering');

      // Tap Pokémon TCG
      await tester.tap(find.text('Pokémon TCG'));
      await tester.pumpAndSettle();

      // Verify Riverpod state updated
      expect(container.read(activeGameContextProvider), 'Pokémon TCG');
    });

    testWidgets('Play/Track accordion reveals nested game modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play / Track +'), findsOneWidget);
      expect(find.text('MTG'), findsOneWidget);
      expect(find.text('Pokémon'), findsOneWidget);
      expect(find.text('Lorcana'), findsOneWidget);

      // Tap MTG to reveal Grandchildren: Commander, Standard, Draft
      await tester.tap(find.text('MTG'));
      await tester.pumpAndSettle();

      expect(find.text('Commander'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // Tap Pokémon to reveal Grandchildren: Standard, GLC
      await tester.tap(find.text('Pokémon'));
      await tester.pumpAndSettle();

      expect(find.text('GLC'), findsOneWidget);
    });

    testWidgets('Navigating between Feed, Vault, and Decks freezes state locally',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CountrApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Vault tab
      await tester.tap(find.text('Vault'));
      await tester.pumpAndSettle();

      expect(find.text('MTG Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);

      // Increment count on Vault
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('Total Tracked Items: 2'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Black Lotus');
      await tester.pumpAndSettle();

      // Switch to Decks tab
      await tester.tap(find.text('Decks'));
      await tester.pumpAndSettle();
      expect(find.text('Deck Builder'), findsOneWidget);

      // Switch back to Vault tab
      await tester.tap(find.text('Vault'));
      await tester.pumpAndSettle();

      // Verify state was frozen and preserved
      expect(find.text('Total Tracked Items: 2'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
        'VaultScreen App Bar dropdown selector updates Riverpod activeGameContextProvider and title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CountrApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Vault tab
      await tester.tap(find.text('Vault'));
      await tester.pumpAndSettle();

      // Initial title based on default "Magic: The Gathering"
      expect(find.text('MTG Vault'), findsOneWidget);

      // Tap the dropdown title to open PopupMenu
      await tester.tap(find.text('MTG Vault'));
      await tester.pumpAndSettle();

      // Verify all 4 TCG options are present
      expect(find.text('All Collections'), findsOneWidget);
      expect(find.text('Magic: The Gathering'), findsOneWidget);
      expect(find.text('Pokémon TCG'), findsOneWidget);
      expect(find.text('Comic Books'), findsOneWidget);

      // Select "Pokémon TCG"
      await tester.tap(find.text('Pokémon TCG'));
      await tester.pumpAndSettle();

      // Verify title dynamically updated to "Pokémon Vault"
      expect(find.text('Pokémon Vault'), findsOneWidget);

      // Tap dropdown again and select "All Collections"
      await tester.tap(find.text('Pokémon Vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Collections'));
      await tester.pumpAndSettle();

      // Verify title updated to "My Vault"
      expect(find.text('My Vault'), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
