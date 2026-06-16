import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/logger.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../core/notification_service.dart';
import '../providers/match/tournament_match_manager.dart';
import '../providers/auth_provider.dart';
import '../providers/card_packs_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/contracts_provider.dart';
import '../widgets/tournament_match_widgets.dart';

class TournamentMatchScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String? homeTeamName;
  final String? awayTeamName;
  final int? matchNumber;
  final String? tournamentName;

  const TournamentMatchScreen({
    super.key, required this.matchId, this.homeTeamName, this.awayTeamName,
    this.matchNumber, this.tournamentName,
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
  late MatchSocketManager _manager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _manager = MatchSocketManager(
      matchId: widget.matchId,
      onStateChanged: () { if (mounted) setState(() {}); },
      onMatchCompleted: _handleMatchComplete,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manager.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _manager.loadAndConnect(
      homeTeamName: widget.homeTeamName,
      awayTeamName: widget.awayTeamName,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleMatchComplete(Map<String, dynamic> data) {
    final s = _manager.state;
    final result = s.matchResult ?? 'Match completed';
    final userWon = result.toLowerCase().contains(s.homeTeamName.toLowerCase());
    final isDraw = result.toLowerCase().contains('tie') ||
        result.toLowerCase().contains('draw');
    final coins = userWon
        ? AppConstants.matchWinCoins
        : (isDraw ? AppConstants.matchDrawCoins : AppConstants.matchLoseCoins);
    final xp = userWon ? AppConstants.matchWinXP : AppConstants.matchPlayXP;

    final userNotifier = ref.read(currentUserProvider.notifier);
    final oldUser = ref.read(currentUserProvider).valueOrNull;
    final oldLevel = oldUser?.level ?? 1;
    userNotifier.updateCoins(coins);
    userNotifier.updateXpAndLevel(xp);
    userNotifier.updateMatchStats(won: userWon);
    final updatedUser = ref.read(currentUserProvider).valueOrNull;
    final newLevel = updatedUser?.level ?? oldLevel;

    String? levelUpPack;
    if (newLevel > oldLevel) {
      levelUpPack = AppConstants.packNameForLevel(newLevel);
    }

    // Determine contract pack for tournament matches
    final contractPackName = AppConstants.contractPackForDifficulty(
      'tournament',
      won: userWon,
      isMultiplayer: false,
      isRanked: false,
    );

    _persistRewards(coins, xp, userWon);
    _consumeTournamentContracts();

    NotificationService.instance.showMatchResult(
      title: 'Tournament Match ${userWon ? 'Victory!' : isDraw ? 'Draw' : 'Defeat'}',
      body: '$result — +$coins coins, +$xp XP',
    );

    s.coinsAwarded = coins;
    s.xpAwarded = xp;
    s.levelUpPackAwarded = levelUpPack;
    s.newLevel = newLevel > oldLevel ? newLevel : null;
    s.contractPackAwarded = contractPackName.isNotEmpty ? contractPackName : null;
  }

  /// Consume contracts for the user's XI in a tournament match.
  Future<void> _consumeTournamentContracts() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      // Get match data to find the user's team
      final matchData = await SupabaseService.client
          .from('matches')
          .select('home_user_id, home_team_id, away_user_id, away_team_id')
          .eq('id', widget.matchId)
          .single();

      final isHome = matchData['home_user_id'] == userId;
      final teamId = isHome ? matchData['home_team_id'] : matchData['away_team_id'];
      if (teamId == null) return;

      // Get the active squad for this team
      final squadData = await SupabaseService.client
          .from('squads')
          .select('id')
          .eq('team_id', teamId)
          .eq('is_active', true)
          .maybeSingle();

      if (squadData == null) return;

      // Get the lineup players for this squad
      final lineupData = await SupabaseService.client
          .from('lineup_players')
          .select('user_card_id')
          .eq('squad_id', squadData['id'])
          .order('batting_order');

      final userXiCardIds = lineupData.map<String>((e) => e['user_card_id'] as String).toList();
      if (userXiCardIds.isEmpty) return;

      await SupabaseService.client.rpc(
        'consume_contracts_on_match_completion',
        params: {
          'p_user_id': userId,
          'p_match_id': widget.matchId,
          'p_user_card_ids': userXiCardIds,
          'p_idempotency_key': 'tournament_contracts_${widget.matchId}_$userId',
        },
      );

      // Refresh user cards to get updated contracts_remaining
      ref.read(userCardsProvider.notifier).refresh();
    } catch (e) {
      Log.e('TournamentMatch: failed to consume contracts', e);
    }
  }

  Future<void> _persistRewards(int coins, int xp, bool? won) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    
    // Determine contract pack for tournament matches
    final contractPackName = AppConstants.contractPackForDifficulty(
      'tournament',
      won: won,
      isMultiplayer: false,
      isRanked: false,
    );
    
    try {
      await SupabaseService.client.rpc('award_match_rewards', params: {
        'p_user_id': userId,
        'p_coins': coins,
        'p_xp': xp,
        'p_won': won ?? false,
        'p_contract_pack_name': contractPackName.isNotEmpty ? contractPackName : null,
        'p_is_multiplayer': false,
        'p_is_ranked': false,
      });
    } catch (e) {
      Log.w('TournamentMatch: RPC award_match_rewards failed, trying fallback');
      try {
        final data = await SupabaseService.getCurrentUser();
        if (data == null) return;
        final oldDbLevel =
            ((data['xp'] as int? ?? 0) ~/ AppConstants.xpPerLevel) + 1;
        final newXp = (data['xp'] as int? ?? 0) + xp;
        final newDbLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
        await SupabaseService.client.from('users').update({
          'coins': (data['coins'] as int? ?? 0) + coins,
          'xp': newXp,
          'level': newDbLevel.clamp(1, AppConstants.maxLevel),
          'matches_played': (data['matches_played'] as int? ?? 0) + 1,
          if (won == true) 'matches_won': (data['matches_won'] as int? ?? 0) + 1,
        }).eq('id', userId);
        
        // Fallback: manually grant contract pack if earned
        if (contractPackName.isNotEmpty) {
          final probs = AppConstants.contractPackProbabilities[contractPackName];
          if (probs != null) {
            await SupabaseService.client.from('user_contract_packs').insert({
              'user_id': userId,
              'pack_name': contractPackName,
              'contract_count': 4,
              'bronze_chance': (probs['bronze']! * 100),
              'silver_chance': (probs['silver']! * 100),
              'gold_chance': (probs['gold']! * 100),
              'elite_chance': (probs['elite']! * 100),
              'legend_chance': (probs['legend']! * 100),
              'source': 'reward',
              'opened': false,
            });
          }
        }
        
        try {
          await SupabaseService.grantLevelUpPack(userId, oldDbLevel, newDbLevel);
        } catch (e) {
          Log.w('TournamentMatch: Level-up pack grant failed');
        }
      } catch (e) {
        Log.e('TournamentMatch: Fallback reward persistence failed', e);
      }
    }
    await Future.delayed(const Duration(milliseconds: 800));
    ref.read(currentUserProvider.notifier).silentRefresh();
    ref.read(userCardPacksProvider.notifier).refresh();
    ref.read(userContractPacksProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = _manager.state;
    final title = widget.matchNumber != null
        ? 'MATCH ${widget.matchNumber}' : 'TOURNAMENT MATCH';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (s.error != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 16),
              Text(s.error!, style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('BACK')),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          if (widget.tournamentName != null)
            Text(widget.tournamentName!,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        bottom: TabBar(
          controller: _tabController, indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent, unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'LIVE'), Tab(text: 'SCORECARD')],
        ),
      ),
      body: Column(
        children: [
          ScoreboardWidget(
            s: s, currentInnings: s.currentInnings,
            isMatchComplete: s.isMatchComplete,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildLiveTab(), ScorecardTab(s: s)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    final s = _manager.state;
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.surfaceLight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              s.currentCommentary ??
                  (s.isSimulating ? 'Match in progress...'
                      : (s.isMatchComplete
                          ? (s.matchResult ?? 'Match completed')
                          : 'Waiting for match to start...')),
              key: ValueKey('${s.commentaryLog.length}_${s.currentCommentary ?? ''}'),
              style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w500, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (s.homeBatsman.isNotEmpty || s.awayBatsman.isNotEmpty)
          BatsmanPanel(s: s),
        if (s.currentBowler.isNotEmpty) BowlerPanel(s: s),
        Expanded(child: CommentaryTimeline(s: s)),
        if (s.isMatchComplete && s.matchResult != null) _buildResultPanel(s),
      ],
    );
  }

  Widget _buildResultPanel(TournamentMatchState s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppTheme.accent.withValues(alpha: 0.15),
      child: Column(
        children: [
          Text(s.matchResult!,
              style: const TextStyle(color: AppTheme.accent,
                  fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center),
          if (s.coinsAwarded > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: AppTheme.cardGold, size: 18),
                const SizedBox(width: 4),
                Text('+${s.coinsAwarded}', style: const TextStyle(
                    color: AppTheme.cardGold, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                const Icon(Icons.star, color: AppTheme.primaryLight, size: 18),
                const SizedBox(width: 4),
                Text('+${s.xpAwarded} XP', style: const TextStyle(
                    color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (s.levelUpPackAwarded != null) ...[
            const SizedBox(height: 8),
            Text('LEVEL UP! → Level ${s.newLevel} — ${s.levelUpPackAwarded} earned!',
                style: const TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
          if (s.contractPackAwarded != null && s.contractPackAwarded!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('CONTRACT PACK EARNED! — ${s.contractPackAwarded}',
                style: const TextStyle(
                    color: AppTheme.cardGold, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
