import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Trade Lifecycle DAO Tests (cancelTradeProposal & counterTradeProposal)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed user profiles
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-alice',
          username: '@alice',
          displayName: 'Alice',
          avatarUrl: const Value('https://example.com/alice.png'),
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-bob',
          username: '@bob',
          displayName: 'Bob',
          avatarUrl: const Value('https://example.com/bob.png'),
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-charlie',
          username: '@charlie',
          displayName: 'Charlie',
          avatarUrl: const Value('https://example.com/charlie.png'),
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('cancelTradeProposal: proposer successfully cancels pending trade offer', () async {
      // 1. Alice creates trade proposal for Bob
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['card-1', 'card-2'],
        requestedCardIds: ['card-3'],
        offeredTotalValue: 120.0,
        requestedTotalValue: 115.0,
        note: 'Let us make this deal!',
      );

      expect(proposal.status, equals('pending'));

      // Check notification was sent to Bob
      final notifsBefore = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(proposal.id)))
          .get();
      expect(notifsBefore.length, equals(1));
      expect(notifsBefore.first.isActioned, isFalse);

      // 2. Alice cancels the trade proposal
      await db.inboxDao.cancelTradeProposal(
        proposal.id,
        currentUserId: 'user-alice',
      );

      // 3. Verify proposal status transitioned to 'cancelled'
      final updatedProposal = await db.inboxDao.getTradeProposal(proposal.id);
      expect(updatedProposal, isNotNull);
      expect(updatedProposal!.status, equals('cancelled'));

      // 4. Verify associated notifications actioned to 'cancelled'
      final notifsAfter = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(proposal.id)))
          .get();
      expect(notifsAfter.first.isActioned, isTrue);
      expect(notifsAfter.first.status, equals('cancelled'));

      // 5. Verify cancellation chat message was emitted to Bob
      final messages = await (db.select(db.messages)
            ..where((t) =>
                t.senderId.equals('user-alice') &
                t.recipientId.equals('user-bob')))
          .get();
      expect(messages.any((m) => m.messageText.contains('Trade proposal was cancelled')), isTrue);
    });

    test('cancelTradeProposal: non-proposer cannot cancel the proposal', () async {
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['card-1'],
        requestedCardIds: ['card-2'],
      );

      // Bob tries to cancel proposal created by Alice (must be rejected)
      await db.inboxDao.cancelTradeProposal(
        proposal.id,
        currentUserId: 'user-bob',
      );

      final checkProposal = await db.inboxDao.getTradeProposal(proposal.id);
      expect(checkProposal!.status, equals('pending')); // Remains pending
    });

    test('counterTradeProposal: recipient counters trade offer, transitions prior to countered and creates new pending offer', () async {
      // 1. Alice creates initial proposal for Bob
      final initialProposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['card-alice-1'],
        requestedCardIds: ['card-bob-1', 'card-bob-2'],
        offeredTotalValue: 100.0,
        requestedTotalValue: 150.0,
        note: 'First offer',
      );

      // 2. Bob counters Alice's proposal with an adjusted card list
      final counterProposal = await db.inboxDao.counterTradeProposal(
        initialProposal.id,
        proposerId: 'user-bob',
        receiverId: 'user-alice',
        offeredCardIds: ['card-bob-1'],
        requestedCardIds: ['card-alice-1'],
        offeredTotalValue: 95.0,
        requestedTotalValue: 100.0,
        proposerCashDelta: 5.0,
        note: 'How about I add \$5 cash instead of the second card?',
      );

      // 3. Verify prior proposal transitioned to 'countered'
      final prior = await db.inboxDao.getTradeProposal(initialProposal.id);
      expect(prior!.status, equals('countered'));

      // 4. Verify prior notifications were actioned to 'countered'
      final priorNotifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(initialProposal.id)))
          .get();
      expect(priorNotifs.first.isActioned, isTrue);
      expect(priorNotifs.first.status, equals('countered'));

      // 5. Verify counter-proposal is created with status 'pending'
      expect(counterProposal.status, equals('pending'));
      expect(counterProposal.proposerId, equals('user-bob'));
      expect(counterProposal.receiverId, equals('user-alice'));
      expect(counterProposal.proposerCashDelta, equals(5.0));
      expect(jsonDecode(counterProposal.offeredCardIdsJson), equals(['card-bob-1']));
      expect(jsonDecode(counterProposal.requestedCardIdsJson), equals(['card-alice-1']));

      // 6. Verify notification dispatched to Alice
      final counterNotifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(counterProposal.id)))
          .get();
      expect(counterNotifs.length, equals(1));
      expect(counterNotifs.first.userId, equals('user-alice'));
      expect(counterNotifs.first.title, equals('New Counter Trade Offer'));

      // 7. Verify counter-proposal embedded into chat
      final chatMessages = await (db.select(db.messages)
            ..where((t) =>
                t.senderId.equals('user-bob') &
                t.recipientId.equals('user-alice')))
          .get();
      expect(chatMessages.any((m) =>
          m.attachmentType == 'trade_proposal' &&
          m.attachmentTradeProposalId == counterProposal.id), isTrue);
    });

    test('counterTradeProposal: throws ArgumentError on non-existent proposal and StateError on non-pending proposal', () async {
      // 1. Non-existent ID
      expect(
        () => db.inboxDao.counterTradeProposal(
          'non-existent-id',
          proposerId: 'user-bob',
          receiverId: 'user-alice',
          offeredCardIds: [],
          requestedCardIds: [],
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 2. Proposal that was already cancelled
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['card-1'],
        requestedCardIds: ['card-2'],
      );
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-alice');

      expect(
        () => db.inboxDao.counterTradeProposal(
          proposal.id,
          proposerId: 'user-bob',
          receiverId: 'user-alice',
          offeredCardIds: [],
          requestedCardIds: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('counterTradeProposal: 3-way counter trade notifies third participant', () async {
      final initialProposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        thirdParticipantId: 'user-charlie',
        isThreeWay: true,
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
      );

      final counter = await db.inboxDao.counterTradeProposal(
        initialProposal.id,
        proposerId: 'user-bob',
        receiverId: 'user-alice',
        thirdParticipantId: 'user-charlie',
        isThreeWay: true,
        offeredCardIds: ['c2'],
        requestedCardIds: ['c1'],
        note: 'Updated 3-way cut',
      );

      expect(counter.isThreeWay, isTrue);
      expect(counter.thirdParticipantId, equals('user-charlie'));

      // Both Alice and Charlie must receive notifications
      final aliceNotif = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(counter.id) & t.userId.equals('user-alice')))
          .getSingleOrNull();
      final charlieNotif = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(counter.id) & t.userId.equals('user-charlie')))
          .getSingleOrNull();

      expect(aliceNotif, isNotNull);
      expect(charlieNotif, isNotNull);
    });
  });
}
