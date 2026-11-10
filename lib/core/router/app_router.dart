import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/command_center/presentation/screens/dummy_menu_screen.dart';
import '../../features/decks/presentation/screens/decks_screen.dart';
import '../../features/decks/presentation/screens/read_only_deck_screen.dart';
import '../../features/feed/presentation/screens/chat_conversation_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/friends_hub_screen.dart';
import '../../features/feed/presentation/screens/inbox_hub_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../../features/vault/presentation/screens/vault_screen.dart';
import '../../features/auth/presentation/screens/onboarding_welcome_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Declarative GoRouter configuration utilizing StatefulShellRoute.indexedStack.
/// Maintains 4 primary branches: Feed, Vault, Decks, and dummy branch for Menu.
/// Freezes the local state of Feed, Vault, and Decks when navigating between them.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/feed',
  debugLogDiagnostics: false,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Feed
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/feed',
              name: 'feed',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: FeedScreen(),
              ),
            ),
          ],
        ),

        // Branch 1: Vault
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              name: 'vault',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: VaultScreen(),
              ),
            ),
          ],
        ),

        // Branch 2: Decks
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/decks',
              name: 'decks',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DecksScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'explore/:id',
                  name: 'exploreDeckDetail',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return MaterialPage(
                      child: ReadOnlyDeckScreen(exploreDeckId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // Branch 3: Dummy branch for the Menu
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/menu',
              name: 'menu',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DummyMenuScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/explore/deck/:id',
      name: 'exploreDeckDetailDirect',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ReadOnlyDeckScreen(exploreDeckId: id);
      },
    ),
    GoRoute(
      path: '/profile/me',
      name: 'currentUserProfile',
      builder: (context, state) {
        return const UserProfileScreen(profileId: 'me');
      },
    ),
    GoRoute(
      path: '/profile/:id',
      name: 'userProfile',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'me';
        return UserProfileScreen(profileId: id);
      },
    ),
    GoRoute(
      path: '/inbox',
      name: 'inboxHub',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final indexParam = state.uri.queryParameters['initialIndex'] ?? state.uri.queryParameters['index'];
        final initialIndex = indexParam != null
            ? int.tryParse(indexParam)
            : (tab == 'messages' ? 1 : (tab == 'notifications' ? 0 : null));
        return InboxHubScreen(
          initialTab: tab,
          initialIndex: initialIndex,
        );
      },
    ),
    GoRoute(
      path: '/post/:id',
      name: 'postDetail',
      builder: (context, state) {
        final postId = state.pathParameters['id'] ?? '';
        final openComments = state.uri.queryParameters['comments'] == 'true';
        return PostDetailScreen(
          postId: postId,
          openComments: openComments,
        );
      },
    ),
    GoRoute(
      path: '/inbox/chat/:conversationId',
      name: 'chatConversation',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        final contactId = state.uri.queryParameters['contactId'];
        return ChatConversationScreen(
          conversationId: conversationId,
          contactId: contactId,
        );
      },
    ),
    GoRoute(
      path: '/friends',
      name: 'friendsHub',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final userId = state.uri.queryParameters['userId'];
        return FriendsHubScreen(initialTab: tab, userId: userId);
      },
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) => '/feed',
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const OnboardingWelcomeScreen(),
    ),
  ],
);
