import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'LIVE'),
            Tab(text: 'SCORECARD'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Scoreboard always visible
          _buildScoreboard(matchState),

          // Tabbed content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Live view
                _buildLiveTab(context, ref, matchState),
                // Tab 2: Scorecard
                _ScorecardTab(matchState: matchState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab(BuildContext context, WidgetRef ref, MatchState matchState) {
    return Column(
      children: [
        const SizedBox(height: 4),
        // Live commentary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.surfaceLight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              matchState.currentCommentary ?? 'Match starting...',
              key: ValueKey(matchState.events.length),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Current batsmen (filtered by current innings)
        if (matchState.currentBatsmen.isNotEmpty)
          _buildBatsmanPanel(matchState),

        // Current bowler
        if (matchState.currentBowlers.isNotEmpty)
          _buildBowlerPanel(matchState),

        // Ball timeline
        Expanded(
          child: _buildTimeline(matchState),
        ),

        // Match result
        if (!matchState.isSimulating && matchState.events.isNotEmpty)
          _buildMatchResult(context, ref, matchState),
      ],
    );
  }

  Widget _buildScoreboard(MatchState state) {
    // Determine which team is currently batting based on toss result
    final homeBatting = state.homeBatsFirst
        ? state.currentInnings == 1
        : state.currentInnings == 2;
    final homeHasBatted = state.homeBatsFirst ||
        state.currentInnings >= 2 ||
        state.isMatchComplete;
    final awayHasBatted = !state.homeBatsFirst ||
        state.currentInnings >= 2 ||
        state.isMatchComplete;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.6), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          // Both teams side by side
          Row(
            children: [
              // Home team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.homeTeamName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: homeBatting ? AppTheme.accent : Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (homeHasBatted)
                      Row(
                        children: [
                          Text(
                            '${state.homeScore}/${state.homeWickets}',
                            style: TextStyle(
                              fontSize: homeBatting ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: homeBatting ? Colors.white : Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${state.homeOvers})',
                            style: const TextStyle(fontSize: 13, color: Colors.white38),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Yet to bat',
                        style: TextStyle(fontSize: 14, color: Colors.white38),
                      ),
                  ],
                ),
              ),
              // VS + Innings indicator
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: state.currentInnings == 1
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.cardElite.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'INN ${state.currentInnings}',
                      style: TextStyle(
                        color: state.currentInnings == 1 ? AppTheme.accent : AppTheme.cardElite,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              // Away team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      state.awayTeamName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: !homeBatting ? AppTheme.accent : Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (awayHasBatted) ...[
                          Text(
                            '(${state.awayOvers})',
                            style: const TextStyle(fontSize: 13, color: Colors.white38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${state.awayScore}/${state.awayWickets}',
                            style: TextStyle(
                              fontSize: !homeBatting ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: !homeBatting ? Colors.white : Colors.white54,
                            ),
                          ),
                        ] else
                          const Text(
                            'Yet to bat',
                            style: TextStyle(fontSize: 14, color: Colors.white38),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
          // Chase info during 2nd innings
          if (state.currentInnings >= 2 && state.isSimulating && state.runsNeeded > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.runsNeeded} runs needed from ${state.ballsRemaining} balls  (RRR: ${state.requiredRunRate.toStringAsFixed(2)})',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatsmanPanel(MatchState state) {
    // Show only current innings batsmen who are not out (max 2 at crease)
    final activeBatsmen = state.currentBatsmen.take(2).toList();

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
    // Show the most recent bowler for the current innings
    final currentBowlers = state.currentBowlers;
    if (currentBowlers.isEmpty) return const SizedBox();

    // The last bowler in the list is typically the current one
    final bowler = currentBowlers.last;

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
          SizedBox(
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

// ─── Scorecard Tab ───────────────────────────────────────────────────────────

class _ScorecardTab extends StatelessWidget {
  final MatchState matchState;
  const _ScorecardTab({required this.matchState});

  @override
  Widget build(BuildContext context) {
    final battingFirstName = matchState.homeBatsFirst ? matchState.homeTeamName : matchState.awayTeamName;
    final battingSecondName = matchState.homeBatsFirst ? matchState.awayTeamName : matchState.homeTeamName;
    final inn1Score = matchState.homeBatsFirst ? matchState.homeScore : matchState.awayScore;
    final inn1Wickets = matchState.homeBatsFirst ? matchState.homeWickets : matchState.awayWickets;
    final inn1Overs = matchState.homeBatsFirst ? matchState.homeOvers : matchState.awayOvers;
    final inn2Score = matchState.homeBatsFirst ? matchState.awayScore : matchState.homeScore;
    final inn2Wickets = matchState.homeBatsFirst ? matchState.awayWickets : matchState.homeWickets;
    final inn2Overs = matchState.homeBatsFirst ? matchState.awayOvers : matchState.homeOvers;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Innings 1 Batting
        if (matchState.innings1Batsmen.isNotEmpty) ...[
          _inningsHeader('$battingFirstName Batting', inn1Score, inn1Wickets, inn1Overs),
          _battingCard(matchState.innings1Batsmen),
          const SizedBox(height: 4),
          _bowlingCard(matchState.innings1Bowlers),
        ],

        const SizedBox(height: 16),

        // Innings 2 Batting
        if (matchState.innings2Batsmen.isNotEmpty) ...[
          _inningsHeader('$battingSecondName Batting', inn2Score, inn2Wickets, inn2Overs),
          _battingCard(matchState.innings2Batsmen),
          const SizedBox(height: 4),
          _bowlingCard(matchState.innings2Bowlers),
        ],

        if (matchState.batsmanStats.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Scorecard will appear once the match starts',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _inningsHeader(String title, int score, int wickets, String overs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
            ),
          ),
          Text(
            '$score/$wickets ($overs ov)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _battingCard(List<BatsmanStats> batsmen) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Batter', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold))),
                Expanded(child: Text('R', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('B', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('4s', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('6s', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('SR', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...batsmen.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: b.isOut ? Colors.white54 : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (b.isOut && b.dismissalType != null)
                        Text(
                          b.dismissalType!,
                          style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                        )
                      else if (!b.isOut)
                        const Text('not out', style: TextStyle(fontSize: 10, color: AppTheme.accent)),
                    ],
                  ),
                ),
                Expanded(child: Text('${b.runs}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: b.runs >= 50 ? AppTheme.accent : Colors.white), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.balls}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.fours}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.sixes}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text(b.strikeRate.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _bowlingCard(List<BowlerStats> bowlers) {
    if (bowlers.isEmpty) return const SizedBox();

    return Container(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Bowler', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold))),
                Expanded(child: Text('O', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('M', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('R', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('W', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text('ECO', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...bowlers.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    b.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(child: Text(b.oversDisplay, style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.maidens}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.runs}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
                Expanded(child: Text('${b.wickets}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: b.wickets >= 3 ? AppTheme.accent : Colors.white), textAlign: TextAlign.center)),
                Expanded(child: Text(b.economy.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
