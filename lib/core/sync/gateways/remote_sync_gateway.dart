import '../models/sync_status.dart';

class RemoteSyncDocument {
  final String id;
  final String entityType;
  final Map<String, dynamic> data;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  const RemoteSyncDocument({
    required this.id,
    required this.entityType,
    required this.data,
    required this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
  });
}

abstract class RemoteSyncGateway {
  /// Pushes a mutation to Firestore.
  /// For tombstones (isDeleted == true), writes soft-delete payload.
  Future<void> pushMutation({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  });

  /// Pulls remote documents updated since [since].
  Future<List<RemoteSyncDocument>> pullDeltas({
    required String entityType,
    required DateTime since,
  });
}
