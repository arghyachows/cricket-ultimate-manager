import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';

class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  @override
  void initState() {
    super.initState();
    // Activate the match listener for auto-detecting wins
    Future.microtask(() => ref.read(challengeMatchListenerProvider));
  }

  void _playOpponent(ChallengeOpponent opponent) {
    final teamAsync = ref.read(teamProvider);
    final chemistry = ref.read(chemistryProvider);
    final team = teamAsync.valueOrNull;
    if (team == null) return;

    final squad = team.activeSquad;
    if (squad == null) return;
    if (squad.playingXI.length < 11) return;

    // Navigate to match preview with challenge parameters
    context.go(
      AppConstants.matchPreviewRoute,
      extra: {
        'challenge_mode': true,
        'opponent_difficulty': opponent.difficulty,
        'opponent_team_name': opponent.teamName,
        'opponent_chemistry': opponent.chemistry,
      },
    );
  }

  String _tierIcon(String tierName) {
    switch (tierName) {
      case 'Rookie': return '🌱';
      case 'Amateur': return '⭐';
      case 'Semi-Pro': return '🔥';
      case 'Professional': return '💎';
      case 'Champion': return '👑';
      case 'Elite': return '🏆';
      default: return '⚔️';
    }
  }

  Color _tierColor(String tierName) {
    switch (tierName) {
      case 'Rookie': return Colors.greenAccent;
      case 'Amateur': return Colors.lightBlueAccent;
      case 'Semi-Pro': return Colors.orangeAccent;
      case 'Professional': return Colors.purpleAccent;
      case 'Champion': return Colors.amberAccent;
      case 'Elite': return Colors.redAccent;
      default: return Colors.white70;
    }
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Village': return Colors.greenAccent;
      case 'Domestic': return Colors.orangeAccent;
      case 'International': return Colors.redAccent;
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengeState = ref.watch(challengeProvider);
    final teamAsync = ref.watch(teamProvider);
    final hasActiveMatch = ref.watch(matchProvider).hasActiveMatch;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('CHALLENGES'),
        actions: [
          // Weekly reset timer indicator
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.autorenew, size: 16, color: AppTheme.accent.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Weekly',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: challengeState.isLoaded
          ? _buildContent(challengeState, teamAsync, hasActiveMatch)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildContent(
    ChallengeState state,
    AsyncValue<dynamic> teamAsync,
    bool hasActiveMatch,
  ) {
    if (state.allCompleted) {
      return _buildCompletedView(state);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(challengeProvider.notifier).resetChallenges();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          _buildHeader(state),
          const SizedBox(height: 16),

          // Progress section
          _buildProgressCard(state),
          const SizedBox(height: 16),

          // Main content: opponent ladder
          const Text(
            'OPPONENT LADDER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),

          // Tier sections
          for (int t = 0; t < ChallengeConfig.tiers.length; t++)
            _buildTierSection(state, t, hasActiveMatch),

          const SizedBox(height: 24),

          // Reward preview
          if (!state.allCompleted)
            _buildRewardPreview(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(ChallengeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.5), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events, color: AppTheme.accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHALLENGE MODE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Defeat all opponents to win an Elite Pack!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Progress resets every week',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ChallengeState state) {
    final progress = state.totalCount > 0
        ? state.defeatedCount / state.totalCount
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROGRESS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white54),
              ),
              Text(
                '${state.defeatedCount} / ${state.totalCount}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.greenAccent : AppTheme.accent,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSection(ChallengeState state, int tierIndex, bool hasActiveMatch) {
    final tier = ChallengeConfig.tiers[tierIndex];
    final tierOpponents = state.opponents
        .where((o) => o.tierName == tier.name)
        .toList();

    if (tierOpponents.isEmpty) return const SizedBox.shrink();

    final allDefeated = tierOpponents.every((o) => o.isDefeated);
    final anyUnlocked = tierOpponents.any((o) => !o.isLocked);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allDefeated
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : anyUnlocked
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          // Tier header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (allDefeated ? Colors.greenAccent : _tierColor(tier.name))
                  .withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _tierIcon(tier.name),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tier.name} TIER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: allDefeated ? Colors.greenAccent : _tierColor(tier.name),
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        tier.difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          color: _difficultyColor(tier.difficulty).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (allDefeated)
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              ],
            ),
          ),

          // Opponents in this tier
          for (final opponent in tierOpponents)
            _buildOpponentTile(state, opponent, hasActiveMatch),
        ],
      ),
    );
  }

  Widget _buildOpponentTile(ChallengeState state, ChallengeOpponent opponent, bool hasActiveMatch) {
    final isCurrent = opponent.index == state.currentOpponentIndex;
    final isSelected = opponent.index == state.currentOpponentIndex;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: isSelected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: opponent.isLocked
              ? null
              : (hasActiveMatch ? null : () => _playOpponent(opponent)),
          borderRadius: BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: opponent.isDefeated
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : opponent.isLocked
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppTheme.accent.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: opponent.isDefeated
                        ? const Icon(Icons.check, color: Colors.greenAccent, size: 20)
                        : opponent.isLocked
                            ? const Icon(Icons.lock, color: Colors.white24, size: 18)
                            : isCurrent
                                ? const Icon(Icons.flash_on, color: AppTheme.accent, size: 20)
                                : const Icon(Icons.sports_cricket, color: AppTheme.accent, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                // Team info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponent.teamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: opponent.isLocked ? Colors.white38 : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (!opponent.isLocked) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _difficultyColor(opponent.difficulty).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                opponent.difficulty,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _difficultyColor(opponent.difficulty),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'RATING ${opponent.rating}',
                            style: TextStyle(
                              fontSize: 10,
                              color: opponent.isLocked ? Colors.white24 : Colors.white38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action / status
                if (opponent.isDefeated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'WON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  )
                else if (!opponent.isLocked && isCurrent && !hasActiveMatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PLAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cardElite.withValues(alpha: 0.15),
            AppTheme.cardGold.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardElite.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardElite.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard, color: AppTheme.cardElite, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPLETION REWARD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elite Pack',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cardElite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Defeat all 12 opponents to claim',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppTheme.cardElite, size: 16),
        ],
      ),
    );
  }

  Widget _buildCompletedView(ChallengeState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: AppTheme.cardGold),
            const SizedBox(height: 16),
            const Text(
              'ALL CHALLENGES COMPLETE!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You defeated all ${state.totalCount} opponents!',
              style: const TextStyle(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your packs for the Elite Pack reward',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.cardElite,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(AppConstants.packsRoute),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('OPEN PACKS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cardElite,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppConstants.matchHistoryRoute),
              child: const Text(
                'View Match History',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}