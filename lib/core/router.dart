import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/pack_store_screen.dart';
import '../screens/pack_opening_screen.dart';
import '../screens/collection_screen.dart';
import '../screens/squad_builder_screen.dart';
import '../screens/match_screen.dart';
import '../screens/live_match_screen.dart';
import '../screens/market_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/tournament_screen.dart';
import '../screens/card_detail_screen.dart';
import '../screens/shell_screen.dart';
import 'constants.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppConstants.dashboardRoute,
    redirect: (context, state) {
      final isLoginPage = state.matchedLocation == AppConstants.loginRoute;
      if (!isAuth && !isLoginPage) return AppConstants.loginRoute;
      if (isAuth && isLoginPage) return AppConstants.dashboardRoute;
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppConstants.dashboardRoute,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppConstants.packsRoute,
            builder: (context, state) => const PackStoreScreen(),
          ),
          GoRoute(
            path: AppConstants.packOpeningRoute,
            builder: (context, state) {
              final packTypeId = state.uri.queryParameters['packTypeId'];
              return PackOpeningScreen(packTypeId: packTypeId ?? '');
            },
          ),
          GoRoute(
            path: AppConstants.collectionRoute,
            builder: (context, state) => const CollectionScreen(),
          ),
          GoRoute(
            path: AppConstants.squadBuilderRoute,
            builder: (context, state) => const SquadBuilderScreen(),
          ),
          GoRoute(
            path: AppConstants.matchRoute,
            builder: (context, state) => const MatchScreen(),
          ),
          GoRoute(
            path: AppConstants.liveMatchRoute,
            builder: (context, state) => const LiveMatchScreen(),
          ),
          GoRoute(
            path: AppConstants.marketRoute,
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: AppConstants.leaderboardRoute,
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: AppConstants.tournamentsRoute,
            builder: (context, state) => const TournamentScreen(),
          ),
          GoRoute(
            path: '/card/:cardId',
            builder: (context, state) {
              final cardId = state.pathParameters['cardId']!;
              return CardDetailScreen(cardId: cardId);
            },
          ),
        ],
      ),
    ],
  );
});
