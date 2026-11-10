import 'package:drift/drift.dart';

@DataClassName('TradeProposalRecord')
class TradeProposals extends Table {
  TextColumn get id => text()();
  TextColumn get proposerId => text().named('proposer_id')();
  TextColumn get receiverId => text().named('receiver_id')();
  TextColumn get thirdParticipantId => text().named('third_participant_id').nullable()();
  BoolColumn get isThreeWay => boolean().named('is_three_way').withDefault(const Constant(false))();
  TextColumn get cardTransfersJson => text().named('card_transfers_json').nullable()();
  TextColumn get fairnessSummaryJson => text().named('fairness_summary_json').nullable()();
  TextColumn get offeredCardIdsJson => text().named('offered_card_ids_json')();
  TextColumn get requestedCardIdsJson => text().named('requested_card_ids_json')();
  TextColumn get offeredCardsSnapshotJson => text().named('offered_cards_snapshot_json').nullable()();
  TextColumn get requestedCardsSnapshotJson => text().named('requested_cards_snapshot_json').nullable()();
  RealColumn get proposerCashDelta => real().named('proposer_cash_delta').withDefault(const Constant(0.0))();
  RealColumn get offeredTotalValue => real().named('offered_total_value').withDefault(const Constant(0.0))();
  RealColumn get requestedTotalValue => real().named('requested_total_value').withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'accepted', 'declined', 'countered', 'cancelled'
  TextColumn get note => text().nullable()();
  BoolColumn get isTransferred => boolean().named('is_transferred').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
