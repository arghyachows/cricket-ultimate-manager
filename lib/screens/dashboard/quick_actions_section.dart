import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'action_tile.dart';

/// Quick actions grid section (Play Match, Packs, Squad, etc).
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

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
                child: ActionTile(
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
                child: ActionTile(
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
              Expanded(child: ActionTile(icon: Icons.groups_rounded, label: 'Squad', color: Colors.blueAccent,
                  gradient: [Colors.blueAccent.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.squadBuilderRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: ActionTile(icon: Icons.emoji_events_rounded, label: 'Tourney', color: AppTheme.cardElite,
                  gradient: [AppTheme.cardElite.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.tournamentsRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: ActionTile(icon: Icons.leaderboard_rounded, label: 'Ranks', color: Colors.orangeAccent,
                  gradient: [Colors.orangeAccent.withValues(alpha: 0.2), AppTheme.surface],
                  onTap: () => context.go(AppConstants.leaderboardRoute), height: 82)),
              const SizedBox(width: 8),
              Expanded(child: ActionTile(icon: Icons.storefront_rounded, label: 'Market', color: Colors.tealAccent,
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