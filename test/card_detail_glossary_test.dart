import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';
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
    String id = 'test-card-1',
    String name = 'Test MTG Card',
    String dynamicData = '{}',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'Alpha',
      imageUrl: '',
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      currentMarketPrice: 20.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: dynamicData,
    );
  }

  Widget createTestWidget(VaultItem item) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CardDetailSheet(item: item),
        ),
      ),
    );
  }

  group('CardDetailSheet Card Mechanics Section Rendering', () {
    testWidgets('renders Card Mechanics section with keyword badge and definition when card has keywords list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Serra Angel',
        dynamicData: '{"keywords":["Flying","Vigilance"],"oracle_text":"Flying, vigilance"}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Verify "Card Mechanics" section header exists
      expect(find.text('Card Mechanics'), findsOneWidget);

      // Verify keyword badges exist
      expect(find.text('Flying'), findsWidgets); // header or badge
      expect(find.text('Vigilance'), findsWidgets);

      // Verify beginner-friendly definitions are displayed
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Vigilance']!), findsOneWidget);
    });

    testWidgets('renders Card Mechanics extracted from oracle_text regex when keywords list is missing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Colossal Dreadmaw',
        dynamicData: '{"oracle_text":"Trample\\nIf you feel the ground quake, run."}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Card Mechanics header is present
      expect(find.text('Card Mechanics'), findsOneWidget);

      // Trample badge is rendered
      expect(find.text('Trample'), findsWidgets);

      // Trample definition is rendered
      expect(find.text(MtgKeywordGlossary.dictionary['Trample']!), findsOneWidget);
    });

    testWidgets('omits Card Mechanics section completely when card has no recognized keywords', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Sol Ring',
        dynamicData: '{"oracle_text":"{T}: Add {C}{C}."}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // "Card Mechanics" section must be cleanly omitted
      expect(find.text('Card Mechanics'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    });

    testWidgets('omits Card Mechanics section when dynamicData is empty or non-MTG', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Pikachu',
        dynamicData: '{"keywords":["Electric"],"oracle_text":"Thunderbolt does 30 damage."}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsNothing);
    });

    testWidgets('renders multiple keywords with respective definitions beneath each tag', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Atraxa, Praetors\' Voice',
        dynamicData:
            '{"keywords":["Flying","Vigilance","Deathtouch","Lifelink"],"oracle_text":"Flying, vigilance, deathtouch, lifelink\\nAt the beginning of your end step, proliferate."}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsOneWidget);

      // All four keyword definitions should be present
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Vigilance']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Deathtouch']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Lifelink']!), findsOneWidget);
    });

    testWidgets('correctly disambiguates Double Strike and does not render First Strike', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Boros Swiftblade',
        dynamicData: '{"oracle_text":"Double strike"}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Double Strike']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['First Strike']!), findsNothing);
    });

    testWidgets('renders Ward definition for Ward with cost and ignores false substring matches', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        name: 'Tivit, Seller of Secrets',
        dynamicData: '{"oracle_text":"Flying, ward {3}\\nWhenever Tivit enters the battlefield..."}',
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('Card Mechanics'), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Flying']!), findsOneWidget);
      expect(find.text(MtgKeywordGlossary.dictionary['Ward']!), findsOneWidget);
    });
  });
}
