import 'package:drift/drift.dart';
import 'package:countr/core/database/connection/connection.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

part 'app_database.g.dart';

/// Root Drift SQLite Database for Countr.
/// Handles offline persistence, schema migrations, and initial mock seeding.
@DriftDatabase(tables: [VaultItems], daos: [VaultDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        try {
          // Automatically seed database on first open if empty
          await vaultDao.seedDatabase();
        } catch (_) {
          // Fallback gracefully; seeding can also be triggered manually
        }
      },
    );
  }
}
