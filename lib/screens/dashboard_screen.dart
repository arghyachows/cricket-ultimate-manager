import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/coin_display.dart';
import '../widgets/daily_objectives_card.dart';
import '../widgets/glass_container.dart';

/// Tracks the match ID the user dismissed from the dashboard banner.
/// Persists across widget rebuilds within the same app session.
final _dismissedMatchIdProvider = StateProvider<String?>((ref) => null);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final matchState = ref.watch(matchProvider);
    final teamAsync = ref.watch(teamProvider);
    final chemistry = ref.watch(chemistryProvider);

    return Scaffold(
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Not logged in'));
            }
            final team = teamAsync.valueOrNull;
            final squad = team?.activeSquad;
            final xiCount = squad?.playingXI.length ?? 0;
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(currentUserProvider.notifier).silentRefresh();
              },
              child: CustomScrollView(
              slivers: [
                // Hero Header
                SliverToBoxAdapter(
                  child: _buildHeroHeader(context, user, team, squad, chemistry, xiCount, ref),
                ),
                // Live match banner (quick match)
                if (matchState.hasActiveMatch)
                  SliverToBoxAdapter(
                    child: _LiveMatchBanner(matchState: matchState),
                  ),
                // Live multiplayer match banner
                SliverToBoxAdapter(
                  child: _MultiplayerMatchBanner(),
                ),
                // Squad Overview Card
                if (team != null)
                  SliverToBoxAdapter(
                    child: _SquadOverviewCard(team: team, squad: squad, chemistry: chemistry),
                  ),
                // Quick actions header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 4, height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'QUICK ACTIONS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Quick actions
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                    ),
                    delegate: SliverChildListDelegate([
                      _QuickActionCard(
                        icon: Icons.sports_cricket_rounded,
                        label: 'Play Match',
                        subtitle: 'Quick or career mode',
                        gradientColors: [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
                        onTap: () => context.go(AppConstants.matchRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Open Packs',
                        subtitle: 'Collect new players',
                        gradientColors: [const Color(0xFF6D4C00), const Color(0xFFB8860B)],
                        onTap: () => context.go(AppConstants.packsRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.groups_rounded,
                        label: 'My Squad',
                        subtitle: '$xiCount/11 in Playing XI',
                        gradientColors: [const Color(0xFF1A237E), const Color(0xFF3949AB)],
                        onTap: () =>
                            context.go(AppConstants.squadBuilderRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.storefront_rounded,
                        label: 'Market',
                        subtitle: 'Trade player cards',
                        gradientColors: [const Color(0xFF004D40), const Color(0xFF00897B)],
                        onTap: () => context.go(AppConstants.marketRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Tournaments',
                        subtitle: 'Compete for glory',
                        gradientColors: [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
                        onTap: () =>
                            context.go(AppConstants.tournamentsRoute),
                      ),
                      _QuickActionCard(
                        icon: Icons.leaderboard_rounded,
                        label: 'Leaderboard',
                        subtitle: 'Global rankings',
                        gradientColors: [const Color(0xFF7F2B00), const Color(0xFFBF6B00)],
                        onTap: () =>
                            context.go(AppConstants.leaderboardRoute),
                      ),
                    ]),
                  ),
                ),
                // Daily Objectives
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: DailyObjectivesCard(objectives: []),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, user, team, squad, int chemistry, int xiCount, WidgetRef ref) {
    final xpCurrent = user.xp % AppConstants.xpPerLevel;
    final xpMax = AppConstants.xpPerLevel;
    final xpProgress = xpCurrent / xpMax;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.4),
            AppTheme.primary.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: greeting + profile + level
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      user.username,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: Colors.white, fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (team != null)
                      Text(
                        team.teamName,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accent.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Profile button
              GestureDetector(
                onTap: () => context.go(AppConstants.profileRoute),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.cardGold],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'LV${user.level}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // XP bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: xpProgress.clamp(0.0, 1.0),
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.accent, AppTheme.cardGold],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$xpCurrent / $xpMax XP',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Currency + Season Tier row
          Row(
            children: [
              CoinDisplay(coins: user.coins, premiumTokens: user.premiumTokens),
              const Spacer(),
              _SeasonBadge(tier: user.seasonTier, points: user.seasonPoints),
            ],
          ),
          const SizedBox(height: 8),
          // Stats row
          Row(
            children: [
              _StatChip(
                label: 'Played',
                value: '${user.matchesPlayed}',
                icon: Icons.sports_cricket,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Won',
                value: '${user.matchesWon}',
                icon: Icons.emoji_events,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Win %',
                value: '${user.winRate.toStringAsFixed(0)}%',
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
      ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ─── Season Badge ────────────────────────────────────────────────────

class _SeasonBadge extends StatelessWidget {
  final String tier;
  final int points;

  const _SeasonBadge({required this.tier, required this.points});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (tier) {
      'legend' => (AppTheme.cardLegend, Icons.whatshot),
      'elite' => (AppTheme.cardElite, Icons.diamond),
      'gold' => (AppTheme.cardGold, Icons.star),
      'silver' => (AppTheme.cardSilver, Icons.shield),
      _ => (AppTheme.cardBronze, Icons.shield_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${tier[0].toUpperCase()}${tier.substring(1)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Squad Overview Card ─────────────────────────────────────────────

class _SquadOverviewCard extends StatelessWidget {
  final Team team;
  final Squad? squad;
  final int chemistry;

  const _SquadOverviewCard({required this.team, this.squad, required this.chemistry});

  @override
  Widget build(BuildContext context) {
    final xiCount = squad?.playingXI.length ?? 0;
    final captain = squad?.captain;
    final captainName = captain?.userCard?.playerCard?.playerName;
    final rating = team.overallRating;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                team.teamName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.accent,
                ),
              ),
              const Spacer(),
              if (captainName != null)
                Text(
                  'C: $captainName',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SquadMiniStat(
                label: 'RATING',
                value: '$rating',
                color: _ratingColor(rating),
              ),
              const SizedBox(width: 16),
              _SquadMiniStat(
                label: 'CHEMISTRY',
                value: '$chemistry',
                color: chemistry >= 50 ? AppTheme.primaryLight : Colors.orangeAccent,
              ),
              const SizedBox(width: 16),
              _SquadMiniStat(
                label: 'PLAYING XI',
                value: '$xiCount/11',
                color: xiCount >= 11 ? AppTheme.primaryLight : AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _ratingColor(int rating) {
    if (rating >= 80) return AppTheme.cardLegend;
    if (rating >= 60) return AppTheme.cardGold;
    if (rating >= 40) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }
}

class _SquadMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SquadMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Card ───────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withValues(alpha: 0.3),
                    gradientColors[1].withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        tint: isLive ? AppTheme.primaryLight : AppTheme.accent,
        opacity: 0.12,
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

// ─── Multiplayer Live Match Banner ──────────────────────────────────

class _MultiplayerMatchBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MultiplayerMatchBanner> createState() => _MultiplayerMatchBannerState();
}

class _MultiplayerMatchBannerState extends ConsumerState<_MultiplayerMatchBanner> {
  Map<String, dynamic>? _matchData;
  String? _subscribedMatchId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(activeMultiplayerMatchProvider));
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime(String matchId) {
    if (_subscribedMatchId == matchId) return;
    _unsubscribe();
    _subscribedMatchId = matchId;

    final channel = SupabaseService.client.channel('dashboard_mp_$matchId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'multiplayer_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: matchId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final data = payload.newRecord;
            setState(() => _matchData = data);
            if (data['status'] == 'completed') {
              ref.invalidate(activeMultiplayerMatchProvider);
              _unsubscribe();
            }
          },
        )
        .subscribe();
  }

  void _unsubscribe() {
    if (_subscribedMatchId != null) {
      SupabaseService.client.channel('dashboard_mp_$_subscribedMatchId').unsubscribe();
      _subscribedMatchId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMatch = ref.watch(activeMultiplayerMatchProvider);
    final dismissedId = ref.watch(_dismissedMatchIdProvider);

    return activeMatch.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (providerMatch) {
        if (providerMatch == null && _matchData == null) {
          _unsubscribe();
          return const SizedBox.shrink();
        }

        // Use realtime data if available, fall back to provider data
        final match = _matchData ?? providerMatch!;
        final matchId = match['id'] as String;

        // Skip if user dismissed this specific completed match
        final status = match['status'] as String? ?? '';
        if (status == 'completed' && matchId == dismissedId) {
          return const SizedBox.shrink();
        }

        // Reset dismissed ID if a new active match appeared
        if (status != 'completed' && dismissedId != null) {
          Future.microtask(() => ref.read(_dismissedMatchIdProvider.notifier).state = null);
        }

        // Start realtime subscription for this match
        if (!status.contains('completed')) {
          _subscribeRealtime(matchId);
        }

        final isLive = status == 'in_progress';
        final isCompleted = status == 'completed';
        final homeTeam = match['home_team_name'] ?? 'Home';
        final awayTeam = match['away_team_name'] ?? 'Away';
        final hScore = match['home_score'] ?? 0;
        final hWickets = match['home_wickets'] ?? 0;
        final aScore = match['away_score'] ?? 0;
        final aWickets = match['away_wickets'] ?? 0;
        final hOvers = match['home_overs_display'] ?? '0.0';
        final aOvers = match['away_overs_display'] ?? '0.0';
        final commentary = match['current_commentary'] as String? ?? '';
        final matchResult = match['match_result'] as String? ?? '';
        final winnerId = match['winner_user_id'];
        final userId = SupabaseService.currentUserId;
        final userWon = winnerId != null && winnerId == userId;
        final isDraw = isCompleted && winnerId == null;
        final target = match['target'] as int? ?? 0;
        final currentInnings = match['current_innings'] as int? ?? 1;
        final matchOvers = match['match_overs'] as int? ?? 20;
        final homeBatsFirst = match['home_bats_first'] as bool? ?? true;

        // Chase info for 2nd innings
        String? chaseInfo;
        if (isLive && currentInnings >= 2 && target > 0) {
          final chasingScore = homeBatsFirst ? aScore : hScore;
          final chasingOvers = homeBatsFirst ? aOvers : hOvers;
          final chasingTeam = homeBatsFirst ? awayTeam : homeTeam;
          final runsNeeded = target + 1 - (chasingScore as int);
          if (runsNeeded > 0) {
            final parts = chasingOvers.toString().split('.');
            final fullOvers = int.tryParse(parts[0]) ?? 0;
            final extraBalls = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
            final ballsBowled = fullOvers * 6 + extraBalls;
            final ballsRemaining = (matchOvers * 6) - ballsBowled;
            chaseInfo = '$chasingTeam need $runsNeeded from $ballsRemaining balls';
          }
        }

        // Badge color/text
        final Color badgeColor;
        final String badgeText;
        if (isCompleted) {
          badgeColor = userWon ? Colors.green : (isDraw ? Colors.orange : Colors.red);
          badgeText = userWon ? 'WON' : (isDraw ? 'DRAW' : 'LOST');
        } else if (isLive) {
          badgeColor = Colors.deepPurple;
          badgeText = 'LIVE';
        } else {
          badgeColor = AppTheme.primary;
          badgeText = 'WAITING';
        }

        return GestureDetector(
          onTap: () => context.push('/multiplayer/match/$matchId'),
          child: GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            tint: isCompleted
                ? (userWon ? Colors.green : Colors.red)
                : isLive
                    ? Colors.deepPurple
                    : AppTheme.primary,
            opacity: 0.12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
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
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MULTIPLAYER',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const Spacer(),
                    if (isCompleted)
                      GestureDetector(
                        onTap: () {
                          ref.read(_dismissedMatchIdProvider.notifier).state = matchId;
                          setState(() => _matchData = null);
                        },
                        child: const Icon(Icons.close, size: 18, color: Colors.white38),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                  ],
                ),
                const SizedBox(height: 12),

                // Teams & Scores
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(homeTeam,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          if (isLive || isCompleted) ...[
                            Text('$hScore/$hWickets',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                            Text('($hOvers ov)',
                                style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          ] else
                            const Text('--', style: TextStyle(fontSize: 18, color: Colors.white38)),
                        ],
                      ),
                    ),
                    const Text('vs', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(awayTeam,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                          const SizedBox(height: 2),
                          if (isLive || isCompleted) ...[
                            Text('$aScore/$aWickets',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('($aOvers ov)',
                                style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          ] else
                            const Text('--', style: TextStyle(fontSize: 18, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ],
                ),

                // Chase info
                if (chaseInfo != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(chaseInfo,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                  ),
                ],

                // Result / Commentary
                if (isCompleted && matchResult.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(matchResult,
                      style: TextStyle(
                        color: userWon ? Colors.green.shade300 : Colors.orange.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ] else if (commentary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(commentary,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
