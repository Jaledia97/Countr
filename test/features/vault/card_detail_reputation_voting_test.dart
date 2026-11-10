import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'card-reputation-test-1',
    String name = 'Rhystic Study',
    int reputationScore = 0,
    int upvotes = 0,
    int downvotes = 0,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'WOT',
      imageUrl: 'https://cards.scryfall.io/normal/front/rhystic.jpg',
      acquiredPrice: 30.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 35.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: jsonEncode({
        'collector_number': '25',
        'set': 'wot',
        'cmc': 3.0,
        'reputation_score': reputationScore,
        'upvotes': upvotes,
        'downvotes': downvotes,
        'oracle_text': 'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
      }),
    );
  }

  Widget createTestWidget(VaultItem item) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CardDetailSheet(item: item),
        ),
      ),
    );
  }

  group('Feature 22 - CardDetailSheet Reputation Upvote/Downvote UI', () {
    testWidgets('renders upvote, reputation score, and downvote buttons in sheet header bar', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));
      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final closeFinder = find.byKey(const Key('card_detail_close_button'));

      expect(upvoteFinder, findsOneWidget);
      expect(scoreFinder, findsOneWidget);
      expect(downvoteFinder, findsOneWidget);
      expect(closeFinder, findsOneWidget);

      // Verify horizontal arrangement: upvote < score < downvote < close
      final upvoteX = tester.getTopLeft(upvoteFinder).dx;
      final scoreX = tester.getTopLeft(scoreFinder).dx;
      final downvoteX = tester.getTopLeft(downvoteFinder).dx;
      final closeX = tester.getTopLeft(closeFinder).dx;

      expect(upvoteX < scoreX, isTrue);
      expect(scoreX < downvoteX, isTrue);
      expect(downvoteX < closeX, isTrue);

      // Verify initial score is 0
      final scoreText = tester.widget<Text>(scoreFinder);
      expect(scoreText.data, equals('0'));
      expect(scoreText.style?.color, equals(AppColors.textPrimary));
    });

    testWidgets('tapping upvote sets score to 1 with emerald highlight, tapping again toggles to 0', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      // Tap upvote
      await tester.tap(upvoteFinder);
      await tester.pump();

      var scoreText = tester.widget<Text>(scoreFinder);
      expect(scoreText.data, equals('1'));
      expect(scoreText.style?.color, equals(AppColors.accentEmerald));

      var upvoteIcon = tester.widget<Icon>(
        find.descendant(of: upvoteFinder, matching: find.byType(Icon)),
      );
      expect(upvoteIcon.color, equals(AppColors.accentEmerald));

      // Tap upvote again to toggle off
      await tester.tap(upvoteFinder);
      await tester.pump();

      scoreText = tester.widget<Text>(scoreFinder);
      expect(scoreText.data, equals('0'));
      expect(scoreText.style?.color, equals(AppColors.textPrimary));

      upvoteIcon = tester.widget<Icon>(
        find.descendant(of: upvoteFinder, matching: find.byType(Icon)),
      );
      expect(upvoteIcon.color, equals(AppColors.textMuted));
    });

    testWidgets('tapping downvote sets score to -1 with amber highlight, tapping again toggles to 0', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      // Tap downvote
      await tester.tap(downvoteFinder);
      await tester.pump();

      var scoreText = tester.widget<Text>(scoreFinder);
      expect(scoreText.data, equals('-1'));
      expect(scoreText.style?.color, equals(AppColors.accentAmber));

      var downvoteIcon = tester.widget<Icon>(
        find.descendant(of: downvoteFinder, matching: find.byType(Icon)),
      );
      expect(downvoteIcon.color, equals(AppColors.accentAmber));

      // Tap downvote again to toggle off
      await tester.tap(downvoteFinder);
      await tester.pump();

      scoreText = tester.widget<Text>(scoreFinder);
      expect(scoreText.data, equals('0'));
      expect(scoreText.style?.color, equals(AppColors.textPrimary));

      downvoteIcon = tester.widget<Icon>(
        find.descendant(of: downvoteFinder, matching: find.byType(Icon)),
      );
      expect(downvoteIcon.color, equals(AppColors.textMuted));
    });

    testWidgets('switching directly between upvote and downvote flips cleanly', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      // 1. Upvote (+1)
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('1'));

      // 2. Downvote (-1, delta -2)
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('-1'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentAmber));

      // 3. Upvote (+1, delta +2)
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('1'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentEmerald));
    });

    testWidgets('320px viewport with 2.0x font scale renders reputation cluster with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final card = createTestCard();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: createTestWidget(card),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_upvote_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_reputation_score')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_downvote_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_close_button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
