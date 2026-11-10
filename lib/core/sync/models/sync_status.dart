enum SyncStatus {
  synced('synced'),
  pendingCreate('pending_create'),
  pendingUpdate('pending_update'),
  pendingDelete('pending_delete');

  final String wireName;
  const SyncStatus(this.wireName);

  static SyncStatus fromWire(String? name) {
    switch (name) {
      case 'pending_create':
        return SyncStatus.pendingCreate;
      case 'pending_update':
        return SyncStatus.pendingUpdate;
      case 'pending_delete':
        return SyncStatus.pendingDelete;
      case 'synced':
      default:
        return SyncStatus.synced;
    }
  }
}

enum SyncOperation {
  insert('INSERT'),
  update('UPDATE'),
  delete('DELETE');

  final String wireName;
  const SyncOperation(this.wireName);

  static SyncOperation fromWire(String name) {
    switch (name.toUpperCase()) {
      case 'INSERT':
      case 'CREATE':
        return SyncOperation.insert;
      case 'DELETE':
        return SyncOperation.delete;
      case 'UPDATE':
      default:
        return SyncOperation.update;
    }
  }
}
