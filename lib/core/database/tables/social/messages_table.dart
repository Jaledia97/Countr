import 'package:drift/drift.dart';

@DataClassName('MessageRecord')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get senderId => text().named('sender_id')();
  TextColumn get recipientId => text().named('recipient_id')();
  TextColumn get messageText => text().named('message_text')();
  TextColumn get attachmentType => text().named('attachment_type').withDefault(const Constant('none'))(); // 'none', 'card', 'trade_proposal'
  TextColumn get attachmentCardId => text().named('attachment_card_id').nullable()();
  TextColumn get attachmentCardJson => text().named('attachment_card_json').nullable()();
  TextColumn get attachmentTradeProposalId => text().named('attachment_trade_proposal_id').nullable()();
  BoolColumn get isRead => boolean().named('is_read').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
