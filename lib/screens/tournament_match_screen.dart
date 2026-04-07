import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/node_backend_service.dart';
import '../core/supabase_service.dart';
import '../providers/match_provider.dart';

/// Commentary entry for the live timeline
class _TCommentaryEntry {
  final String commentary;
  final String eventType;
  final int runs;
  final int innings;
  final String oversDisplay;

  const _TCommentaryEntry({
    required this.commentary,
    required this.eventType,
    this.runs = 0,
    this.innings = 1,
    this.oversDisplay = '',
  });
}

class TournamentMatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String? homeTeamName;
  final String? awayTeamName;
  final int? matchNumber;
  final String? tournamentName;

  const TournamentMatchScreen({
    super.key,
    required this.matchId,
    this.homeTeamName,
    this.awayTeamName,
    this.matchNumber,
    this.tournamentName,
  });

  @override
  ConsumerState<TournamentMatchScreen> createState() =>
      _TournamentMatchScreenState();
}

class _TournamentMatchScreenState
    extends ConsumerState<TournamentMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _socketConnected = false;
  bool _isSimulating = false;
  bool _isMatchComplete = false;
  String? _error;

  // Scores
  String _homeTeamName = 'Home';
  String _awayTeamName = 'Away';
  bool _homeBatsFirst = true;
  int _homeScore = 0;
  int _homeWickets = 0;
  String _homeOvers = '0.0';
  int _awayScore = 0;
  int _awayWickets = 0;
  String _awayOvers = '0.0';
  int _currentInnings = 1;
  int _target = 0;
  int _matchOvers = 20;
  String? _currentCommentary;
  String? _matchResult;

  // Player info
  String _homeBatsman = '';
  String _awayBatsman = '';
  String _currentBowler = '';

  // Scorecard
  Map<String, BatsmanStats> _batsmanStats = {};
  Map<String, BowlerStats> _bowlerStats = {};

  // Commentary log
  final List<_TCommentaryEntry> _commentaryLog = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _homeTeamName = widget.homeTeamName ?? 'Home';
    _awayTeamName = widget.awayTeamName ?? 'Away';
    _loadAndConnect();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_socketConnected) {
      NodeBackendService.leaveMatch(widget.matchId);
    }
    super.dispose();
  }

  Future<void> _loadAndConnect() async {
    // First, check if match exists in DB and get its current state
    try {
      final data = await SupabaseService.client
          .from('matches')
          .select('*, home_teams:home_team_id(team_name), away_teams:away_team_id(team_name)')
          .eq('id', widget.matchId)
          .single();

      if (!mounted) return;

      _homeTeamName = data['home_teams']?['team_name'] ?? widget.homeTeamName ?? 'Home';
      _awayTeamName = data['away_teams']?['team_name'] ?? widget.awayTeamName ?? 'Away';
      final format = data['format'] ?? 't20';
      final oversMap = {'t10': 10, 't20': 20, 'odi': 50, 'test': 90};
      _matchOvers = oversMap[format] ?? 20;

      if (data['status'] == 'completed') {
        // Show completed match state
        setState(() {
          _isLoading = false;
          _isMatchComplete = true;
          _isSimulating = false;
          _homeScore = data['home_score'] ?? 0;
          _homeWickets = data['home_wickets'] ?? 0;
          _homeOvers = (data['home_overs'] ?? 0).toString();
          _awayScore = data['away_score'] ?? 0;
          _awayWickets = data['away_wickets'] ?? 0;
          _awayOvers = (data['away_overs'] ?? 0).toString();
          final winnerId = data['winner_team_id'];
          if (winnerId == data['home_team_id']) {
            _matchResult = '$_homeTeamName won';
          } else if (winnerId == data['away_team_id']) {
            _matchResult = '$_awayTeamName won';
          } else {
            _matchResult = 'Match Tied';
          }
        });
        // Fetch commentary for completed match
        _loadCommentary();
        return;
      }

      // Match is pending or in_progress — connect Socket.IO for live updates
      setState(() {
        _isLoading = false;
        _isSimulating = data['status'] == 'in_progress';
        if (_isSimulating) {
          _homeScore = data['home_score'] ?? 0;
          _homeWickets = data['home_wickets'] ?? 0;
          _awayScore = data['away_score'] ?? 0;
          _awayWickets = data['away_wickets'] ?? 0;
        }
      });

      _connectSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load match: $e';
      });
    }
  }

  Future<void> _connectSocket() async {
    NodeBackendService.initSocket();
    final connected = await NodeBackendService.waitForConnection(
      timeout: const Duration(seconds: 10),
    );

    if (!connected || !mounted) return;

    final joined = await NodeBackendService.joinMatch(
      widget.matchId,
      _onBallUpdate,
      _onMatchComplete,
    );

    if (joined && mounted) {
      setState(() => _socketConnected = true);
      // Load existing commentary for this match (catch-up on missed balls)
      _loadCommentary();
    }
  }

  Future<void> _loadCommentary() async {
    try {
      final entries = await NodeBackendService.getMatchCommentary(widget.matchId);
      if (!mounted || entries.isEmpty) return;
      setState(() {
        _commentaryLog.clear();
        for (final e in entries) {
          _commentaryLog.add(_TCommentaryEntry(
            commentary: e['commentary'] ?? '',
            eventType: e['eventType'] ?? '',
            runs: e['runs'] ?? 0,
            innings: e['innings'] ?? 1,
            oversDisplay: '${e['overNumber'] ?? 0}.${e['ballNumber'] ?? 0}',
          ));
        }
      });
    } catch (e) {
      print('⚠️ Failed to load commentary: $e');
    }
  }
  }

  void _onBallUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final result = data['result'] as Map<String, dynamic>?;
      final stateData = data['state'] as Map<String, dynamic>?;
      if (result == null || stateData == null) return;

      final innings = result['innings'] as int? ?? 1;
      final commentary = result['commentary'] as String? ?? '';
      final eventType = result['eventType'] as String? ?? '';
      final runs = result['runs'] as int? ?? 0;
      final overNumber = result['overNumber'] as int? ?? 0;
      final ballNumber = result['ballNumber'] as int? ?? 0;

      final score1 = stateData['score1'] as int? ?? 0;
      final score2 = stateData['score2'] as int? ?? 0;
      final wickets1 = stateData['wickets1'] as int? ?? 0;
      final wickets2 = stateData['wickets2'] as int? ?? 0;
      final target = stateData['target'] as int? ?? 0;
      final currentBatsmanName = stateData['currentBatsman'] as String? ?? '';
      final currentBowlerName = stateData['currentBowler'] as String? ?? '';

      // Pick up homeBatsFirst from state if available
      if (stateData.containsKey('homeBatsFirst')) {
        _homeBatsFirst = stateData['homeBatsFirst'] as bool? ?? _homeBatsFirst;
      }

      final hbf = _homeBatsFirst;
      final homeScore = hbf ? score1 : score2;
      final homeWickets = hbf ? wickets1 : wickets2;
      final awayScore = hbf ? score2 : score1;
      final awayWickets = hbf ? wickets2 : wickets1;

      final oversStr = '$overNumber.$ballNumber';
      String homeOvers = _homeOvers;
      String awayOvers = _awayOvers;
      if (innings == 1) {
        if (hbf) homeOvers = oversStr; else awayOvers = oversStr;
      } else {
        if (hbf) awayOvers = oversStr; else homeOvers = oversStr;
      }

      // Update batsman/bowler names
      String homeBatsman = _homeBatsman;
      String awayBatsman = _awayBatsman;
      if ((innings == 1 && hbf) || (innings == 2 && !hbf)) {
        homeBatsman = currentBatsmanName;
      } else {
        awayBatsman = currentBatsmanName;
      }

      // Scorecard stats
      final batsmanStatsData = stateData['batsmanStats'] as Map<String, dynamic>? ?? {};
      final batsmanStats = <String, BatsmanStats>{};
      batsmanStatsData.forEach((key, value) {
        final stats = value as Map<String, dynamic>;
        batsmanStats[key] = BatsmanStats(
          name: stats['name'] ?? '',
          innings: stats['innings'] ?? 1,
          battingOrder: stats['battingOrder'] ?? 99,
          runs: stats['runs'] ?? 0,
          balls: stats['balls'] ?? 0,
          fours: stats['fours'] ?? 0,
          sixes: stats['sixes'] ?? 0,
          isOut: stats['isOut'] ?? false,
          dismissalType: stats['dismissalType'],
        );
      });

      final bowlerStatsData = stateData['bowlerStats'] as Map<String, dynamic>? ?? {};
      final bowlerStats = <String, BowlerStats>{};
      bowlerStatsData.forEach((key, value) {
        final stats = value as Map<String, dynamic>;
        bowlerStats[key] = BowlerStats(
          name: stats['name'] ?? '',
          innings: stats['innings'] ?? 1,
          balls: stats['balls'] ?? 0,
          runs: stats['runs'] ?? 0,
          wickets: stats['wickets'] ?? 0,
          maidens: stats['maidens'] ?? 0,
          dotBalls: stats['dotBalls'] ?? 0,
        );
      });

      // Commentary log
      if (commentary.isNotEmpty) {
        final currentOvers = (innings == 1)
            ? (hbf ? homeOvers : awayOvers)
            : (hbf ? awayOvers : homeOvers);
        _commentaryLog.add(_TCommentaryEntry(
          commentary: commentary,
          eventType: eventType,
          runs: runs,
          innings: innings,
          oversDisplay: currentOvers,
        ));
      }

      setState(() {
        _isSimulating = true;
        _homeScore = homeScore;
        _homeWickets = homeWickets;
        _awayScore = awayScore;
        _awayWickets = awayWickets;
        _homeOvers = homeOvers;
        _awayOvers = awayOvers;
        _currentInnings = innings;
        _target = target;
        _currentCommentary = commentary;
        _homeBatsman = homeBatsman;
        _awayBatsman = awayBatsman;
        _currentBowler = currentBowlerName;
        _batsmanStats = batsmanStats;
        _bowlerStats = bowlerStats;
      });
    } catch (e) {
      print('❌ Tournament match ball update error: $e');
    }
  }

  void _onMatchComplete(Map<String, dynamic> data) {
    if (!mounted) return;
    final result = data['result'] as String? ?? 'Match completed';
    setState(() {
      _isSimulating = false;
      _isMatchComplete = true;
      _matchResult = result;
    });
  }

  // ─── Computed helpers ────────────────────────────────────────────

  int get _runsNeeded {
    if (_currentInnings < 2 || _target == 0) return 0;
    final chasingScore = _homeBatsFirst ? _awayScore : _homeScore;
    final needed = _target + 1 - chasingScore;
    return needed > 0 ? needed : 0;
  }

  int get _ballsRemaining {
    final chasingOvers = _homeBatsFirst ? _awayOvers : _homeOvers;
    final parts = chasingOvers.split('.');
    final fullOvers = int.tryParse(parts[0]) ?? 0;
    final extraBalls = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final ballsBowled = fullOvers * 6 + extraBalls;
    return (_matchOvers * 6) - ballsBowled;
  }

  double get _requiredRunRate {
    if (_currentInnings < 2 || _ballsRemaining <= 0) return 0;
    return (_runsNeeded / _ballsRemaining) * 6;
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.matchNumber != null
        ? 'MATCH ${widget.matchNumber}'
        : 'TOURNAMENT MATCH';
    final subtitle = widget.tournamentName;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.pop(), child: const Text('BACK')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'LIVE'), Tab(text: 'SCORECARD')],
        ),
      ),
      body: Column(
        children: [
          _buildScoreboard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLiveTab(), _buildScorecardTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Scoreboard ─────────────────────────────────────────────────

  Widget _buildScoreboard() {
    final homeBatting = _homeBatsFirst ? _currentInnings == 1 : _currentInnings == 2;
    final homeHasBatted = _homeBatsFirst || _currentInnings >= 2 || _isMatchComplete;
    final awayHasBatted = !_homeBatsFirst || _currentInnings >= 2 || _isMatchComplete;

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
                    Text(_homeTeamName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: homeBatting ? AppTheme.accent : Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (homeHasBatted)
                      Row(children: [
                        Text('$_homeScore/$_homeWickets',
                            style: TextStyle(
                              fontSize: homeBatting ? 28 : 22,
                              fontWeight: FontWeight.bold,
                              color: homeBatting ? Colors.white : Colors.white54,
                            )),
                        const SizedBox(width: 6),
                        Text('($_homeOvers)', style: const TextStyle(fontSize: 13, color: Colors.white38)),
                      ])
                    else
                      const Text('Yet to bat', style: TextStyle(fontSize: 14, color: Colors.white38)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _currentInnings == 1
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : AppTheme.cardElite.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('INN $_currentInnings',
                    style: TextStyle(
                      color: _currentInnings == 1 ? AppTheme.accent : AppTheme.cardElite,
                      fontWeight: FontWeight.bold, fontSize: 10,
                    )),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_awayTeamName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: !homeBatting ? AppTheme.accent : Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (awayHasBatted) ...[
                          Text('($_awayOvers)', style: const TextStyle(fontSize: 13, color: Colors.white38)),
                          const SizedBox(width: 6),
                          Text('$_awayScore/$_awayWickets',
                              style: TextStyle(
                                fontSize: !homeBatting ? 28 : 22,
                                fontWeight: FontWeight.bold,
                                color: !homeBatting ? Colors.white : Colors.white54,
                              )),
                        ] else
                          const Text('Yet to bat', style: TextStyle(fontSize: 14, color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isSimulating)
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
          if (_currentInnings >= 2 && _isSimulating && _runsNeeded > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_runsNeeded runs needed from $_ballsRemaining balls  (RRR: ${_requiredRunRate.toStringAsFixed(2)})',
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Live Tab ─────────────────────────────────────────────────────

  Widget _buildLiveTab() {
    return Column(
      children: [
        const SizedBox(height: 4),
        // Current commentary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.surfaceLight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _currentCommentary ?? (_isSimulating ? 'Match in progress...' : (_isMatchComplete ? (_matchResult ?? 'Match completed') : 'Waiting for match to start...')),
              key: ValueKey(_commentaryLog.length.toString() + (_currentCommentary ?? '')),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Batsman panel
        if (_homeBatsman.isNotEmpty || _awayBatsman.isNotEmpty) _buildBatsmanPanel(),
        // Bowler panel
        if (_currentBowler.isNotEmpty) _buildBowlerPanel(),
        // Timeline
        Expanded(child: _buildTimeline()),
        // Match result
        if (_isMatchComplete && _matchResult != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.accent.withValues(alpha: 0.15),
            child: Text(
              _matchResult!,
              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildBatsmanPanel() {
    BatsmanStats? findStats(String name) {
      if (name.isEmpty) return null;
      for (final b in _batsmanStats.values) {
        if (b.name == name && b.innings == _currentInnings) return b;
      }
      return null;
    }

    final strikerStats = findStats(_homeBatsman);
    final nonStrikerStats = findStats(_awayBatsman);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.sports_cricket, size: 16, color: AppTheme.accent),
            SizedBox(width: 8),
            Text('AT CREASE', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ]),
          const SizedBox(height: 6),
          Text(
            '${_homeBatsman}* ${strikerStats != null ? '${strikerStats.runs} (${strikerStats.balls})' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          if (_awayBatsman.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '$_awayBatsman ${nonStrikerStats != null ? '${nonStrikerStats.runs} (${nonStrikerStats.balls})' : ''}',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBowlerPanel() {
    BowlerStats? bowler;
    for (final b in _bowlerStats.values) {
      if (b.name == _currentBowler && b.innings == _currentInnings) {
        bowler = b;
        break;
      }
    }
    final figures = bowler != null ? '${bowler.wickets}/${bowler.runs} (${bowler.oversDisplay})' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surface,
      child: Row(children: [
        const Icon(Icons.sports_baseball, size: 14, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$_currentBowler${figures.isEmpty ? '' : ' · $figures'}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Text('BOWLING', style: TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    );
  }

  Widget _buildTimeline() {
    if (_commentaryLog.isEmpty) {
      if (_isMatchComplete) return const SizedBox.shrink();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSimulating) ...[
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
              const SizedBox(height: 12),
            ],
            Text(
              _isSimulating ? 'Waiting for ball-by-ball updates...' : 'Match has not started yet',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _commentaryLog.length,
      itemBuilder: (context, index) {
        final entry = _commentaryLog[_commentaryLog.length - 1 - index];
        return _buildEventTile(entry);
      },
    );
  }

  Widget _buildEventTile(_TCommentaryEntry entry) {
    Color eventColor;
    IconData eventIcon;

    switch (entry.eventType) {
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
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Text(entry.oversDisplay,
              style: TextStyle(color: eventColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
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

  // ─── Scorecard Tab ──────────────────────────────────────────────

  Widget _buildScorecardTab() {
    final inn1Batsmen = _batsmanStats.values.where((b) => b.innings == 1).toList()
      ..sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
    final inn2Batsmen = _batsmanStats.values.where((b) => b.innings == 2).toList()
      ..sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
    final inn1Bowlers = _bowlerStats.values.where((b) => b.innings == 1).toList();
    final inn2Bowlers = _bowlerStats.values.where((b) => b.innings == 2).toList();

    final battingFirstName = _homeBatsFirst ? _homeTeamName : _awayTeamName;
    final battingSecondName = _homeBatsFirst ? _awayTeamName : _homeTeamName;
    final inn1Score = _homeBatsFirst ? _homeScore : _awayScore;
    final inn1Wickets = _homeBatsFirst ? _homeWickets : _awayWickets;
    final inn1Overs = _homeBatsFirst ? _homeOvers : _awayOvers;
    final inn2Score = _homeBatsFirst ? _awayScore : _homeScore;
    final inn2Wickets = _homeBatsFirst ? _awayWickets : _homeWickets;
    final inn2Overs = _homeBatsFirst ? _awayOvers : _homeOvers;

    if (inn1Batsmen.isEmpty && inn2Batsmen.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.scoreboard, color: AppTheme.accent, size: 48),
              const SizedBox(height: 16),
              Text(
                _isMatchComplete ? 'Final Score' : 'Scorecard loading...',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
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
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.accent)),
          ),
          Text('$score/$wickets ($overs ov)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _battingCard(List<BatsmanStats> batsmen) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Batter',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('R',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('B',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('4s',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('6s',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('SR',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...batsmen.map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color:
                                    b.isOut ? Colors.white54 : Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis),
                          if (b.isOut && b.dismissalType != null)
                            Text(b.dismissalType!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.redAccent))
                          else if (!b.isOut)
                            const Text('not out',
                                style: TextStyle(
                                    fontSize: 10, color: AppTheme.accent)),
                        ],
                      ),
                    ),
                    Expanded(
                        child: Text('${b.runs}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: b.runs >= 50
                                    ? AppTheme.accent
                                    : Colors.white),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.balls}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.fours}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.sixes}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(b.strikeRate.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54),
                            textAlign: TextAlign.center)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.surfaceLight,
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Bowler',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('O',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('M',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('R',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('W',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('ECO',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...bowlers.map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(b.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                        child: Text(b.oversDisplay,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.maidens}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.runs}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${b.wickets}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: b.wickets >= 3
                                    ? AppTheme.accent
                                    : Colors.white),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(b.economy.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54),
                            textAlign: TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
