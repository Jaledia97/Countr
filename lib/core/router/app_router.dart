import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/command_center/presentation/screens/dummy_menu_screen.dart';
import '../../features/decks/presentation/screens/decks_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../../features/vault/presentation/screens/vault_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Declarative GoRouter configuration utilizing StatefulShellRoute.indexedStack.
/// Maintains 4 primary branches: Feed, Vault, Decks, and dummy branch for Menu.
/// Freezes the local state of Feed, Vault, and Decks when navigating between them.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
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
  ],
);
