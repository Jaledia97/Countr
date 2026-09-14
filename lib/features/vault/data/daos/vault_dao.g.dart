// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_dao.dart';

// ignore_for_file: type=lint
mixin _$VaultDaoMixin on DatabaseAccessor<AppDatabase> {
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  VaultDaoManager get managers => VaultDaoManager(this);
}

class VaultDaoManager {
  final _$VaultDaoMixin _db;
  VaultDaoManager(this._db);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
}
