import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/coin_display.dart';
import 'season_tier_badge.dart';
import 'daily_reward_button.dart';
import 'stat_chip.dart';

/// Hero header section of the dashboard with user info, coins, and stats.
class HeroHeader extends ConsumerWidget {
  final UserModel user;
  final bool showDailyReward;
  final VoidCallback onClaimDailyReward;

  const HeroHeader({
    super.key,
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
              SeasonTierBadge(tier: user.seasonTier),
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
          Row(
            children: [
              Expanded(child: CoinDisplay(coins: user.coins, premiumTokens: user.premiumTokens)),
              if (showDailyReward) ...[
                const SizedBox(width: 8),
                DailyRewardButton(onTap: onClaimDailyReward),
              ],
            ],
          ),
          const SizedBox(height: 12),
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
          Row(
            children: [
              StatChip(label: 'Played', value: '${user.matchesPlayed}', icon: Icons.sports_cricket),
              const SizedBox(width: 8),
              StatChip(label: 'Won', value: '${user.matchesWon}', icon: Icons.emoji_events),
              const SizedBox(width: 8),
              StatChip(label: 'WR', value: '${user.winRate.toStringAsFixed(0)}%', icon: Icons.trending_up),
              const SizedBox(width: 8),
              StatChip(label: 'LV ${user.level}', value: '', icon: Icons.star),
            ],
          ),
          const SizedBox(height: 10),
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
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}