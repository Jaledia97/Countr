import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_transfer.dart';

/// Helper to create a mock UserProfile for trade tests.
UserProfile createTestUser({
  required String id,
  required String username,
  required String displayName,
  String? avatarUrl,
  String collectionVisibility = 'public',
}) {
  return UserProfile(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 5,
    repCount: 10,
    tier: 'free',
    syncStatus: 'synced',
    collectionVisibility: collectionVisibility,
    isDeleted: false,
    createdAt: DateTime.now(),
  );
}

/// Helper to create a mock VaultItem for trade tests.
VaultItem createTestCard({
  required String id,
  required String name,
  String setOrSeries = 'MH3',
  String imageUrl = 'https://example.com/card.png',
  double currentMarketPrice = 10.0,
  String condition = 'NM',
  String dynamicData = '{}',
  String? userId,
}) {
  return VaultItem(
    id: id,
    collectionType: 'binder',
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: currentMarketPrice,
    acquiredDate: DateTime.now(),
    quantity: 1,
    condition: condition,
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime.now(),
    dynamicData: dynamicData,
    userId: userId,
    isDeleted: false,
  );
}

/// Helper to create a TradeCardTransfer.
TradeCardTransfer createTestTransfer({
  required VaultItem card,
  required String senderId,
  required String recipientId,
  double? marketPrice,
  String finish = 'non_foil',
}) {
  return TradeCardTransfer(
    cardId: card.id,
    cardName: card.name,
    setName: card.setOrSeries,
    imageUrl: card.imageUrl,
    marketPrice: marketPrice ?? card.currentMarketPrice,
    finish: finish,
    senderId: senderId,
    recipientId: recipientId,
  );
}
