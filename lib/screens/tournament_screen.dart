import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/supabase_service.dart';
import '../core/node_backend_service.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tournaments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTournaments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tournaments = await NodeBackendService.getTournaments();
      if (mounted) {
        setState(() {
          _tournaments = tournaments;
          _isLoading = false;
        });
        // Auto-trigger check-start for open tournaments past their start time
        _checkAndStartOverdueTournaments(tournaments);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndStartOverdueTournaments(List<Map<String, dynamic>> tournaments) async {
    final now = DateTime.now();
    final overdue = tournaments.where((t) {
      if (t['status'] != 'open') return false;
      final startsAt = t['starts_at'] != null ? DateTime.tryParse(t['starts_at']) : null;
      return startsAt != null && startsAt.isBefore(now);
    }).toList();

    if (overdue.isEmpty) return;

    bool anyChanged = false;
    for (final t in overdue) {
      final result = await NodeBackendService.checkStartTournament(t['id']);
      if (result['status'] == 'in_progress' || result['status'] == 'cancelled') {
        anyChanged = true;
      }
    }

    // Reload if any tournament status changed
    if (anyChanged && mounted) {
      final refreshed = await NodeBackendService.getTournaments();
      if (mounted) {
        setState(() {
          _tournaments = refreshed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTournaments =
        _tournaments.where((t) => t['status'] == 'open').toList();
    final activeTournaments =
        _tournaments.where((t) => t['status'] == 'in_progress').toList();
    final cancelledTournaments =
        _tournaments.where((t) => t['status'] == 'cancelled').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TOURNAMENTS'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'OPEN (${openTournaments.length})'),
            Tab(text: 'LIVE (${activeTournaments.length})'),
            Tab(text: 'CANCELLED (${cancelledTournaments.length})'),
          ],
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTournaments,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTournamentDialog,
        icon: const Icon(Icons.add),
        label: const Text('CREATE'),
        backgroundColor: AppTheme.accent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error loading tournaments',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadTournaments,
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTournamentList(openTournaments, isOpen: true),
                    _buildTournamentList(activeTournaments, isOpen: false),
                    _buildTournamentList(cancelledTournaments, isOpen: false),
                  ],
                ),
    );
  }

  Widget _buildTournamentList(List<Map<String, dynamic>> tournaments,
      {required bool isOpen}) {
    if (tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOpen ? Icons.emoji_events_outlined : Icons.sports_cricket,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 20),
            Text(
              isOpen ? 'No Open Tournaments' : 'No Live Tournaments',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isOpen
                  ? 'New tournaments are created every Friday!'
                  : 'Tournaments will appear here once they start',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTournaments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tournaments.length,
        itemBuilder: (context, index) {
          return _buildTournamentCard(tournaments[index]);
        },
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Tournament';
    final status = data['status'] ?? 'open';
    final entryFee = data['entry_fee_coins'] ?? 0;
    final maxParticipants = data['max_participants'] ?? 0;
    final currentParticipants = data['current_participants'] ?? 0;
    final prizeCoins = data['prize_coins'] ?? 0;
    final format = data['format'] ?? 't20';
    final startsAt = data['starts_at'] != null
        ? DateTime.tryParse(data['starts_at'])
        : null;

    final statusColor = switch (status) {
      'in_progress' => AppTheme.success,
      'open' => AppTheme.accent,
      'completed' => Colors.white54,
      'cancelled' => Colors.redAccent,
      _ => AppTheme.primary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status == 'in_progress'
                                  ? 'LIVE'
                                  : status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            format.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          if (startsAt != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.schedule,
                                size: 12, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(startsAt),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTournamentStat(
                  'Entry Fee',
                  entryFee > 0 ? '$entryFee' : 'FREE',
                  Icons.monetization_on,
                ),
                _buildTournamentStat(
                  'Players',
                  '$currentParticipants/$maxParticipants',
                  Icons.people,
                ),
                _buildTournamentStat(
                  'Prize Pool',
                  prizeCoins > 0 ? '$prizeCoins' : 'TBD',
                  Icons.star,
                ),
              ],
            ),
          ),

          // Progress bar for participant count
          if (status == 'open')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxParticipants > 0
                      ? currentParticipants / maxParticipants
                      : 0,
                  backgroundColor: Colors.white12,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 4,
                ),
              ),
            ),

          // Action buttons
          if (status != 'cancelled')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  if (status == 'in_progress' || status == 'completed')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewTournamentDetails(data),
                        icon: const Icon(Icons.leaderboard, size: 16),
                        label: const Text('STANDINGS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: statusColor,
                          side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  if (status == 'in_progress') const SizedBox(width: 8),
                  if (status == 'open')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: currentParticipants < maxParticipants
                            ? () => _joinTournament(data)
                            : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          currentParticipants >= maxParticipants
                              ? 'FULL'
                              : 'JOIN TOURNAMENT',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (status == 'cancelled')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'CANCELLED — Not enough players. Entry fees refunded.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Starting soon...';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  Future<void> _joinTournament(Map<String, dynamic> tournament) async {
    final tournamentId = tournament['id'];
    final entryFee = tournament['entry_fee_coins'] ?? 0;
    final name = tournament['name'] ?? 'Tournament';

    // Get user's active team
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _showError('Please log in first');
      return;
    }

    final team = await SupabaseService.getActiveTeam();
    if (!mounted) return;
    if (team == null) {
      _showError('Create a team first before joining');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Join $name?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entryFee > 0) ...[
              Row(
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text('Entry fee: $entryFee coins'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Team: ${team['name'] ?? 'Your Team'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
            ),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppTheme.surface,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    try {
      final result = await NodeBackendService.joinTournament(
        tournamentId: tournamentId,
        userId: userId,
        teamId: team['id'],
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined $name!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadTournaments(); // Refresh
      } else {
        _showError(result['message'] ?? 'Failed to join');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      _showError('Failed to join tournament');
    }
  }

  Future<void> _viewTournamentDetails(Map<String, dynamic> tournament) async {
    final tournamentId = tournament['id'];
    final name = tournament['name'] ?? 'Tournament';

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppTheme.surface,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    Map<String, dynamic>? details;
    try {
      details = await NodeBackendService.getTournamentDetails(tournamentId);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      _showError('Failed to load tournament details');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (details == null) {
      _showError('Failed to load tournament details');
      return;
    }

    final participants =
        List<Map<String, dynamic>>.from(details['participants'] ?? []);
    final matches =
        List<Map<String, dynamic>>.from(details['matches'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            // Points table header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.05),
              child: const Row(
                children: [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                  Expanded(child: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                  SizedBox(width: 32, child: Text('P', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                  SizedBox(width: 32, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                  SizedBox(width: 40, child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                  SizedBox(width: 50, child: Text('NRR', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 12))),
                ],
              ),
            ),
            // Points table rows
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: participants.length + (matches.isNotEmpty ? matches.length + 1 : 0),
                itemBuilder: (context, index) {
                  if (index < participants.length) {
                    final p = participants[index];
                    final teamName = p['teams']?['team_name'] ??
                        p['users']?['display_name'] ??
                        p['users']?['username'] ??
                        'Team ${index + 1}';
                    final isTop3 = index < 3;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        color: isTop3
                            ? AppTheme.accent.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isTop3
                                    ? AppTheme.accent
                                    : Colors.white54,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              teamName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isTop3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${p['matches_played'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${p['matches_won'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${p['points'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              (p['net_run_rate'] ?? 0).toStringAsFixed(2),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: (p['net_run_rate'] ?? 0) >= 0
                                    ? AppTheme.success
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Matches section
                  final matchIndex = index - participants.length;
                  if (matchIndex == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 20, bottom: 8),
                      child: Text(
                        'MATCHES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  final match = matches[matchIndex - 1];
                  final matchStatus = match['status'] ?? 'scheduled';
                  final homeScore = match['home_score'] ?? 0;
                  final awayScore = match['away_score'] ?? 0;
                  final homeWickets = match['home_wickets'] ?? 0;
                  final awayWickets = match['away_wickets'] ?? 0;
                  final homeTeamName = match['home_team_name'] ?? 'Home';
                  final awayTeamName = match['away_team_name'] ?? 'Away';
                  final matchNum = match['match_number'] ?? matchIndex;
                  final scheduledAt = match['scheduled_at'] != null
                      ? DateTime.tryParse(match['scheduled_at'])
                      : null;
                  final matchId = match['id'] as String?;
                  final isLive = matchStatus == 'in_progress';
                  final isCompleted = matchStatus == 'completed';

                  return GestureDetector(
                    onTap: (isLive || isCompleted) && matchId != null
                        ? () {
                            Navigator.pop(context); // Close bottom sheet
                            context.push('/tournaments/match/$matchId', extra: {
                              'homeTeamName': homeTeamName,
                              'awayTeamName': awayTeamName,
                              'matchNumber': matchNum,
                              'tournamentName': name,
                            });
                          }
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLive
                            ? Colors.deepOrange.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: isLive
                            ? Border.all(color: Colors.deepOrange.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Match number + status
                          Row(
                            children: [
                              Text('Match $matchNum',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              const Spacer(),
                              if (isCompleted)
                                Text('$homeScore/$homeWickets - $awayScore/$awayWickets',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 13,
                                    ))
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLive
                                        ? Colors.deepOrange.withValues(alpha: 0.2)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLive) ...[
                                        Container(
                                          width: 5, height: 5,
                                          decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        isLive ? 'LIVE' : 'SCHEDULED',
                                        style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold,
                                          color: isLive ? Colors.deepOrange : Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Team names
                          Row(
                            children: [
                              Expanded(
                                child: Text(homeTeamName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const Text(' vs ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              Expanded(
                                child: Text(awayTeamName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                              ),
                            ],
                          ),
                          // Scheduled time or Watch button
                          if (!isCompleted) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (scheduledAt != null) ...[
                                  Icon(Icons.schedule, size: 12, color: Colors.white38),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatMatchTime(scheduledAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                                  ),
                                ],
                                const Spacer(),
                                if (isLive)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility, size: 14, color: Colors.deepOrange),
                                      SizedBox(width: 4),
                                      Text('WATCH', style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange,
                                      )),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTournamentDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final entryFeeController = TextEditingController(text: '0');
    final prizeController = TextEditingController(text: '0');
    String selectedFormat = 't20';
    int maxParticipants = 8;
    DateTime startsAt = DateTime.now().add(const Duration(hours: 24));

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CREATE TOURNAMENT',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tournament Name *',
                    hintText: 'e.g. Weekend Cup',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.emoji_events),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Format + Max Participants row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Format',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white24),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedFormat,
                                isExpanded: true,
                                dropdownColor: AppTheme.surface,
                                items: const [
                                  DropdownMenuItem(
                                      value: 't10', child: Text('T10')),
                                  DropdownMenuItem(
                                      value: 't20', child: Text('T20')),
                                  DropdownMenuItem(
                                      value: 'odi', child: Text('ODI')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(
                                        () => selectedFormat = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Players',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white24),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: maxParticipants,
                                isExpanded: true,
                                dropdownColor: AppTheme.surface,
                                items: const [
                                  DropdownMenuItem(
                                      value: 4, child: Text('4')),
                                  DropdownMenuItem(
                                      value: 6, child: Text('6')),
                                  DropdownMenuItem(
                                      value: 8, child: Text('8')),
                                  DropdownMenuItem(
                                      value: 12, child: Text('12')),
                                  DropdownMenuItem(
                                      value: 16, child: Text('16')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(
                                        () => maxParticipants = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Entry Fee + Prize row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entryFeeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Entry Fee',
                          suffixText: 'coins',
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon:
                              const Icon(Icons.monetization_on, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: prizeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Prize Pool',
                          suffixText: 'coins',
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.star, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Start Time
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: startsAt,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date == null) return;
                    if (!ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(startsAt),
                    );
                    if (time == null) return;
                    setModalState(() {
                      startsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: AppTheme.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Starts At',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12)),
                              Text(
                                '${startsAt.day}/${startsAt.month}/${startsAt.year} at ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Create button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please enter a tournament name')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('CREATE TOURNAMENT',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppTheme.surface,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    try {
      final response = await NodeBackendService.createTournament(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        format: selectedFormat,
        maxParticipants: maxParticipants,
        entryFeeCoins: int.tryParse(entryFeeController.text) ?? 0,
        prizeCoins: int.tryParse(prizeController.text) ?? 0,
        startsAt: startsAt.toUtc().toIso8601String(),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament created!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadTournaments();
      } else {
        _showError(response['message'] ?? 'Failed to create tournament');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      _showError('Failed to create tournament');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatMatchTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Starting soon...';
    if (diff.inMinutes < 1) return 'In < 1 min';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}
