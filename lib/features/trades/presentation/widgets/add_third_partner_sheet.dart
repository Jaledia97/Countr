import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Modal bottom sheet allowing selection of a 3rd trade partner.
class AddThirdPartnerSheet extends ConsumerStatefulWidget {
  final List<String> existingParticipantIds;
  final ValueChanged<UserProfile> onPartnerSelected;

  const AddThirdPartnerSheet({
    super.key,
    required this.existingParticipantIds,
    required this.onPartnerSelected,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    required List<String> existingParticipantIds,
  }) {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddThirdPartnerSheet(
        existingParticipantIds: existingParticipantIds,
        onPartnerSelected: (user) => Navigator.of(ctx).pop(user),
      ),
    );
  }

  @override
  ConsumerState<AddThirdPartnerSheet> createState() =>
      _AddThirdPartnerSheetState();
}

class _AddThirdPartnerSheetState extends ConsumerState<AddThirdPartnerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Container(
      key: const Key('add_third_partner_sheet'),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.accentCyan,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add 3rd Trade Partner',
                  style: AppTypography.heading2.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search friends or collectors...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: AppColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
          ),

          // User Profiles List
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: (db.select(db.userProfiles)
                    ..where((t) => t.isDeleted.equals(false)))
                  .watch(),
              builder: (context, snapshot) {
                final profiles = snapshot.data ?? [];
                final eligible = profiles.where((p) {
                  if (widget.existingParticipantIds.contains(p.id)) return false;
                  if (_query.isEmpty) return true;
                  return p.displayName.toLowerCase().contains(_query) ||
                      p.username.toLowerCase().contains(_query);
                }).toList();

                if (eligible.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching trade partners found',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: eligible.length,
                  itemBuilder: (context, index) {
                    final profile = eligible[index];
                    return ListTile(
                      key: Key('partner_option_${profile.id}'),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceBorder,
                        backgroundImage: profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null ||
                                profile.avatarUrl!.isEmpty
                            ? Text(
                                profile.displayName.isNotEmpty
                                    ? profile.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        profile.displayName,
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                      ),
                      subtitle: Text(
                        profile.username,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.accentCyan,
                        size: 22,
                      ),
                      onTap: () => widget.onPartnerSelected(profile),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
