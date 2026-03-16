import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/match_provider.dart';
import '../providers/multiplayer_provider.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MATCH HISTORY'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'QUICK MATCH'),
            Tab(text: 'MULTIPLAYER'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QuickMatchHistory(),
          _MultiplayerHistory(),
        ],
      ),
    );
  }
}

class _QuickMatchHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No quick matches played yet',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 8),
            Text('Play a quick match and it will appear here',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final match = history[index];
        return _MatchHistoryCard(
          match: match,
          onTap: () => _showScorecard(context, match),
        );
      },
    );
  }

  void _showScorecard(BuildContext context, MatchSummary match) {
    _openScorecardSheet(context, match);
  }
}

class _MultiplayerHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(multiplayerMatchHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (e, _) => Center(
        child: Text('Failed to load: $e', style: const TextStyle(color: Colors.white38)),
      ),
      data: (history) {
        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text('No multiplayer matches played yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
                SizedBox(height: 8),
                Text('Challenge someone in the multiplayer lobby!',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final match = history[index];
            return _MatchHistoryCard(
              match: match,
              isMultiplayer: true,
              onTap: () => _openScorecardSheet(context, match),
            );
          },
        );
      },
    );
  }
}

void _openScorecardSheet(BuildContext context, MatchSummary match) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => _ScorecardSheet(
        match: match,
        scrollController: controller,
      ),
    ),
  );
}

class _MatchHistoryCard extends StatelessWidget {
  final MatchSummary match;
  final VoidCallback onTap;
  final bool isMultiplayer;

  const _MatchHistoryCard({required this.match, required this.onTap, this.isMultiplayer = false});

  @override
  Widget build(BuildContext context) {
    final isWin = match.homeWon == true;
    final isDraw = match.homeWon == null;
    final resultColor = isWin ? AppTheme.accent : isDraw ? Colors.blueAccent : Colors.redAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: resultColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: format + result + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isWin ? 'WON' : isDraw ? 'DRAW' : 'LOST',
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isMultiplayer ? 'MP · ${match.format.toUpperCase()}' : match.format.toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  _formatDate(match.playedAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scores
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.homeTeamName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${match.homeScore}/${match.homeWickets} (${match.homeOvers})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
                const Text('vs', style: TextStyle(color: Colors.white38)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        match.awayTeamName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        '${match.awayScore}/${match.awayWickets} (${match.awayOvers})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // Rewards row
            Row(
              children: [
                const Icon(Icons.monetization_on, size: 14, color: AppTheme.cardGold),
                const SizedBox(width: 4),
                Text(
                  '+${match.coinsAwarded}',
                  style: const TextStyle(color: AppTheme.cardGold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.star, size: 14, color: AppTheme.primaryLight),
                const SizedBox(width: 4),
                Text(
                  '+${match.xpAwarded} XP',
                  style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text(
                  'Tap for scorecard',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ScorecardSheet extends StatelessWidget {
  final MatchSummary match;
  final ScrollController scrollController;

  const _ScorecardSheet({required this.match, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final inn1Batsmen = match.batsmanStats.values.where((b) => b.innings == 1).toList();
    final inn2Batsmen = match.batsmanStats.values.where((b) => b.innings == 2).toList();
    final inn1Bowlers = match.bowlerStats.values.where((b) => b.innings == 1).toList();
    final inn2Bowlers = match.bowlerStats.values.where((b) => b.innings == 2).toList();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title
        Text(
          'SCORECARD',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppTheme.accent,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${match.homeTeamName} vs ${match.awayTeamName}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Innings 1
        if (inn1Batsmen.isNotEmpty) ...[
          _inningsHeader('${match.battingFirstName} Batting', match.inn1Score, match.inn1Wickets, match.inn1Overs),
          _battingTable(inn1Batsmen),
          const SizedBox(height: 4),
          _bowlingTable(inn1Bowlers),
        ],
        const SizedBox(height: 16),

        // Innings 2
        if (inn2Batsmen.isNotEmpty) ...[
          _inningsHeader('${match.battingSecondName} Batting', match.inn2Score, match.inn2Wickets, match.inn2Overs),
          _battingTable(inn2Batsmen),
          const SizedBox(height: 4),
          _bowlingTable(inn2Bowlers),
        ],

        const SizedBox(height: 24),
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

  Widget _battingTable(List<BatsmanStats> batsmen) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
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
                        Text(b.dismissalType!, style: const TextStyle(fontSize: 10, color: Colors.redAccent))
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

  Widget _bowlingTable(List<BowlerStats> bowlers) {
    if (bowlers.isEmpty) return const SizedBox();

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
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
                  child: Text(b.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
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
