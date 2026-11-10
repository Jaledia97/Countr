// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_reputation_dao.dart';

// ignore_for_file: type=lint
mixin _$CardReputationDaoMixin on DatabaseAccessor<AppDatabase> {
  $CardReputationVotesTable get cardReputationVotes =>
      attachedDatabase.cardReputationVotes;
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  CardReputationDaoManager get managers => CardReputationDaoManager(this);
}

class CardReputationDaoManager {
  final _$CardReputationDaoMixin _db;
  CardReputationDaoManager(this._db);
  $$CardReputationVotesTableTableManager get cardReputationVotes =>
      $$CardReputationVotesTableTableManager(
        _db.attachedDatabase,
        _db.cardReputationVotes,
      );
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
}
