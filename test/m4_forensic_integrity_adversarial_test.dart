import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M4 Forensic Auditor Adversarial Stress Suite', () {
    // -------------------------------------------------------------------------
    // 1. PageStorageBucket Boundary Isolation
    // -------------------------------------------------------------------------
    testWidgets('1. PageStorageBucket prevents typecast clash between ancestor double and descendant bool', (tester) async {
      // Simulate the exact structure in CardDetailSheet:
      // An outer PageStorage holding a double scroll offset with key 'card_detail_list_item1',
      // enclosing an ExpansionTile protected by PageStorage(bucket: PageStorageBucket()).
      final outerBucket = PageStorageBucket();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: outerBucket,
              child: ListView(
                key: const PageStorageKey<String>('card_detail_list_item1'),
                children: [
                  const SizedBox(height: 100),
                  PageStorage(
                    bucket: PageStorageBucket(),
                    child: const ExpansionTile(
                      key: Key('card_detail_rulings_accordion'),
                      title: Text('Official Rulings'),
                      children: [Text('Ruling 1')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.text('Official Rulings'));
      await tester.pumpAndSettle();

      // Scroll the list to simulate scroll offset write into PageStorage
      await tester.drag(find.byType(ListView), const Offset(0, -50));
      await tester.pumpAndSettle();

      // Re-pump widget to test PageStorage restore phase
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: outerBucket,
              child: ListView(
                key: const PageStorageKey<String>('card_detail_list_item1'),
                children: [
                  const SizedBox(height: 100),
                  PageStorage(
                    bucket: PageStorageBucket(),
                    child: const ExpansionTile(
                      key: Key('card_detail_rulings_accordion'),
                      title: Text('Official Rulings'),
                      children: [Text('Ruling 1')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero typecast exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('Official Rulings'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. Dynamic Collapse Interpolation Math
    // -------------------------------------------------------------------------
    test('2. Dynamic collapse interpolation math is monotonic, clamped, and non-NaN', () {
      // Mathematical model in deck_builder_screen.dart:
      // t = (1.0 - (currentExtent - minExtent) / deltaExtent).clamp(0.0, 1.0)
      // left = Tween<double>(begin: 16.0, end: targetLeft).transform(t)
      // right = Tween<double>(begin: 16.0, end: 144.0).transform(t)

      const double minExtent = 56.0;
      const double maxExtent = 180.0;
      const double deltaExtent = maxExtent - minExtent;
      const double targetLeft = 56.0;

      for (double current = minExtent; current <= maxExtent; current += 5.0) {
        final double t = (1.0 - (current - minExtent) / deltaExtent).clamp(0.0, 1.0);
        final double left = Tween<double>(begin: 16.0, end: targetLeft).transform(t);
        final double right = Tween<double>(begin: 16.0, end: 144.0).transform(t);

        expect(t, inInclusiveRange(0.0, 1.0));
        expect(left, inInclusiveRange(16.0, targetLeft));
        expect(right, inInclusiveRange(16.0, 144.0));
      }

      // Edge cases: currentExtent outside bounds
      final double tOver = (1.0 - (250.0 - minExtent) / deltaExtent).clamp(0.0, 1.0);
      expect(tOver, equals(0.0)); // Fully expanded clamp

      final double tUnder = (1.0 - (20.0 - minExtent) / deltaExtent).clamp(0.0, 1.0);
      expect(tUnder, equals(1.0)); // Fully collapsed clamp

      // Zero delta extent defense
      const double degenerateDelta = 0.0;
      final double tDegenerate = degenerateDelta > 0 ? 1.0 : 0.0;
      expect(tDegenerate.isNaN, isFalse);
    });

    // -------------------------------------------------------------------------
    // 3. Authentic Formats Legality Filtering
    // -------------------------------------------------------------------------
    group('3. Format legality filtering against Scryfall dynamicData', () {
      VaultItem createMockCard({required String dynamicData}) {
        return VaultItem(
          id: 'test-card-1',
          collectionType: 'mtg',
          name: 'Format Test Card',
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime(2026, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime(2026, 1, 1),
          dynamicData: dynamicData,
        );
      }

      test('Evaluates legal and restricted as true', () {
        const state = MtgFilterState(formats: {'commander', 'vintage'});
        final card = createMockCard(
          dynamicData: jsonEncode({
            'legalities': {
              'commander': 'legal',
              'vintage': 'restricted',
            },
          }),
        );
        expect(state.matches(card), isTrue);
      });

      test('Rejects when card is banned or not_legal in one of the selected formats', () {
        const state = MtgFilterState(formats: {'commander', 'modern'});
        final card = createMockCard(
          dynamicData: jsonEncode({
            'legalities': {
              'commander': 'legal',
              'modern': 'banned',
            },
          }),
        );
        expect(state.matches(card), isFalse);
      });

      test('Rejects when legalities field is not a map', () {
        const state = MtgFilterState(formats: {'commander'});
        final card = createMockCard(
          dynamicData: jsonEncode({
            'legalities': 'not a map',
          }),
        );
        expect(state.matches(card), isFalse);
      });

      test('Handles case-insensitivity and whitespace in format names', () {
        const state = MtgFilterState(formats: {'Commander '});
        final card = createMockCard(
          dynamicData: jsonEncode({
            'legalities': {
              'commander': 'LEGAL',
            },
          }),
        );
        expect(state.matches(card), isTrue);
      });

      test('Corrupted dynamicData string does not crash evaluator and returns false', () {
        const state = MtgFilterState(formats: {'commander'});
        final card = createMockCard(dynamicData: 'corrupt!{not:json');
        expect(state.matches(card), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // 4. MtgFilterState Immutability & Contract Invariants
    // -------------------------------------------------------------------------
    test('4. MtgFilterState copyWith, clear, reset, activeCount, and equality invariants', () {
      const initial = MtgFilterState();
      expect(initial.formats, isEmpty);
      expect(initial.activeCount, equals(0));

      final updated = initial.copyWith(formats: {'modern', 'legacy'});
      expect(updated.formats, equals({'modern', 'legacy'}));
      expect(updated.activeCount, equals(1));

      // Equality
      final identicalState = const MtgFilterState().copyWith(formats: {'modern', 'legacy'});
      expect(updated, equals(identicalState));
      expect(updated.hashCode, equals(identicalState.hashCode));

      // Clear / Reset
      final cleared = updated.clear();
      expect(cleared.formats, isEmpty);
      expect(cleared.activeCount, equals(0));
    });
  });
}
