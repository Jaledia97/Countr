import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens an offline-first SQLite database across all platforms (iOS, Android, macOS, Web).
/// In automated test environments (FLUTTER_TEST), falls back to in-memory database.
QueryExecutor openConnection({String dbName = 'countr_vault'}) {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    return NativeDatabase.memory();
  }
  if (kIsWeb) {
    return driftDatabase(name: dbName);
  }

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final fileName = dbName.endsWith('.sqlite') ? dbName : '$dbName.sqlite';
    final file = File(p.join(dbFolder.path, fileName));

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final cacheFolder = await getTemporaryDirectory();
    if (!cacheFolder.existsSync()) {
      cacheFolder.createSync(recursive: true);
    }
    final cachePath = cacheFolder.path;

    // Safely configure sqlite3.tempDirectory on the primary isolate
    try {
      sqlite3.tempDirectory = cachePath;
    } catch (_) {}

    return NativeDatabase.createBackgroundConnection(
      file,
      setup: (rawDb) {
        // Safely configure sqlite3.tempDirectory in the background isolate to prevent
        // SQLite /tmp EACCES permission failures and deadlocks on Android sandboxes.
        try {
          sqlite3.tempDirectory = cachePath;
        } catch (_) {}
        try {
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
        } catch (_) {}
      },
    );
  });
}

