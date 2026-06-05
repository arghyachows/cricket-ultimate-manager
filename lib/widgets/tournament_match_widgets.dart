import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/match/tournament_match_manager.dart';
import '../providers/match/match_state.dart';

// ─── Scoreboard ─────────────────────────────────────────────────

class ScoreboardWidget extends StatelessWidget {
  final TournamentMatchState s;
  final int currentInnings;
  final bool isMatchComplete;

  const ScoreboardWidget({
    super.key,
    required this.s,
    required this.currentInnings,
    required this.isMatchComplete,
  });

  @override
  Widget build(BuildContext context) {
    final homeBatting = s.homeBatsFirst ? currentInnings == 1 : currentInnings == 2;
    final homeHasBatted = s.homeBatsFirst || currentInnings >= 2 || isMatchComplete;
    final awayHasBatted = !s.homeBatsFirst || currentInnings >= 2 || isMatchComplete;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.6), AppTheme.surface],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.homeTeamName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                            color: homeBatting ? AppTheme.accent : Colors.white54),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (homeHasBatted)
                      Row(children: [
                        Text('${s.homeScore}/${s.homeWickets}',
                            style: TextStyle(fontSize: homeBatting ? 28 : 22,
                                fontWeight: FontWeight.bold,
                                color: homeBatting ? Colors.white : Colors.white54)),
                        const SizedBox(width: 6),
                        Text('(${s.homeOvers})', style: const TextStyle(fontSize: 13, color: Colors.white38)),
                      ])
                    else
                      const Text('Yet to bat', style: TextStyle(fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),
              _inningsBadge(currentInnings),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(s.awayTeamName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                            color: !homeBatting ? AppTheme.accent : Colors.white54),
                        overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (awayHasBatted) ...[
                        Text('(${s.awayOvers})', style: const TextStyle(fontSize: 13, color: Colors.white38)),
                        const SizedBox(width: 6),
                        Text('${s.awayScore}/${s.awayWickets}',
                            style: TextStyle(fontSize: !homeBatting ? 28 : 22,
                                fontWeight: FontWeight.bold,
                                color: !homeBatting ? Colors.white : Colors.white54)),
                      ] else
                        const Text('Yet to bat', style: TextStyle(fontSize: 14, color: Colors.white38)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (s.isSimulating) const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(width: 100, child: LinearProgressIndicator(
              backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(AppTheme.accent),
            )),
          ),
          if (currentInnings >= 2 && s.isSimulating) _runsNeededBanner(),
        ],
      ),
    );
  }

  Widget _inningsBadge(int inn) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: inn == 1
          ? AppTheme.accent.withValues(alpha: 0.2)
          : AppTheme.cardElite.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text('INN $inn', style: TextStyle(
      color: inn == 1 ? AppTheme.accent : AppTheme.cardElite,
      fontWeight: FontWeight.bold, fontSize: 10,
    )),
  );

  Widget _runsNeededBanner() {
    final runsNeeded = _calcRunsNeeded();
    final ballsRemaining = _calcBallsRemaining();
    final rrr = _calcRRR(runsNeeded, ballsRemaining);
    if (runsNeeded <= 0) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$runsNeeded runs needed from $ballsRemaining balls  (RRR: ${rrr.toStringAsFixed(2)})',
          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  int _calcRunsNeeded() {
    if (currentInnings < 2 || s.target == 0) return 0;
    final chasingScore = s.homeBatsFirst ? s.awayScore : s.homeScore;
    final needed = s.target + 1 - chasingScore;
    return needed > 0 ? needed : 0;
  }

  int _calcBallsRemaining() {
    final chasingOvers = s.homeBatsFirst ? s.awayOvers : s.homeOvers;
    final parts = chasingOvers.split('.');
    final fullOvers = int.tryParse(parts[0]) ?? 0;
    final extraBalls = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (s.matchOvers * 6) - (fullOvers * 6 + extraBalls);
  }

  double _calcRRR(int needed, int balls) {
    if (currentInnings < 2 || balls <= 0) return 0;
    return (needed / balls) * 6;
  }
}

// ─── Batsman Panel ──────────────────────────────────────────────

