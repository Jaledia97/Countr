import 'package:drift/drift.dart';

/// The VaultBinders Schema
/// Represents customized card binders / portfolio albums for individual collections.
class VaultBinders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get collectionType => text().named('collection_type')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
