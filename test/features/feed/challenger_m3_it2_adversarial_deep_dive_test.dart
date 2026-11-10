// Copyright (c) 2026 Countr. All rights reserved.
// Deep Adversarial Stress Suite for Milestone 3 Iteration 2 (Challenger 1)
// Focus areas:
// 1. Full emoji picker modal bottom sheet at 240px-400px width and short viewports (400px height).
// 2. Comprehensive Reddit voting flips (+1, 0, -1) and score state machines.
// 3. Extreme content saturation (10 pills, extreme numbers, trade button) at 240px.
// 4. State synchronization via didUpdateWidget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/feed/presentation/widgets/post_action_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestBed({
    required Widget child,
    double? width,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: width != null
            ? Center(
                child: SizedBox(
                  width: width,
                  child: child,
                ),
              )
            : child,
      ),
    );
  }

  group('ADVERSARIAL STRESS 1: Full Emoji Picker Modal Bottom Sheet across Viewports', () {
    const viewports = [400.0, 320.0, 280.0, 260.0, 240.0];

    for (final width in viewports) {
      testWidgets('Full emoji picker modal opens and selects emoji without overflow at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        String? selectedReaction;

        await tester.pumpWidget(buildTestBed(
          width: width,
          child: PostActionBar(
            postId: 'post-modal-test-${width.toInt()}',
            initialNetScore: 50,
            commentCount: 10,
            onReactionSelected: (emoji) => selectedReaction = emoji,
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 1. Open MRU selector
        await tester.tap(find.byKey(const Key('post_action_react_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);

        // 2. Tap full emoji picker (+) button to open modal bottom sheet
        await tester.tap(find.byKey(const Key('mru_full_picker_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('React with Emoji'), findsOneWidget);

        // 3. Verify modal emojis are present
        expect(find.text('🎉'), findsOneWidget);
        expect(find.text('👑'), findsOneWidget);

        // 4. Tap emoji '🎉'
        await tester.tap(find.text('🎉'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(selectedReaction, equals('🎉'));

        // Modal closed
        expect(find.text('React with Emoji'), findsNothing);

        // Active pill is rendered
        expect(find.byKey(const Key('reaction_pill_🎉')), findsOneWidget);
        expect(find.text('🎉 1'), findsOneWidget);
      });
    }

    testWidgets('Full emoji picker modal under constrained vertical viewport (360x420) scrolls with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360.0 * 2.0, 420.0 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBed(
        width: 360,
        child: const PostActionBar(
          postId: 'post-short-viewport',
          initialNetScore: 1,
          commentCount: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Open MRU selector
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();

      // Open full emoji picker modal
      await tester.tap(find.byKey(const Key('mru_full_picker_button')));
      await tester.pumpAndSettle();

      // Must NOT throw RenderFlex overflow on the bottom
      expect(tester.takeException(), isNull);
      expect(find.text('React with Emoji'), findsOneWidget);

      // Scroll modal
      await tester.drag(find.text('React with Emoji'), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ADVERSARIAL STRESS 2: Reddit Voting State Machine & Edge Flips', () {
    testWidgets('Initial negative score (-10) and initial downvote (-1) flips to upvote (+1)', (tester) async {
      int? reportedVote;
      await tester.pumpWidget(buildTestBed(
        child: PostActionBar(
          postId: 'post-vote-edge-1',
          initialNetScore: -10,
          initialUserVote: -1,
          commentCount: 3,
          onVoteChanged: (v) => reportedVote = v,
        ),
      ));
      await tester.pumpAndSettle();

      final scoreFinder = find.byKey(const Key('post_net_score_text'));
      final upvoteFinder = find.byKey(const Key('post_upvote_button'));
      final downvoteFinder = find.byKey(const Key('post_downvote_button'));

      expect(tester.widget<Text>(scoreFinder).data, equals('-10'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFF7193FF)));

      // Flip from -1 directly to +1: delta must be +2, net score moves from -10 to -8
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(1));
      expect(tester.widget<Text>(scoreFinder).data, equals('-8'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFFFF4500)));

      // Flip back from +1 to -1: delta must be -2, net score moves from -8 to -10
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(-1));
      expect(tester.widget<Text>(scoreFinder).data, equals('-10'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFF7193FF)));

      // Downvote again to toggle to 0: delta must be +1, net score moves from -10 to -9
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(0));
      expect(tester.widget<Text>(scoreFinder).data, equals('-9'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(Colors.white));
    });

    testWidgets('Initial positive score (10) and initial upvote (+1) flips to downvote (-1)', (tester) async {
      int? reportedVote;
      await tester.pumpWidget(buildTestBed(
        child: PostActionBar(
          postId: 'post-vote-edge-2',
          initialNetScore: 10,
          initialUserVote: 1,
          commentCount: 3,
          onVoteChanged: (v) => reportedVote = v,
        ),
      ));
      await tester.pumpAndSettle();

      final scoreFinder = find.byKey(const Key('post_net_score_text'));
      final upvoteFinder = find.byKey(const Key('post_upvote_button'));
      final downvoteFinder = find.byKey(const Key('post_downvote_button'));

      expect(tester.widget<Text>(scoreFinder).data, equals(10.toString()));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFFFF4500)));

      // Flip from +1 directly to -1: delta must be -2, net score moves from 10 to 8
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(-1));
      expect(tester.widget<Text>(scoreFinder).data, equals('8'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFF7193FF)));

      // Toggle off -1 to 0: delta must be +1, net score moves from 8 to 9
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(0));
      expect(tester.widget<Text>(scoreFinder).data, equals('9'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(Colors.white));

      // Upvote again from 0 to +1: delta must be +1, net score moves from 9 to 10
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      expect(reportedVote, equals(1));
      expect(tester.widget<Text>(scoreFinder).data, equals('10'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(const Color(0xFFFF4500)));
    });

    testWidgets('Tapping score text (post_action_hype) acts as upvote trigger', (tester) async {
      int? reportedVote;
      await tester.pumpWidget(buildTestBed(
        child: PostActionBar(
          postId: 'post-hype-tap',
          initialNetScore: 0,
          initialUserVote: 0,
          commentCount: 0,
          onVoteChanged: (v) => reportedVote = v,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap score text
      await tester.tap(find.byKey(const Key('post_action_hype')));
      await tester.pumpAndSettle();

      expect(reportedVote, equals(1));
      expect(tester.widget<Text>(find.byKey(const Key('post_net_score_text'))).data, equals('1'));

      // Tap again to toggle off
      await tester.tap(find.byKey(const Key('post_action_hype')));
      await tester.pumpAndSettle();

      expect(reportedVote, equals(0));
      expect(tester.widget<Text>(find.byKey(const Key('post_net_score_text'))).data, equals('0'));
    });
  });

  group('ADVERSARIAL STRESS 3: Extreme Content Saturation & Layout at 240px', () {
    testWidgets('PostActionBar with trade button, 10 active reactions, huge scores at 240px renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(240.0 * 2.0, 800.0 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool tradeTapped = false;
      bool commentTapped = false;

      await tester.pumpWidget(buildTestBed(
        width: 240.0,
        child: PostActionBar(
          postId: 'post-saturated-extreme',
          initialNetScore: -999999,
          initialUserVote: -1,
          commentCount: 999999,
          initialReactions: const {
            '🔥': 999,
            '❤️': 888,
            '😂': 777,
            '🤯': 666,
            '💎': 555,
            '🎉': 444,
            '🚀': 333,
            '💯': 222,
            '👏': 111,
            '👀': 99,
          },
          userReactions: const {'🔥', '💎', '🚀'},
          onTradeTap: () => tradeTapped = true,
          onCommentTap: () => commentTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Zero RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify trade button is present and clickable
      final tradeBtnFinder = find.byKey(const Key('post_action_trade'));
      expect(tradeBtnFinder, findsOneWidget);
      await tester.tap(tradeBtnFinder);
      await tester.pumpAndSettle();
      expect(tradeTapped, isTrue);

      // Verify comment button is present and clickable
      final commentBtnFinder = find.byKey(const Key('post_comment_button'));
      expect(commentBtnFinder, findsOneWidget);
      await tester.tap(commentBtnFinder);
      await tester.pumpAndSettle();
      expect(commentTapped, isTrue);

      // Verify voting pill is present and downvote button is clickable
      final upvoteBtnFinder = find.byKey(const Key('post_upvote_button'));
      expect(upvoteBtnFinder, findsOneWidget);
      await tester.tap(upvoteBtnFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open MRU selector
      await tester.tap(find.byKey(const Key('post_action_react_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('reaction_mru_selector')), findsOneWidget);
    });
  });

  group('ADVERSARIAL STRESS 4: didUpdateWidget Reactivity', () {
    testWidgets('didUpdateWidget updates netScore and userVote dynamically when parent rebuilds', (tester) async {
      int score = 5;
      int vote = 0;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildTestBed(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      score = 25;
                      vote = 1;
                    });
                  },
                  child: const Text('Update External State'),
                ),
                PostActionBar(
                  postId: 'post-reactive-test',
                  initialNetScore: score,
                  initialUserVote: vote,
                  commentCount: 2,
                ),
              ],
            ),
          );
        },
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('post_net_score_text'))).data, equals('5'));

      // Tap button to change external state
      await tester.tap(find.text('Update External State'));
      await tester.pumpAndSettle();

      // PostActionBar didUpdateWidget should reflect the new netScore and userVote
      expect(tester.widget<Text>(find.byKey(const Key('post_net_score_text'))).data, equals('25'));
      expect(
        tester.widget<Text>(find.byKey(const Key('post_net_score_text'))).style?.color,
        equals(const Color(0xFFFF4500)),
      );
    });
  });
}
