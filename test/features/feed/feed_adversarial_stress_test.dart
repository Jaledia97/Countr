// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for Feed Post Widgets & ManaText.
// Tests long mana strings, 50-symbol contiguous sequences, complex hybrid/Phyrexian
// symbols, extreme viewports (320px, 240px), and high font scaling (2.0x).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/widgets/multi_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/text_post_body.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithConstraints({
    required Widget child,
    double width = 360,
    double height = 800,
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('TextPostBody - Empirical Adversarial Stress Testing', () {
    const contiguous50Symbols =
        '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'
        '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'
        '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'; // 50 consecutive symbols without spaces

    const allHybridsAndPhyrexian =
        'Pay {2/W}{2/U}{2/B}{2/R}{2/G} and {W/U}{U/B}{B/R}{R/G}{G/W} or '
        '{W/P}{U/P}{B/P}{R/P}{G/P}{C/P} with {G/U/P}{W/B/P} and {C/W}{C/U}. '
        'Untap {Q}, tap {T}, gain {E}, check {CHAOS} {TK} {A} {½} {∞} {1000000}!';

    testWidgets('renders contiguous 50 mana symbols without spaces on standard 360px viewport', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const TextPostBody(text: contiguous50Symbols),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(50));
    });

    testWidgets('renders contiguous 50 mana symbols on narrow 320px viewport without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        width: 320,
        height: 640,
        child: const TextPostBody(text: contiguous50Symbols),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(50));
    });

    testWidgets('renders all hybrid, Phyrexian, un-set, and keyword symbols without crashing', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const TextPostBody(text: allHybridsAndPhyrexian),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaText), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsWidgets);
    });

    testWidgets('renders under extreme 2.0x font scaling and narrow 320px viewport with zero overflow', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        width: 320,
        height: 640,
        textScaleFactor: 2.0,
        child: const TextPostBody(text: allHybridsAndPhyrexian),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty string and whitespace-only text gracefully', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const Column(
          children: [
            TextPostBody(text: ''),
            TextPostBody(text: '   \n  \t  '),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
    });

    testWidgets('renders nested, unclosed, and chaotic brackets without throwing format exceptions', (tester) async {
      const chaotic = '{{{{W}}}}}{U}{B/R/G/extra}{}{}{{{}} {2 and tap} {{1000000}}';
      await tester.pumpWidget(wrapWithConstraints(
        child: const TextPostBody(text: chaotic),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('SinglePullPostBody - Empirical Adversarial Stress Testing', () {
    const extremeCommentary =
        'Massive pull from collector booster! Cast with {W}{W}{U}{U}{B}{B}{R}{R}{G}{G} '
        'or activate {2/W}{2/U} and sacrifice {P/B}! Market value is insane.';

    testWidgets('renders single pull with extreme mana commentary on 360px viewport', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const SinglePullPostBody(
          commentary: extremeCommentary,
          cardTitle: 'Progenitus Foil Serialized #001/500',
          cardSubtitle: 'Modern Horizons 3 • Mythic Rare Foil',
          cardRarity: 'MYTHIC',
          estimatedValue: '\$1,450.00',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SinglePullPostBody), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsWidgets);
    });

    testWidgets('renders single pull with extreme commentary on narrow 320px viewport without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        width: 320,
        height: 640,
        child: const SinglePullPostBody(
          commentary: extremeCommentary,
          cardTitle: 'The Ur-Dragon Extended Art Foil',
          cardSubtitle: 'Commander Masters • Special',
          cardRarity: 'SPECIAL',
          estimatedValue: '\$250.00',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders single pull with null and empty commentary without error', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const Column(
          children: [
            SinglePullPostBody(
              commentary: null,
              cardTitle: 'Card With Null Commentary',
            ),
            SinglePullPostBody(
              commentary: '',
              cardTitle: 'Card With Empty Commentary',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('MultiPullPostBody - Empirical Adversarial Stress Testing', () {
    const multiPullCommentary =
        'Box break results! Pulled {W/U} Teferi, {4}{W}{U}{B}{R}{G} Ur-Dragon, '
        'and paid {1000000} for Gleemax! Total value through the roof.';

    testWidgets('renders multi-pull with extreme mana commentary on 360px viewport', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        child: const MultiPullPostBody(
          commentary: multiPullCommentary,
          pullItems: ['Hit 1', 'Hit 2', 'Hit 3', 'Hit 4', 'Hit 5', 'Hit 6'],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MultiPullPostBody), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsWidgets);
    });

    testWidgets('renders multi-pull with extreme commentary on narrow 320px viewport without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(wrapWithConstraints(
        width: 320,
        height: 640,
        child: const MultiPullPostBody(
          commentary: multiPullCommentary,
          pullItems: ['Hit 1', 'Hit 2', 'Hit 3', 'Hit 4'],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('PostCard - End-to-End Adversarial Integration Stress Testing', () {
    testWidgets('renders all 3 post types under 320px viewport with 1.5x font scaling with zero RenderFlex overflows', (tester) async {
      final posts = [
        const FeedPost(
          id: 'post-adv-text',
          type: PostType.text,
          username: '@CommanderMaster',
          avatarInitials: 'CM',
          timestamp: '2h ago',
          locationTag: 'TBS Comics & Games',
          textContent:
              'Combos to test tonight: {2/W}{2/U} into {W/P}{U/P} and {G/U/P} '
              'holding {T} for {1}{G}{G} and {1000000} generic mana backup!',
          hypeCount: 42,
          commentCount: 19,
        ),
        const FeedPost(
          id: 'post-adv-single',
          type: PostType.singlePull,
          username: '@LuckyPuller',
          avatarInitials: 'LP',
          timestamp: '3h ago',
          locationTag: 'Local Game Store',
          textContent: 'Just cracked Progenitus ({W}{W}{U}{U}{B}{B}{R}{R}{G}{G})! Foil etched.',
          cardTitle: 'Progenitus — Foil Etched',
          cardSubtitle: 'Double Masters 2022',
          cardRarity: 'MYTHIC',
          estimatedValue: '\$85.00',
          hypeCount: 104,
          commentCount: 31,
        ),
        const FeedPost(
          id: 'post-adv-multi',
          type: PostType.multiPull,
          username: '@BoxBreaker99',
          avatarInitials: 'BB',
          timestamp: '5h ago',
          locationTag: 'Collector Expo',
          textContent: 'Modern Horizons 3 pack results: hit {3}{G}{G}, {W/U}, and {C}{C} Eldrazi.',
          pullImages: ['Art 1', 'Art 2', 'Art 3', 'Art 4'],
          hypeCount: 88,
          commentCount: 12,
        ),
      ];

      await tester.pumpWidget(wrapWithConstraints(
        width: 320,
        height: 800,
        textScaleFactor: 1.5,
        child: Column(
          children: posts.map((p) => PostCard(post: p)).toList(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PostCard), findsNWidgets(3));
      expect(find.byType(ManaSymbolIcon), findsWidgets);
    });

    testWidgets('renders PostCard under extreme narrow 240px width with zero RenderFlex overflows', (tester) async {
      const post = FeedPost(
        id: 'post-ultra-narrow',
        type: PostType.text,
        username: '@MinimalWidth',
        avatarInitials: 'MW',
        timestamp: 'Just now',
        locationTag: 'Pocket Pod',
        textContent: 'Testing ultra narrow: {W}{U}{B}{R}{G} symbols galore!',
        hypeCount: 1,
        commentCount: 0,
      );

      await tester.pumpWidget(wrapWithConstraints(
        width: 240,
        height: 600,
        child: const PostCard(post: post),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
