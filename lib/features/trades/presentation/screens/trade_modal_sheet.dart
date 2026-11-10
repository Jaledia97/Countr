import 'package:flutter/material.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';

/// Modal entry point for launching a trade proposal from anywhere in the app (e.g. user profile).
class TradeModalSheet {
  static Future<TradeProposalRecord?> show(
    BuildContext context, {
    required UserProfile currentUser,
    required UserProfile partnerProfile,
    UserProfile? thirdPartner,
    VaultItem? initialPartnerCard,
  }) {
    final params = TradeProposalParams(
      currentUser: currentUser,
      partnerProfile: partnerProfile,
      initialThirdPartner: thirdPartner,
      initialPartnerCard: initialPartnerCard,
    );

    return showModalBottomSheet<TradeProposalRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TradeScreen(params: params),
        );
      },
    );
  }
}
