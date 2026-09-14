import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens an offline-first SQLite database across all platforms (iOS, Android, macOS, Web).
/// In automated test environments (FLUTTER_TEST), falls back to in-memory database.
QueryExecutor openConnection({String dbName = 'countr_vault'}) {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    return NativeDatabase.memory();
  }
  return driftDatabase(name: dbName);
}
