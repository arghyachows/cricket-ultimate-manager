import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';

class LiveMatchScreen extends ConsumerWidget {
  const LiveMatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(matchProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('LIVE MATCH'),
        actions: [
          if (matchState.isSimulating)
            TextButton(
              onPressed: () => ref.read(matchProvider.notifier).skipToEnd(),
              child: const Text('SKIP TO END', style: TextStyle(color: AppTheme.accent)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard
          _buildScoreboard(matchState),
          const SizedBox(height: 8),

          // Live commentary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceLight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                matchState.currentCommentary ?? 'Match starting...',
                key: ValueKey(matchState.events.length),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Batting stats
          if (matchState.batsmanStats.isNotEmpty)
            _buildBatsmanPanel(matchState),

          // Bowler stats
          if (matchState.bowlerStats.isNotEmpty)
            _buildBowlerPanel(matchState),

          // Ball timeline
          Expanded(
            child: _buildTimeline(matchState),
          ),

          // Match result
          if (!matchState.isSimulating && matchState.events.isNotEmpty)
            _buildMatchResult(context, ref, matchState),
        ],
      ),
    );
  }

  Widget _buildScoreboard(MatchState state) {
    final lastEvent = state.events.isNotEmpty ? state.events.last : null;
    final score = lastEvent?.scoreAfter ?? 0;
    final wickets = lastEvent?.wicketsAfter ?? 0;
    final overs = lastEvent != null
        ? '${lastEvent.overNumber}.${lastEvent.ballNumber}'
        : '0.0';

    final battingTeam = state.currentInnings == 1
        ? state.homeTeamName
        : state.awayTeamName;
    final bowlingTeam = state.currentInnings == 1
        ? state.awayTeamName
        : state.homeTeamName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.6), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          // Team names
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  battingTeam,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'vs',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Expanded(
                child: Text(
                  bowlingTeam,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white54,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Innings indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: state.currentInnings == 1
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : AppTheme.cardElite.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'INNINGS ${state.currentInnings}',
                  style: TextStyle(
                    color: state.currentInnings == 1 ? AppTheme.accent : AppTheme.cardElite,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '/$wickets',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Text(
            '($overs overs)',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white54,
            ),
          ),
          if (state.isSimulating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatsmanPanel(MatchState state) {
    final activeBatsmen = state.batsmanStats.values
        .where((b) => !b.isOut)
        .take(2)
        .toList();

    if (activeBatsmen.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surface,
      child: Row(
        children: activeBatsmen.map((b) {
          return Expanded(
            child: Row(
              children: [
                const Icon(Icons.sports_cricket, size: 14, color: AppTheme.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    b.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${b.runs}(${b.balls})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBowlerPanel(MatchState state) {
    final lastEvent = state.events.isNotEmpty ? state.events.last : null;
    if (lastEvent == null) return const SizedBox();

    final bowler = state.bowlerStats[lastEvent.bowlerCardId];
    if (bowler == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surfaceLight,
      child: Row(
        children: [
          const Icon(Icons.sports_baseball, size: 14, color: Colors.redAccent),
          const SizedBox(width: 6),
          Text(bowler.name, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            '${bowler.oversDisplay}-${bowler.maidens}-${bowler.runs}-${bowler.wickets}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(MatchState state) {
    if (state.events.isEmpty) {
      return const Center(
        child: Text('Waiting for match to start...', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: state.events.length,
      itemBuilder: (context, index) {
        final event = state.events[state.events.length - 1 - index];
        return _buildEventTile(event);
      },
    );
  }

  Widget _buildEventTile(MatchEvent event) {
    Color eventColor;
    IconData eventIcon;

    switch (event.eventType) {
      case 'four':
        eventColor = AppTheme.primaryLight;
        eventIcon = Icons.looks_4;
        break;
      case 'six':
        eventColor = AppTheme.accent;
        eventIcon = Icons.looks_6;
        break;
      case 'wicket':
        eventColor = AppTheme.error;
        eventIcon = Icons.close;
        break;
      case 'dot_ball':
        eventColor = Colors.white38;
        eventIcon = Icons.fiber_manual_record;
        break;
      case 'wide':
      case 'no_ball':
        eventColor = Colors.orangeAccent;
        eventIcon = Icons.warning_amber;
        break;
      default:
        eventColor = Colors.white54;
        eventIcon = Icons.circle_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: eventColor, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            child: Text(
              event.overDisplay,
              style: TextStyle(
                color: eventColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Icon(eventIcon, size: 16, color: eventColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.commentary ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          if (event.runs > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: eventColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${event.runs}',
                style: TextStyle(
                  color: eventColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatchResult(BuildContext context, WidgetRef ref, MatchState state) {
    final isWin = state.homeWon == true;
    final isDraw = state.homeWon == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWin
              ? [AppTheme.accent.withValues(alpha: 0.3), AppTheme.surface]
              : isDraw
                  ? [Colors.blueAccent.withValues(alpha: 0.2), AppTheme.surface]
                  : [AppTheme.error.withValues(alpha: 0.2), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          Icon(
            isWin ? Icons.emoji_events : isDraw ? Icons.handshake : Icons.sentiment_dissatisfied,
            color: isWin ? AppTheme.accent : isDraw ? Colors.blueAccent : Colors.white54,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            isWin ? 'VICTORY!' : isDraw ? 'MATCH DRAWN' : 'DEFEAT',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isWin ? AppTheme.accent : isDraw ? Colors.blueAccent : Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.currentCommentary ?? 'Match Complete',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Rewards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: AppTheme.cardGold, size: 20),
                const SizedBox(width: 6),
                Text(
                  '+${state.coinsAwarded}',
                  style: const TextStyle(
                    color: AppTheme.cardGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.star, color: AppTheme.primaryLight, size: 20),
                const SizedBox(width: 6),
                Text(
                  '+${state.xpAwarded} XP',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(matchProvider.notifier).reset();
              context.go(AppConstants.matchRoute);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isWin ? AppTheme.accent : null,
              foregroundColor: isWin ? Colors.black : null,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
}
