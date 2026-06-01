import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../core/node_backend_service.dart';
import '../providers/providers.dart';
import '../widgets/coin_display.dart';
import '../widgets/daily_objectives_card.dart';

/// Tracks the match ID the user dismissed from the dashboard banner.
/// Persists across widget rebuilds within the same app session.
final _dismissedMatchIdProvider = StateProvider<String?>((ref) => null);

class DailyObjectivesCardPlaceholder extends StatelessWidget {
  const DailyObjectivesCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'DAILY OBJECTIVES',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              const Text('0/0', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('No objectives today', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showDailyReward = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkDailyReward);
  }

  Future<void> _checkDailyReward() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final now = DateTime.now();
    final last = user.lastDailyReward;
    final claimed = last != null &&
        last.year == now.year && last.month == now.month && last.day == now.day;
    if (!claimed) setState(() => _showDailyReward = true);
  }

  Future<void> _claimDailyReward() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await SupabaseService.client.from('transactions').insert({
      'user_id': user.id,
      'type': 'daily_reward',
      'coins_amount': 100,
      'description': 'Daily login reward',
    });
    await SupabaseService.client.rpc('increment_user_coins', {'user_id': user.id, 'delta': 100});
    await SupabaseService.client.from('users').update({
      'last_daily_reward': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
    ref.read(currentUserProvider.notifier).silentRefresh();
    setState(() => _showDailyReward = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💰 +100 coins claimed!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final matchState = ref.watch(matchProvider);

    ref.listen<MatchState>(matchProvider, (previous, next) {
      if (next.isMatchComplete && previous?.isMatchComplete == false) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          ref.read(currentUserProvider.notifier).silentRefresh();
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) return const Center(child: Text('Not logged in'));
            return RefreshIndicator(
              onRefresh: () async => ref.read(currentUserProvider.notifier).silentRefresh(),
              child: CustomScrollView(
                slivers: [
                  // ── 1. Hero Header ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      user: user,
                      showDailyReward: _showDailyReward,
                      onClaimDailyReward: _claimDailyReward,
                    ),
                  ),
                  // ── 2. Live Match Banners ─────────────────────────
                  if (matchState.hasActiveMatch)
                    SliverToBoxAdapter(child: _LiveMatchBanner(matchState: matchState)),
                  const SliverToBoxAdapter(child: _MultiplayerMatchBanner()),
                  const SliverToBoxAdapter(child: _TournamentMatchBanner()),
                  // ── 3. Featured Card ────────────────────────────────
                  const SliverToBoxAdapter(child: _FeaturedCardSection()),
                  // ── 4. Quick Actions ─────────────────────────────────
                  SliverToBoxAdapter(child: _QuickActionsSection()),
                  // ── 5. Recent Matches ────────────────────────────────
                  const SliverToBoxAdapter(child: _RecentMatchesSection()),
                  // ── 6. Daily Objectives ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _DailyObjectivesSection(),
                    ),
                  ),
                  // ── 7. Pack Highlights ───────────────────────────────
                  const SliverToBoxAdapter(child: _PackHighlightsSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
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

// ══════════════════════════════════════════════════════════════════
//  SECTION 1: HERO HEADER
// ══════════════════════════════════════════════════════════════════

class _HeroHeader extends ConsumerWidget {
  final UserModel user;
  final bool showDailyReward;
  final VoidCallback onClaimDailyReward;

  const _HeroHeader({
    required this.user,
    required this.showDailyReward,
    required this.onClaimDailyReward,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.5),
            AppTheme.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: greeting + tier badge + profile
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
                    ),
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              _SeasonTierBadge(tier: user.seasonTier),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.go(AppConstants.profileRoute),
                icon: const Icon(Icons.person_rounded),
                color: AppTheme.accent,
                style: IconButton.styleFrom(backgroundColor: AppTheme.surface),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Currency + daily reward
          Row(
            children: [
              Expanded(child: CoinDisplay(coins: user.coins, premiumTokens: user.premiumTokens)),
              if (showDailyReward) ...[
                const SizedBox(width: 8),
                _DailyRewardButton(onTap: onClaimDailyReward),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Team info row
          teamAsync.when(
            data: (team) {
              if (team == null) {
                return GestureDetector(
                  onTap: () => context.go(AppConstants.squadBuilderRoute),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primaryLight),
                        SizedBox(width: 6),
                        Text('Create your team',
                            style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text(team.teamName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (team.overallRating > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text('OVR ${team.overallRating}',
                          style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_rounded, size: 12, color: Colors.teal.shade300),
                        const SizedBox(width: 4),
                        Text('${team.chemistry}',
                            style: TextStyle(color: Colors.teal.shade300, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // Stats chips
          Row(
            children: [
              _StatChip(label: 'Played', value: '${user.matchesPlayed}', icon: Icons.sports_cricket),
              const SizedBox(width: 8),
              _StatChip(label: 'Won', value: '${user.matchesWon}', icon: Icons.emoji_events),
              const SizedBox(width: 8),
              _StatChip(label: 'WR', value: '${user.winRate.toStringAsFixed(0)}%',
                  icon: Icons.trending_up),
              const SizedBox(width: 8),
              _StatChip(label: 'LV ${user.level}', value: '', icon: Icons.star),
            ],
          ),

          const SizedBox(height: 10),

          // XP bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (user.xp % AppConstants.xpPerLevel) / AppConstants.xpPerLevel,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.xp % AppConstants.xpPerLevel} / ${AppConstants.xpPerLevel} XP to next level',
            style: const TextStyle(fontSize: 11, color: Colors.white45),
          ),
        ],
      ),
    );
  }
}

class _SeasonTierBadge extends StatelessWidget {
  final String tier;
  const _SeasonTierBadge({required this.tier});

  Color get _c {
    switch (tier) {
      case 'champion': return Colors.amber;
      case 'elite': return AppTheme.cardElite;
      case 'gold': return AppTheme.cardGold;
      case 'silver': return AppTheme.cardSilver;
      default: return AppTheme.cardBronze;
    }
  }

  String get _label {
    switch (tier) {
      case 'champion': return '⚔️ CHAMPION';
      case 'elite': return '💎 ELITE';
      case 'gold': return '🥇 GOLD';
      case 'silver': return '🥈 SILVER';
      default: return '🥉 BRONZE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c.withValues(alpha: 0.4)),
      ),
      child: Text(_label,
          style: TextStyle(color: _c, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
    );
  }
}

class _DailyRewardButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyRewardButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 14, color: Colors.black87),
            SizedBox(width: 4),
            Text('Daily!',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SECTION 3: FEATURED CARD
// ══════════════════════════════════════════════════════════════════

class _FeaturedCardSection extends ConsumerWidget {
  const _FeaturedCardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider);

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        final featured = cards.reduce((a, b) => a.overallRating >= b.overallRating ? a : b);
        final playerCard = featured.playerCard;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.getRarityColor(playerCard.rarity).withValues(alpha: 0.15),
                  AppTheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.getRarityColor(playerCard.rarity).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.getRarityColor(playerCard.rarity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(playerCard.rarity.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    const Text('STAR PLAYER',
                        style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go(AppConstants.collectionRoute),
                      child: const Text('View all', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Card preview
                    Container(
                      width: 70, height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [
                            AppTheme.getRarityColor(playerCard.rarity).withValues(alpha: 0.6),
                            AppTheme.getRarityColor(playerCard.rarity).withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getRarityColor(playerCard.rarity).withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(playerCard.playerName.split(' ').last,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(featured.level > 1 ? '+${(featured.level - 1) * 2}' : '',
                              style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('${featured.overallRating}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playerCard.playerName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${playerCard.role.replaceAll('_', ' ').toUpperCase()} · ${playerCard.country}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _MiniStat(label: 'BAT', value: featured.batting, color: AppTheme.primaryLight),
                              const SizedBox(width: 8),
                              _MiniStat(label: 'BOW', value: featured.bowling, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              _MiniStat(label: 'FIE', value: featured.fielding, color: Colors.blueAccent),
                              if (featured.level > 1) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('LV${featured.level}',
                                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SECTION 4: QUICK ACTIONS
// ══════════════════════════════════════════════════════════════════

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚡ QUICK PLAY',
              style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          // Row 1: Play Match (large left) + Packs (small right)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _ActionTile(
                  icon: Icons.sports_cricket_rounded,
                  label: 'Play Match',
                  color: AppTheme.primaryLight,
                  gradient: [AppTheme.primary.withValues(alpha: 0.4), AppTheme.surface],
                  onTap: () => context.go(AppConstants.matchRoute),
                  height: 100,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Packs',
                  color: AppTheme.cardGold,
                  gradient: [AppTheme.cardGold.withValues(alpha: 0.25), AppTheme.surface],
                  onTap: () => context.go(AppConstants.packsRoute),
                  height: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Squad + Tournaments + Leaderboard + Market (4 equal)
          Row(
            children: [
              Expanded(child: _ActionTile(icon: Icons.groups_rounded, label: 'Squad', color: Colors.blueAccent,
                  gradient: [Colors.blueAccent.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.squadBuilderRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: _ActionTile(icon: Icons.emoji_events_rounded, label: 'Tourney', color: AppTheme.cardElite,
                  gradient: [AppTheme.cardElite.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.tournamentsRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: _ActionTile(icon: Icons.leaderboard_rounded, label: 'Ranks', color: Colors.orangeAccent,
                  gradient: [Colors.orangeAccent.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.leaderboardRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: _ActionTile(icon: Icons.storefront_rounded, label: 'Market', color: Colors.tealAccent,
                  gradient: [Colors.tealAccent.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.marketRoute), height: 82)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<Color> gradient;
  final VoidCallback onTap;
  final double height;

  const _ActionTile({
    required this.icon, required this.label, required this.color,
    required this.gradient, required this.onTap, this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ).createShader(bounds),
                child: Icon(icon, size: height * 0.38, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SECTION 5: RECENT MATCHES
// ══════════════════════════════════════════════════════════════════

class _RecentMatchesSection extends ConsumerStatefulWidget {
  const _RecentMatchesSection();

  @override
  ConsumerState<_RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends ConsumerState<_RecentMatchesSection> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final rows = await SupabaseService.client
          .from('matches')
          .select()
          .or('home_user_id.eq.$userId,away_user_id.eq.$userId')
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(3);
      if (mounted) setState(() { _matches = List<Map<String, dynamic>>.from(rows as List); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏏 RECENT MATCHES',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(AppConstants.matchHistoryRoute),
                child: const Text('See all', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_matches.take(2).map((m) => _RecentMatchTile(match: m))),
        ],
      ),
    );
  }
}

class _RecentMatchTile extends StatelessWidget {
  final Map<String, dynamic> match;
  const _RecentMatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentUserId;
    final isHome = match['home_user_id'] == userId;
    final myScore = isHome ? match['home_score'] : match['away_score'];
    final myWickets = isHome ? match['home_wickets'] : match['away_wickets'];
    final oppScore = isHome ? match['away_score'] : match['home_score'];
    final oppWickets = isHome ? match['away_wickets'] : match['home_wickets'];
    final winnerId = match['winner_user_id'];
    final won = winnerId == userId;
    final draw = winnerId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: won
              ? Colors.green.withValues(alpha: 0.3)
              : (draw ? Colors.orange.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: won ? Colors.green : (draw ? Colors.orange : Colors.red),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match['format']?.toString().toUpperCase() ?? 'T20',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(won ? 'Victory!' : (draw ? 'Draw' : 'Defeat'),
                    style: TextStyle(
                      color: won ? Colors.green : (draw ? Colors.orange : Colors.red),
                      fontWeight: FontWeight.bold, fontSize: 14,
                    )),
              ],
            ),
          ),
          Text('$myScore/$myWickets', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          const Text('vs', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Text('$oppScore/$oppWickets', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 8),
          Text('(${match['home_overs'] ?? 0} ov)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SECTION 6: DAILY OBJECTIVES (from DB)
// ══════════════════════════════════════════════════════════════════

class _DailyObjectivesSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DailyObjectivesSection> createState() => _DailyObjectivesSectionState();
}

class _DailyObjectivesSectionState extends ConsumerState<_DailyObjectivesSection> {
  List<DailyObjective> _objectives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final rows = await SupabaseService.client
          .from('daily_objectives')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .eq('status', 'active');
      if (mounted) {
        setState(() {
          _objectives = (rows as List).map((r) => DailyObjective.fromJson(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_objectives.isEmpty) return const SizedBox.shrink();
    return DailyObjectivesCard(objectives: _objectives);
  }
}

// ══════════════════════════════════════════════════════════════════
//  SECTION 7: PACK HIGHLIGHTS
// ══════════════════════════════════════════════════════════════════

class _PackHighlightsSection extends ConsumerStatefulWidget {
  const _PackHighlightsSection();

  @override
  ConsumerState<_PackHighlightsSection> createState() => _PackHighlightsSectionState();
}

class _PackHighlightsSectionState extends ConsumerState<_PackHighlightsSection> {
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  Future<void> _fetch() async {
    try {
      final rows = await SupabaseService.client
          .from('pack_types')
          .select()
          .eq('is_available', true)
          .order('coin_cost', ascending: true)
          .limit(3);
      if (mounted) {
        setState(() {
          _packs = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _packs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦 PACK STORE',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go(AppConstants.packsRoute),
                child: const Text('See all', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _packs.map((p) => _PackTile(pack: p)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final Map<String, dynamic> pack;
  const _PackTile({required this.pack});

  Color get _color {
    final name = pack['name'] as String? ?? '';
    if (name.contains('Legend')) return AppTheme.cardLegend;
    if (name.contains('Elite')) return AppTheme.cardElite;
    if (name.contains('Gold')) return AppTheme.cardGold;
    if (name.contains('Silver')) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }

  IconData get _icon {
    final name = pack['name'] as String? ?? '';
    if (name.contains('Legend')) return Icons.auto_awesome;
    if (name.contains('Elite')) return Icons.diamond;
    if (name.contains('Gold')) return Icons.military_tech;
    if (name.contains('Silver')) return Icons.workspace_premium;
    return Icons.style;
  }

  @override
  Widget build(BuildContext context) {
    final name = pack['name'] as String? ?? 'Pack';
    final coinCost = pack['coin_cost'] as int? ?? 0;
    final premiumCost = pack['premium_cost'] as int? ?? 0;
    final cardCount = pack['card_count'] as int? ?? 3;
    final color = _color;

    return GestureDetector(
      onTap: () => context.go(AppConstants.packsRoute),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), AppTheme.surface],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('x$cardCount', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                if (coinCost > 0) ...[
                  const Icon(Icons.monetization_on, size: 13, color: AppTheme.accent),
                  const SizedBox(width: 3),
                  Text(coinCost >= 1000 ? '${(coinCost / 1000).toStringAsFixed(0)}K' : '$coinCost',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                ] else if (premiumCost > 0) ...[
                  const Icon(Icons.diamond, size: 13, color: Colors.purpleAccent),
                  const SizedBox(width: 3),
                  Text('$premiumCost', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  LIVE MATCH BANNER (existing, preserved)
// ══════════════════════════════════════════════════════════════════

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
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? (userWon
                        ? [Colors.green.withValues(alpha: 0.25), AppTheme.surface]
                        : [Colors.red.withValues(alpha: 0.2), AppTheme.surface])
                    : isLive
                        ? [Colors.deepPurple.withValues(alpha: 0.3), AppTheme.surface]
                        : [AppTheme.primary.withValues(alpha: 0.2), AppTheme.surface],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted
                    ? (userWon
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.4))
                    : isLive
                        ? Colors.deepPurple.withValues(alpha: 0.5)
                        : AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
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

// ─── Tournament Match Banner ─────────────────────────────────────

class _TournamentMatchBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TournamentMatchBanner> createState() => _TournamentMatchBannerState();
}

class _TournamentMatchBannerState extends ConsumerState<_TournamentMatchBanner> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  Timer? _refreshTimer;
  bool _hasLiveMatch = false;
  String? _subscribedMatchId;
  StreamSubscription<Map<String, dynamic>>? _ballSub;
  StreamSubscription<Map<String, dynamic>>? _completeSub;
  String? _lastCommentary;

  @override
  void initState() {
    super.initState();
    _fetchActiveMatch();
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    // Poll as fallback: 5s when live (for reconnection recovery), 30s otherwise
    final interval = _hasLiveMatch ? const Duration(seconds: 5) : const Duration(seconds: 30);
    _refreshTimer = Timer.periodic(interval, (_) => _fetchActiveMatch());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _unsubscribeSocket();
    super.dispose();
  }

  void _subscribeSocket(String matchId) {
    if (_subscribedMatchId == matchId && _ballSub != null) return;
    _unsubscribeSocket();
    _subscribedMatchId = matchId;

    NodeBackendService.subscribeToMatchUpdates(matchId);
    _ballSub = NodeBackendService.ballUpdates.listen((data) {
      if (!mounted) return;
      _handleBallUpdate(data);
    });
    _completeSub = NodeBackendService.matchCompleteEvents.listen((data) {
      if (!mounted) return;
      // Match ended — refresh via HTTP to get final state
      _fetchActiveMatch();
    });
  }

  void _unsubscribeSocket() {
    _ballSub?.cancel();
    _ballSub = null;
    _completeSub?.cancel();
    _completeSub = null;
    if (_subscribedMatchId != null) {
      NodeBackendService.unsubscribeFromMatchUpdates();
      _subscribedMatchId = null;
    }
  }

  void _handleBallUpdate(Map<String, dynamic> data) {
    final state = data['state'] as Map<String, dynamic>?;
    if (state == null || _data == null) return;

    final currentMatch = _data!['currentMatch'] as Map<String, dynamic>?;
    if (currentMatch == null) return;

    final hbf = state['homeBatsFirst'] as bool? ?? true;
    final score1 = state['score1'] as int? ?? 0;
    final score2 = state['score2'] as int? ?? 0;
    final wickets1 = state['wickets1'] as int? ?? 0;
    final wickets2 = state['wickets2'] as int? ?? 0;
    final innings = state['innings'] as int? ?? 1;
    final overNumber = state['overNumber'] as int? ?? 0;
    final ballNumber = state['ballNumber'] as int? ?? 0;
    final target = state['target'] as int? ?? 0;
    final matchOvers = state['matchOvers'] as int? ?? 20;

    // Extract commentary from result
    final result = data['result'] as Map<String, dynamic>?;
    final commentary = result?['commentary'] as String? ?? '';

    final oversStr = '$overNumber.$ballNumber';

    setState(() {
      if (commentary.isNotEmpty) _lastCommentary = commentary;
      _data!['currentMatch'] = {
        ...currentMatch,
        'home_score': hbf ? score1 : score2,
        'away_score': hbf ? score2 : score1,
        'home_wickets': hbf ? wickets1 : wickets2,
        'away_wickets': hbf ? wickets2 : wickets1,
        'home_overs': innings == 1
            ? (hbf ? oversStr : currentMatch['home_overs'])
            : (!hbf ? oversStr : currentMatch['home_overs']),
        'away_overs': innings == 1
            ? (!hbf ? oversStr : currentMatch['away_overs'])
            : (hbf ? oversStr : currentMatch['away_overs']),
        'live_innings': innings,
        'target': target,
        'match_overs': matchOvers,
        'home_bats_first': hbf,
      };
    });
  }

  Future<void> _fetchActiveMatch() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final result = await NodeBackendService.getTournamentActiveMatch(userId);
    if (!mounted) return;
    final wasLive = _hasLiveMatch;
    final currentMatch = result?['currentMatch'] as Map<String, dynamic>?;
    final isLiveNow = currentMatch != null && currentMatch['status'] == 'in_progress';
    setState(() {
      _data = result;
      _loading = false;
      _hasLiveMatch = isLiveNow;
    });
    // Switch polling interval if live status changed
    if (wasLive != isLiveNow) _startPolling();

    // Subscribe/unsubscribe Socket.IO based on live status
    if (isLiveNow) {
      final matchId = currentMatch!['id'] as String;
      _subscribeSocket(matchId);
    } else {
      _unsubscribeSocket();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) return const SizedBox.shrink();

    final activeTournament = _data!['activeTournament'] as Map<String, dynamic>?;
    if (activeTournament == null) return const SizedBox.shrink();

    final currentMatch = _data!['currentMatch'] as Map<String, dynamic>?;
    final nextMatch = _data!['nextMatch'] as Map<String, dynamic>?;

    // Show banner for live match or next scheduled match
    final match = currentMatch ?? nextMatch;
    if (match == null) return const SizedBox.shrink();

    final isLive = match['status'] == 'in_progress';
    final isPending = match['status'] == 'pending';
    final matchId = match['id'] as String;
    final homeTeam = match['home_team_name'] ?? 'Home';
    final awayTeam = match['away_team_name'] ?? 'Away';
    final matchNumber = match['match_number'] ?? 0;
    final scheduledAt = match['scheduled_at'] != null ? DateTime.tryParse(match['scheduled_at']) : null;
    final tournamentName = activeTournament['name'] ?? 'Tournament';

    final hScore = match['home_score'] ?? 0;
    final hWickets = match['home_wickets'] ?? 0;
    final aScore = match['away_score'] ?? 0;
    final aWickets = match['away_wickets'] ?? 0;
    final hOvers = match['home_overs']?.toString() ?? '';
    final aOvers = match['away_overs']?.toString() ?? '';

    final Color badgeColor;
    final String badgeText;
    if (isLive) {
      badgeColor = Colors.deepOrange;
      badgeText = 'LIVE';
    } else {
      badgeColor = AppTheme.primary;
      badgeText = 'NEXT';
    }

    return GestureDetector(
      onTap: isLive
          ? () => context.push('/tournaments/match/$matchId', extra: {
                'homeTeamName': homeTeam,
                'awayTeamName': awayTeam,
                'matchNumber': matchNumber,
                'tournamentName': tournamentName,
              })
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLive
                ? [Colors.deepOrange.withValues(alpha: 0.3), AppTheme.surface]
                : [AppTheme.cardElite.withValues(alpha: 0.2), AppTheme.surface],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? Colors.deepOrange.withValues(alpha: 0.5)
                : AppTheme.cardElite.withValues(alpha: 0.3),
          ),
        ),
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
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(badgeText,
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$tournamentName · Match $matchNumber',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLive)
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
                      if (isLive)
                        Text('$hScore/$hWickets${hOvers.isNotEmpty ? ' ($hOvers ov)' : ''}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent))
                      else
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
                      if (isLive)
                        Text('$aScore/$aWickets${aOvers.isNotEmpty ? ' ($aOvers ov)' : ''}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
                      else
                        const Text('--', style: TextStyle(fontSize: 18, color: Colors.white38)),
                    ],
                  ),
                ),
              ],
            ),
            // Chase info
            if (isLive) ...[
              () {
                final liveInnings = match['live_innings'] as int? ?? 1;
                final target = match['target'] as int? ?? 0;
                final matchOvers = match['match_overs'] as int? ?? 20;
                if (liveInnings >= 2 && target > 0) {
                  final hbf = match['home_bats_first'] as bool? ?? true;
                  final chasingTeam = hbf ? awayTeam : homeTeam;
                  final chasingScore = hbf ? aScore : hScore;
                  final chasingOvers = hbf ? aOvers : hOvers;
                  final runsNeeded = target - chasingScore;
                  // Parse overs to compute balls remaining
                  final overParts = chasingOvers.split('.');
                  final completedOvers = int.tryParse(overParts[0]) ?? 0;
                  final ballsInOver = overParts.length > 1 ? (int.tryParse(overParts[1]) ?? 0) : 0;
                  final totalBallsBowled = completedOvers * 6 + ballsInOver;
                  final totalBalls = matchOvers * 6;
                  final ballsRemaining = totalBalls - totalBallsBowled;
                  if (runsNeeded > 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$chasingTeam need $runsNeeded from $ballsRemaining balls',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              }(),
            ],
            // Commentary
            if (isLive && _lastCommentary != null && _lastCommentary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _lastCommentary!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Schedule info for pending matches
            if (isPending && scheduledAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    'Starts ${_formatScheduledTime(scheduledAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (isLive) ...[
              const SizedBox(height: 8),
              const Text('Tap to watch live',
                  style: TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatScheduledTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Starting soon...';
    if (diff.inMinutes < 1) return 'Starting in < 1 min';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    return 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}