class BatsmanPanel extends StatelessWidget {
  final TournamentMatchState s;
  const BatsmanPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    BatsmanStats? find(String name) {
      if (name.isEmpty) return null;
      for (final b in s.batsmanStats.values) {
        if (b.name == name && b.innings == s.currentInnings) return b;
      }
      return null;
    }
    final striker = find(s.homeBatsman);
    final nonStriker = find(s.awayBatsman);
    if (s.homeBatsman.isEmpty && s.awayBatsman.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceLight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.sports_cricket, size: 16, color: AppTheme.accent),
          SizedBox(width: 8),
          Text('AT CREASE', style: TextStyle(fontSize: 10, color: Colors.white38)),
        ]),
        const SizedBox(height: 6),
        Text('${s.homeBatsman}*${striker != null ? ' ${striker.runs} (${striker.balls})' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            overflow: TextOverflow.ellipsis),
        if (s.awayBatsman.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('${s.awayBatsman}${nonStriker != null ? ' ${nonStriker.runs} (${nonStriker.balls})' : ''}',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

// ─── Bowler Panel ───────────────────────────────────────────────

class BowlerPanel extends StatelessWidget {
  final TournamentMatchState s;
  const BowlerPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    BowlerStats? bowler;
    for (final b in s.bowlerStats.values) {
      if (b.name == s.currentBowler && b.innings == s.currentInnings) {
        bowler = b; break;
      }
    }
    final figures = bowler != null ? '${bowler.wickets}/${bowler.runs} (${bowler.oversDisplay})' : '';
    if (s.currentBowler.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surface,
      child: Row(children: [
        const Icon(Icons.sports_baseball, size: 14, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('${s.currentBowler}${figures.isEmpty ? '' : ' · $figures'}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            overflow: TextOverflow.ellipsis)),
        const Text('BOWLING', style: TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    );
  }
}

// ─── Event Tile ─────────────────────────────────────────────────

class CommentaryEventTile extends StatelessWidget {
  final CommentaryEntry entry;
  const CommentaryEventTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    Color eventColor;
    IconData eventIcon;
    switch (entry.eventType) {
      case 'four':     eventColor = AppTheme.primaryLight; eventIcon = Icons.looks_4; break;
      case 'six':      eventColor = AppTheme.accent;      eventIcon = Icons.looks_6; break;
      case 'wicket':   eventColor = AppTheme.error;       eventIcon = Icons.close; break;
      case 'dot_ball': eventColor = Colors.white38; eventIcon = Icons.fiber_manual_record; break;
      case 'wide': case 'no_ball': eventColor = Colors.orangeAccent; eventIcon = Icons.warning_amber; break;
      default:         eventColor = Colors.white54; eventIcon = Icons.circle_outlined;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: eventColor, width: 3)),
      ),
      child: Row(children: [
        SizedBox(width: 50, child: Text(entry.oversDisplay,
            style: TextStyle(color: eventColor, fontWeight: FontWeight.bold, fontSize: 13))),
        Icon(eventIcon, size: 16, color: eventColor),
        const SizedBox(width: 8),
        Expanded(child: Text(entry.commentary, style: const TextStyle(fontSize: 13, color: Colors.white70))),
        if (entry.runs > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: eventColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('+${entry.runs}',
                style: TextStyle(color: eventColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ]),
    );
  }
}

// ─── Commentary Timeline ────────────────────────────────────────

class CommentaryTimeline extends StatelessWidget {
  final TournamentMatchState s;
  const CommentaryTimeline({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    if (s.commentaryLog.isEmpty) {
      if (s.isMatchComplete) return const SizedBox.shrink();
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s.isSimulating) const SizedBox(
            width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
          ),
          const SizedBox(height: 12),
          Text(s.isSimulating ? 'Waiting for ball-by-ball updates...' : 'Match has not started yet',
              style: const TextStyle(color: Colors.white38)),
        ]),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: s.commentaryLog.length,
      itemBuilder: (context, index) => CommentaryEventTile(
        entry: s.commentaryLog[s.commentaryLog.length - 1 - index],
      ),
    );
  }
}

// ─── Scorecard Tab ──────────────────────────────────────────────

class ScorecardTab extends StatelessWidget {
  final TournamentMatchState s;
  const ScorecardTab({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final inn1Batsmen = s.batsmanStats.values.where((b) => b.innings == 1).toList()
      ..sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
    final inn2Batsmen = s.batsmanStats.values.where((b) => b.innings == 2).toList()
      ..sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
    final inn1Bowlers = s.bowlerStats.values.where((b) => b.innings == 1).toList();
    final inn2Bowlers = s.bowlerStats.values.where((b) => b.innings == 2).toList();

    final battingFirstName = s.homeBatsFirst ? s.homeTeamName : s.awayTeamName;
    final battingSecondName = s.homeBatsFirst ? s.awayTeamName : s.homeTeamName;
    final inn1Score = s.homeBatsFirst ? s.homeScore : s.awayScore;
    final inn1Wickets = s.homeBatsFirst ? s.homeWickets : s.awayWickets;
    final inn1Overs = s.homeBatsFirst ? s.homeOvers : s.awayOvers;
    final inn2Score = s.homeBatsFirst ? s.awayScore : s.homeScore;
    final inn2Wickets = s.homeBatsFirst ? s.awayWickets : s.homeWickets;
    final inn2Overs = s.homeBatsFirst ? s.awayOvers : s.homeOvers;

    if (inn1Batsmen.isEmpty && inn2Batsmen.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.scoreboard, color: AppTheme.accent, size: 48),
          const SizedBox(height: 16),
          Text(s.isMatchComplete ? 'Final Score' : 'Scorecard loading...',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ]),
      ));
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      if (inn1Batsmen.isNotEmpty) ...[
        _inningsHeader('$battingFirstName Batting', inn1Score, inn1Wickets, inn1Overs),
        _battingCard(inn1Batsmen),
        const SizedBox(height: 4),
        _bowlingCard(inn1Bowlers),
      ],
      const SizedBox(height: 16),
      if (inn2Batsmen.isNotEmpty) ...[
        _inningsHeader('$battingSecondName Batting', inn2Score, inn2Wickets, inn2Overs),
        _battingCard(inn2Batsmen),
        const SizedBox(height: 4),
        _bowlingCard(inn2Bowlers),
      ],
      const SizedBox(height: 80),
    ]);
  }

  Widget _inningsHeader(String title, int score, int wickets, String overs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.4),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
    ),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent))),
      Text('$score/$wickets ($overs ov)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
    ]),
  );

  Widget _battingCard(List<BatsmanStats> batsmen) => Container(
    color: AppTheme.surface,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: AppTheme.surfaceLight,
        child: const Row(children: [
          Expanded(flex: 4, child: Text('Batter', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold))),
          Expanded(child: Text('R', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('B', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('4s', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('6s', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('SR', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ]),
      ),
      ...batsmen.map((b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
        child: Row(children: [
          Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: b.isOut ? Colors.white54 : Colors.white), overflow: TextOverflow.ellipsis),
            if (b.isOut && b.dismissalType != null)
              Text(b.dismissalType!, style: const TextStyle(fontSize: 10, color: Colors.redAccent))
            else if (!b.isOut)
              const Text('not out', style: TextStyle(fontSize: 10, color: AppTheme.accent)),
          ])),
          Expanded(child: Text('${b.runs}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: b.runs >= 50 ? AppTheme.accent : Colors.white), textAlign: TextAlign.center)),
          Expanded(child: Text('${b.balls}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
          Expanded(child: Text('${b.fours}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
          Expanded(child: Text('${b.sixes}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
          Expanded(child: Text(b.strikeRate.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center)),
        ]),
      )),
    ]),
  );

  Widget _bowlingCard(List<BowlerStats> bowlers) {
    if (bowlers.isEmpty) return const SizedBox();
    return Container(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: AppTheme.surfaceLight,
          child: const Row(children: [
            Expanded(flex: 4, child: Text('Bowler', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold))),
            Expanded(child: Text('O', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            Expanded(child: Text('M', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            Expanded(child: Text('R', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            Expanded(child: Text('W', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            Expanded(child: Text('ECO', style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          ]),
        ),
        ...bowlers.map((b) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
          child: Row(children: [
            Expanded(flex: 4, child: Text(b.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Expanded(child: Text(b.oversDisplay, style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
            Expanded(child: Text('${b.maidens}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
            Expanded(child: Text('${b.runs}', style: const TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center)),
            Expanded(child: Text('${b.wickets}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: b.wickets >= 3 ? AppTheme.accent : Colors.white), textAlign: TextAlign.center)),
            Expanded(child: Text(b.economy.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center)),
          ]),
        )),
      ]),
    );
  }
}
