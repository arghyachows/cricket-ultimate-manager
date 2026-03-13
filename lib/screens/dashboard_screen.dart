import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../widgets/coin_display.dart';
import '../widgets/daily_objectives_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final matchState = ref.watch(matchProvider);

    return Scaffold(
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Not logged in'));
            }
            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context, user, ref),
                ),
                // Live match banner
                if (matchState.hasActiveMatch)
                  SliverToBoxAdapter(
                    child: _LiveMatchBanner(matchState: matchState),
                  ),
                // Quick actions
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    delegate: SliverChildListDelegate([
                      _QuickActionCard(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Open Packs',
                        color: AppTheme.cardGold,
                        onTap: () => context.go(AppConstants.packsRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.sports_cricket_rounded,
                        label: 'Play Match',
                        color: AppTheme.primaryLight,
                        onTap: () => context.go(AppConstants.matchRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.groups_rounded,
                        label: 'My Squad',
                        color: Colors.blueAccent,
                        onTap: () =>
                            context.go(AppConstants.squadBuilderRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Tournaments',
                        color: AppTheme.cardElite,
                        onTap: () =>
                            context.go(AppConstants.tournamentsRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.leaderboard_rounded,
                        label: 'Leaderboard',
                        color: Colors.orangeAccent,
                        onTap: () =>
                            context.go(AppConstants.leaderboardRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.storefront_rounded,
                        label: 'Market',
                        color: Colors.tealAccent,
                        onTap: () => context.go(AppConstants.marketRoute),
                      ),
                    ]),
                  ),
                ),
                // Daily Objectives
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DailyObjectivesCard(objectives: []),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.6),
            AppTheme.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    user.username,
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppTheme.accent),
                  ),
                ],
              ),
              // Level badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.cardGold],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LV ${user.level}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Currency row
          CoinDisplay(coins: user.coins, premiumTokens: user.premiumTokens),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _StatChip(
                label: 'Played',
                value: '${user.matchesPlayed}',
                icon: Icons.sports_cricket,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Won',
                value: '${user.matchesWon}',
                icon: Icons.emoji_events,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Win %',
                value: '${user.winRate.toStringAsFixed(0)}%',
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP progress
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (user.xp % AppConstants.xpPerLevel) /
                  AppConstants.xpPerLevel,
              backgroundColor: AppTheme.surfaceLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.xp % AppConstants.xpPerLevel} / ${AppConstants.xpPerLevel} XP to next level',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _LiveMatchBanner extends StatelessWidget {
  final MatchState matchState;

  const _LiveMatchBanner({required this.matchState});

  @override
  Widget build(BuildContext context) {
    final isLive = matchState.isSimulating;
    final isComplete = matchState.isMatchComplete;

    return GestureDetector(
      onTap: () => context.go(AppConstants.liveMatchRoute),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLive
                ? [AppTheme.primaryLight.withValues(alpha: 0.3), AppTheme.surface]
                : [AppTheme.accent.withValues(alpha: 0.2), AppTheme.surface],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? AppTheme.primaryLight.withValues(alpha: 0.5)
                : AppTheme.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive ? Colors.red : AppTheme.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isLive ? 'LIVE' : 'COMPLETED',
                        style: TextStyle(
                          color: isLive ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  matchState.matchFormat.toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Teams and scores
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchState.homeTeamName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (matchState.homeBatsFirst || matchState.currentInnings >= 2 || matchState.isMatchComplete) ...[
                        Text(
                          '${matchState.homeScore}/${matchState.homeWickets}',
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                        Text(
                          '(${matchState.homeOvers} ov)',
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ] else
                        const Text(
                          'Yet to bat',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white38),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'vs',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        matchState.awayTeamName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (!matchState.homeBatsFirst || matchState.currentInnings >= 2 || matchState.isMatchComplete)
                            ? '${matchState.awayScore}/${matchState.awayWickets}'
                            : 'Yet to bat',
                        style: TextStyle(
                          fontSize: (!matchState.homeBatsFirst || matchState.currentInnings >= 2 || matchState.isMatchComplete) ? 20 : 14,
                          fontWeight: FontWeight.bold,
                          color: (!matchState.homeBatsFirst || matchState.currentInnings >= 2 || matchState.isMatchComplete)
                              ? Colors.white : Colors.white38,
                        ),
                      ),
                      if (!matchState.homeBatsFirst || matchState.currentInnings >= 2 || matchState.isMatchComplete)
                        Text(
                          '(${matchState.awayOvers} ov)',
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom status
            if (matchState.currentCommentary != null) ...[
              const SizedBox(height: 8),
              Text(
                matchState.currentCommentary!,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Chase info during 2nd innings
            if (isLive && matchState.currentInnings >= 2 && matchState.runsNeeded > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${matchState.runsNeeded} needed from ${matchState.ballsRemaining} balls',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            // Rewards for completed match
            if (isComplete && matchState.coinsAwarded > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    matchState.homeWon == true
                        ? Icons.emoji_events
                        : matchState.homeWon == false
                            ? Icons.sentiment_dissatisfied
                            : Icons.handshake,
                    size: 16,
                    color: matchState.homeWon == true
                        ? AppTheme.accent : Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    matchState.homeWon == true
                        ? 'Victory!'
                        : matchState.homeWon == false
                            ? 'Defeat'
                            : 'Draw',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: matchState.homeWon == true
                          ? AppTheme.accent : Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.monetization_on, size: 14, color: AppTheme.cardGold),
                  const SizedBox(width: 4),
                  Text(
                    '+${matchState.coinsAwarded}',
                    style: const TextStyle(
                      color: AppTheme.cardGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 4),
                  Text(
                    '+${matchState.xpAwarded} XP',
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
