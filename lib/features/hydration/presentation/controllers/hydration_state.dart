/// State lifecycle enumeration for MTG bulk ledger hydration.
enum HydrationStatus {
  idle,
  fetchingMetadata,
  downloading,
  parsingAndInserting,
  complete,
  error,
}

/// Immutable state representation for the Hydration Engine.
class HydrationState {
  final HydrationStatus status;
  final String statusMessage;
  final double? progress;
  final int bytesDownloaded;
  final int? totalBytes;
  final int insertedCount;
  final int estimatedTotalCards;
  final String? errorMessage;

  const HydrationState({
    this.status = HydrationStatus.idle,
    this.statusMessage = 'Idle',
    this.progress,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.insertedCount = 0,
    this.estimatedTotalCards = 80000,
    this.errorMessage,
  });

  bool get isLoading =>
      status == HydrationStatus.fetchingMetadata ||
      status == HydrationStatus.downloading ||
      status == HydrationStatus.parsingAndInserting;

  bool get isComplete => status == HydrationStatus.complete;
  bool get isError => status == HydrationStatus.error;

  String get downloadProgressText {
    final mbDown = (bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes != null && totalBytes! > 0) {
      final mbTotal = (totalBytes! / (1024 * 1024)).toStringAsFixed(1);
      return '$mbDown MB / $mbTotal MB';
    }
    return '$mbDown MB downloaded';
  }

  HydrationState copyWith({
    HydrationStatus? status,
    String? statusMessage,
    double? progress,
    bool clearProgress = false,
    int? bytesDownloaded,
    int? totalBytes,
    int? insertedCount,
    int? estimatedTotalCards,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HydrationState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      progress: clearProgress ? null : (progress ?? this.progress),
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      insertedCount: insertedCount ?? this.insertedCount,
      estimatedTotalCards: estimatedTotalCards ?? this.estimatedTotalCards,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
