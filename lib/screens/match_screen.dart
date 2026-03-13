import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider);
    final chemistry = ref.watch(chemistryProvider);
    final matchState = ref.watch(matchProvider);
    final hasActiveMatch = matchState.hasActiveMatch;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PLAY MATCH'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(AppConstants.matchHistoryRoute),
            icon: const Icon(Icons.history, size: 18, color: Colors.white54),
            label: const Text('History', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (team) {
          if (team == null) {
            return const Center(
              child: Text('Create a team first', style: TextStyle(color: Colors.white54)),
            );
          }

          final squad = team.activeSquad;
          final xi = squad?.playingXI ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Team card
              _buildTeamCard(context, team, chemistry, xi),
              const SizedBox(height: 24),

              // Match modes
              const Text(
                'SELECT MODE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 12),

              if (hasActiveMatch) ...[
                GestureDetector(
                  onTap: () => context.go(AppConstants.liveMatchRoute),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_cricket, color: AppTheme.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                matchState.isSimulating ? 'Match in progress' : 'Match completed',
                                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap to view the current match',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: AppTheme.accent, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _MatchModeCard(
                title: 'QUICK MATCH',
                subtitle: 'Play a T20 against AI opponent',
                icon: Icons.flash_on,
                color: AppTheme.primaryLight,
                reward: '500 coins',
                enabled: xi.length == 11 && !hasActiveMatch,
                onTap: () => _startQuickMatch(context, ref, team, chemistry),
              ),
              const SizedBox(height: 12),

              _MatchModeCard(
                title: 'ODI CHALLENGE',
                subtitle: '50-over match for bigger rewards',
                icon: Icons.sports_cricket,
                color: AppTheme.cardGold,
                reward: '1000 coins',
                enabled: xi.length == 11 && !hasActiveMatch,
                onTap: () => _startODI(context, ref, team, chemistry),
              ),
              const SizedBox(height: 12),

              _MatchModeCard(
                title: 'TOURNAMENT',
                subtitle: 'Compete against other managers',
                icon: Icons.emoji_events,
                color: AppTheme.cardElite,
                reward: 'Varies',
                enabled: xi.length == 11 && !hasActiveMatch,
                onTap: () => context.go(AppConstants.tournamentsRoute),
              ),
              const SizedBox(height: 12),

              _MatchModeCard(
                title: 'WEEKEND LEAGUE',
                subtitle: 'Elite competition for top rewards',
                icon: Icons.military_tech,
                color: AppTheme.cardLegend,
                reward: 'Premium packs',
                enabled: xi.length == 11 && !hasActiveMatch,
                onTap: () {},
              ),

              if (xi.length < 11) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: AppTheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You need 11 players in your Playing XI. Currently: ${xi.length}/11',
                              style: const TextStyle(color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go(AppConstants.squadBuilderRoute),
                          icon: const Icon(Icons.groups, size: 18),
                          label: const Text('GO TO SQUAD BUILDER'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, team, int chemistry, List<SquadPlayer> xi) {
    final xiCount = xi.length;
    final avgRating = xi.isEmpty
        ? 0
        : (xi.fold<int>(0, (sum, p) => sum + (p.userCard?.playerCard?.rating ?? 0)) ~/ xi.length);
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: AppTheme.accent, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.teamName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'OVR $avgRating',
                      style: const TextStyle(color: AppTheme.accent, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.2),
                ),
                child: Text(
                  '$chemistry',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Players', '$xiCount/11'),
              _buildStat('Chemistry', '$chemistry/100'),
              _buildStat('Form', 'Good'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  void _startQuickMatch(BuildContext context, WidgetRef ref, team, int chemistry) {
    final squad = team.activeSquad;
    if (squad == null) return;
    context.go('${AppConstants.matchPreviewRoute}?format=t20');
  }

  void _startODI(BuildContext context, WidgetRef ref, team, int chemistry) {
    final squad = team.activeSquad;
    if (squad == null) return;
    context.go('${AppConstants.matchPreviewRoute}?format=odi');
  }
}

class _MatchModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String reward;
  final bool enabled;
  final VoidCallback onTap;

  const _MatchModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.reward,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reward,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
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
