// Copyright (c) 2026 Countr. All rights reserved.
// Widget test suite verifying ManaText integration in Feed Post widgets.

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

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('TextPostBody - MTG Mana Symbology Rendering', () {
    testWidgets('renders plain text without mana symbols using ManaText without icons', (tester) async {
      await tester.pumpWidget(wrap(
        const TextPostBody(
          text: 'Looking for a casual Commander pod tonight at TBS Comics!',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextPostBody), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('Looking for a casual Commander pod tonight at TBS Comics!'), findsOneWidget);
    });

    testWidgets('renders social post with inline mana symbols for Edgar Markov {3}{R}{W}{B}', (tester) async {
      await tester.pumpWidget(wrap(
        const TextPostBody(
          text: 'Bringing Edgar Markov ({3}{R}{W}{B}) with heavy {B} sacrifice synergies!',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextPostBody), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);

      // {3}, {R}, {W}, {B}, {B} = 5 symbols
      final icons = find.byType(ManaSymbolIcon);
      expect(icons, findsNWidgets(5));

      final iconWidgets = tester.widgetList<ManaSymbolIcon>(icons).toList();
      expect(iconWidgets[0].assetPath, equals('assets/symbology/3.svg'));
      expect(iconWidgets[1].assetPath, equals('assets/symbology/R.svg'));
      expect(iconWidgets[2].assetPath, equals('assets/symbology/W.svg'));
      expect(iconWidgets[3].assetPath, equals('assets/symbology/B.svg'));
      expect(iconWidgets[4].assetPath, equals('assets/symbology/B.svg'));
    });

    testWidgets('renders complex deck primer combo notation with middle alignment', (tester) async {
      await tester.pumpWidget(wrap(
        const TextPostBody(
          text: 'T1: Cast {G} elf. T2: Tap {T} for {1}{G}{G}. Activate {W/U} and pay {P/B} life.',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;
      final widgetSpans = (effectiveSpan.children ?? rootSpan.children)!.whereType<WidgetSpan>().toList();

      // All widget spans must have middle alignment
      for (final span in widgetSpans) {
        expect(span.alignment, equals(PlaceholderAlignment.middle));
      }

      // Verify transposable alias {P/B} resolves to BP.svg
      final bpFinder = find.byWidgetPredicate(
        (w) => w is ManaSymbolIcon && w.assetPath == 'assets/symbology/BP.svg',
      );
      expect(bpFinder, findsOneWidget);

      // Verify hybrid {W/U} resolves to WU.svg
      final wuFinder = find.byWidgetPredicate(
        (w) => w is ManaSymbolIcon && w.assetPath == 'assets/symbology/WU.svg',
      );
      expect(wuFinder, findsOneWidget);
    });

    testWidgets('fault-tolerant: malformed brackets and non-mana tags render without crashing', (tester) async {
      await tester.pumpWidget(wrap(
        const TextPostBody(
          text: 'Check this {NotASymbol} and {unclosed tag. Best pulls ever!',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
    });
  });

  group('SinglePullPostBody & MultiPullPostBody - Mana Symbology in Commentary', () {
    testWidgets('SinglePullPostBody renders ManaText in commentary', (tester) async {
      await tester.pumpWidget(wrap(
        const SinglePullPostBody(
          commentary: 'Pulled The One Ring {4}! Serialized 007/100.',
          cardTitle: 'The One Ring',
          cardSubtitle: 'LTR • Foil',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SinglePullPostBody), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/4.svg'));
    });

    testWidgets('MultiPullPostBody renders ManaText in commentary', (tester) async {
      await tester.pumpWidget(wrap(
        const MultiPullPostBody(
          commentary: 'Opening a Modern Horizons 3 box: hit {2}{U}{U} Subtlety!',
          pullItems: ['Hit 1', 'Hit 2', 'Hit 3', 'Hit 4'],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MultiPullPostBody), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);

      // {2}, {U}, {U} = 3 symbols
      expect(find.byType(ManaSymbolIcon), findsNWidgets(3));
    });
  });

  group('PostCard - End-to-End Social Post Integration', () {
    testWidgets('PostCard renders TextPostBody with ManaText seamlessly', (tester) async {
      const post = FeedPost(
        id: 'post-test-1',
        type: PostType.text,
        username: '@MtgCommander',
        avatarInitials: 'MC',
        timestamp: '1h ago',
        locationTag: 'Game Store',
        textContent: 'Need advice: what {R} or {W} removal works best against Atraxa {G}{W}{U}{B}?',
        hypeCount: 15,
        commentCount: 8,
      );

      await tester.pumpWidget(wrap(const PostCard(post: post)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PostCard), findsOneWidget);
      expect(find.byType(TextPostBody), findsOneWidget);
      expect(find.byType(ManaText), findsOneWidget);

      // {R}, {W}, {G}, {W}, {U}, {B} = 6 symbols
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
    });
  });
}
