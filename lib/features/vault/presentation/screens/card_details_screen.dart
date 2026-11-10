import 'package:flutter/material.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

export 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

/// Standalone screen wrapper for CardDetailSheet.
class CardDetailsScreen extends StatelessWidget {
  final VaultItem? item;
  final String? cardId;
  final List<VaultItem>? items;
  final int initialIndex;

  const CardDetailsScreen({
    super.key,
    this.item,
    this.cardId,
    this.items,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CardDetailSheet(
        item: item,
        cardId: cardId,
        items: items,
        initialIndex: initialIndex,
      ),
    );
  }
}
