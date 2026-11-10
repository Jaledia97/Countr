import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/daos/inbox_dao.dart';
import '../providers/friends_providers.dart';

class InboxUserPickerModal extends ConsumerStatefulWidget {
  const InboxUserPickerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InboxUserPickerModal(),
    );
  }

  @override
  ConsumerState<InboxUserPickerModal> createState() =>
      _InboxUserPickerModalState();
}

class _InboxUserPickerModalState extends ConsumerState<InboxUserPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
      }
    });
  }

  void _toggleUser(UserProfile profile, String currentUserId) {
    if (profile.id == currentUserId) return;

    setState(() {
      if (_selectedUserIds.contains(profile.id)) {
        _selectedUserIds.remove(profile.id);
      } else {
        if (_selectedUserIds.length >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 2 partners allowed for 3-way conversation'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _selectedUserIds.add(profile.id);
      }
    });
  }

  void _startConversation(String currentUserId) {
    if (_selectedUserIds.isEmpty) return;

    final selectedList = _selectedUserIds.toList();
    final String convId;
    final String primaryContactId = selectedList.first;

    if (selectedList.length == 1) {
      convId = InboxDao.getConversationId(currentUserId, primaryContactId);
    } else {
      final allParticipants = [currentUserId, ...selectedList]..sort();
      convId = allParticipants.join('_');
    }

    Navigator.of(context).pop();
    context.push('/inbox/chat/$convId?contactId=$primaryContactId');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final friendsDao = ref.watch(friendsDaoProvider);

    return KeyedSubtree(
      key: const Key('inbox_user_picker_modal'),
      child: Container(
        key: const Key('inbox_user_picker'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(1.0);
                  final shouldWrap = constraints.maxWidth <
                      (300 * textScale).clamp(300.0, 600.0);

                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'New Message',
                        style: AppTypography.heading2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _selectedUserIds.isEmpty
                            ? 'Select 1 or 2 partners'
                            : '${_selectedUserIds.length}/2 partners selected',
                        style: AppTypography.caption.copyWith(
                          color: _selectedUserIds.length == 2
                              ? AppColors.accentCyan
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );

                  final startButton = ElevatedButton(
                    key: const Key('inbox_user_picker_start_button'),
                    onPressed: _selectedUserIds.isNotEmpty
                        ? () => _startConversation(currentUserId)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.surfaceBorder,
                      disabledForegroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _selectedUserIds.isEmpty
                          ? 'Start Chat'
                          : (_selectedUserIds.length == 1
                              ? 'Start Chat (1)'
                              : 'Start Chat (2)'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );

                  if (shouldWrap) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleCol,
                        const SizedBox(height: 8),
                        startButton,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleCol),
                      const SizedBox(width: 8),
                      startButton,
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('inbox_user_picker_search_input'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: AppTypography.bodySecondary.copyWith(
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: friendsDao.watchFriends(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  );
                }

                final friends = snapshot.data ?? [];
                final eligibleFriends = friends
                    .where((f) => f.id != currentUserId)
                    .toList();

                if (eligibleFriends.isEmpty && _searchQuery.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 48,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Invite friends to start a chat',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                final filteredFriends = _searchQuery.isEmpty
                    ? eligibleFriends
                    : eligibleFriends.where((f) {
                        final clean = _searchQuery.toLowerCase().replaceAll('@', '');
                        return f.displayName.toLowerCase().contains(clean) ||
                            f.username.toLowerCase().contains(clean);
                      }).toList();

                if (filteredFriends.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching friends found',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredFriends.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.surfaceBorder),
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final isSelected = _selectedUserIds.contains(friend.id);

                    return ListTile(
                      key: Key('inbox_user_picker_item_${friend.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
                        child: Text(
                          friend.displayName.isNotEmpty
                              ? friend.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        friend.displayName,
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                      ),
                      subtitle: Text(
                        friend.username,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: Checkbox(
                        key: Key('inbox_user_picker_checkbox_${friend.id}'),
                        value: isSelected,
                        activeColor: AppColors.accentCyan,
                        checkColor: AppColors.background,
                        onChanged: (_) => _toggleUser(friend, currentUserId),
                      ),
                      onTap: () => _toggleUser(friend, currentUserId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
