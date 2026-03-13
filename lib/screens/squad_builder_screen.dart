import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../models/models.dart';

class SquadBuilderScreen extends ConsumerStatefulWidget {
  const SquadBuilderScreen({super.key});

  @override
  ConsumerState<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends ConsumerState<SquadBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _teamNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);
    final chemistry = ref.watch(chemistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SQUAD BUILDER'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'PLAYING XI'),
            Tab(text: 'SQUAD'),
            Tab(text: 'TACTICS'),
          ],
        ),
        actions: [
          // Chemistry indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _chemistryColor(chemistry).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _chemistryColor(chemistry)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: _chemistryColor(chemistry)),
                const SizedBox(width: 4),
                Text(
                  '$chemistry',
                  style: TextStyle(
                    color: _chemistryColor(chemistry),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(teamProvider.notifier).refresh(),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
        data: (team) {
          if (team == null) {
            return _buildCreateTeam();
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPlayingXI(team),
              _buildFullSquad(team),
              _buildTactics(team),
            ],
          );
        },
      ),
    );
  }

  Color _chemistryColor(int chemistry) {
    if (chemistry >= 80) return AppTheme.cardLegend;
    if (chemistry >= 60) return AppTheme.cardGold;
    if (chemistry >= 40) return AppTheme.primaryLight;
    if (chemistry >= 20) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }

  // ─── Create Team ─────────────────────────────────────────────────────────

  Widget _buildCreateTeam() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Create Your Team',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _teamNameController,
              decoration: const InputDecoration(
                hintText: 'Team Name',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final name = _teamNameController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(teamProvider.notifier).createTeam(name);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('CREATE TEAM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Playing XI Tab ──────────────────────────────────────────────────────

  // Role-based position labels for cricket
  static const _positionLabels = <int, String>{
    1: 'Opener',
    2: 'Opener',
    3: 'No. 3',
    4: 'No. 4',
    5: 'No. 5',
    6: 'Wicket Keeper',
    7: 'All-Rounder',
    8: 'All-Rounder',
    9: 'Bowler',
    10: 'Bowler',
    11: 'Bowler',
  };

  Widget _buildPlayingXI(Team team) {
    final squad = team.activeSquad;
    if (squad == null) {
      return const Center(
        child: Text('No active squad found', style: TextStyle(color: Colors.white38)),
      );
    }

    final xi = squad.playingXI;
    // Build a map of position -> SquadPlayer for positions 1-11
    final Map<int, SquadPlayer> positionMap = {};
    for (final sp in squad.players.where((p) => p.isPlayingXI)) {
      positionMap[sp.position] = sp;
    }

    // Count roles
    final roleCount = <String, int>{};
    for (final sp in xi) {
      final role = sp.userCard?.playerCard?.role ?? 'unknown';
      roleCount[role] = (roleCount[role] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary.withValues(alpha: 0.4), AppTheme.surface],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: AppTheme.accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.teamName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OVR ${team.overallRating} | ${xi.length}/11 selected',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              if (xi.length == 11)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('READY', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${11 - xi.length} NEEDED', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Role breakdown chips
        if (xi.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                _roleChip('BAT', roleCount['batsman'] ?? 0, Colors.blueAccent),
                _roleChip('BOWL', roleCount['bowler'] ?? 0, Colors.redAccent),
                _roleChip('ALL', roleCount['all_rounder'] ?? 0, Colors.orangeAccent),
                _roleChip('WK', roleCount['wicket_keeper'] ?? 0, Colors.tealAccent),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Render all 11 positions — filled or empty
        ...List.generate(11, (i) {
          final pos = i + 1;
          final sp = positionMap[pos];
          if (sp != null) {
            return _buildSquadPlayerTile(sp, isXI: true);
          }
          return _buildEmptySlot(pos, label: _positionLabels[pos]);
        }),
      ],
    );
  }

  Widget _roleChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Player Tile ─────────────────────────────────────────────────────────

  Widget _buildSquadPlayerTile(SquadPlayer sp, {bool isXI = false, bool showAddToXI = false}) {
    final card = sp.userCard?.playerCard;
    if (card == null) return const SizedBox();

    final rarityColor = AppTheme.getRarityColor(card.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sp.isCaptain
              ? AppTheme.accent
              : sp.isViceCaptain
                  ? Colors.blueAccent
                  : rarityColor.withValues(alpha: 0.3),
          width: (sp.isCaptain || sp.isViceCaptain) ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [rarityColor, rarityColor.withValues(alpha: 0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${card.rating}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                card.roleDisplay,
                style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                card.playerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sp.isCaptain)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('C', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            if (sp.isViceCaptain) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('VC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text(card.countryCode, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            Text(
              'BAT ${card.batting}',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
            ),
            const SizedBox(width: 6),
            Text(
              'BOWL ${card.bowling}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: AppTheme.surfaceLight,
          onSelected: (value) => _handlePlayerAction(value, sp),
          itemBuilder: (context) => [
            if (isXI && !sp.isCaptain)
              const PopupMenuItem(value: 'captain', child: Text('Set Captain')),
            if (isXI && !sp.isViceCaptain)
              const PopupMenuItem(value: 'vice_captain', child: Text('Set Vice Captain')),
            if (!isXI && !sp.isPlayingXI)
              const PopupMenuItem(value: 'add_xi', child: Text('Add to Playing XI')),
            if (isXI)
              const PopupMenuItem(value: 'remove_xi', child: Text('Remove from XI')),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove from Squad', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlayerAction(String value, SquadPlayer sp) {
    final notifier = ref.read(teamProvider.notifier);
    switch (value) {
      case 'captain':
        notifier.setCaptain(sp.id);
        break;
      case 'vice_captain':
        notifier.setViceCaptain(sp.id);
        break;
      case 'add_xi':
        // Find next available XI position
        final team = ref.read(teamProvider).valueOrNull;
        final squad = team?.activeSquad;
        if (squad == null) return;
        final usedPositions = squad.players
            .where((p) => p.isPlayingXI)
            .map((p) => p.position)
            .toSet();
        int? freePos;
        for (int i = 1; i <= 11; i++) {
          if (!usedPositions.contains(i)) {
            freePos = i;
            break;
          }
        }
        if (freePos != null) {
          notifier.addPlayerToSquad(squad.id, sp.userCardId, freePos, isPlayingXI: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playing XI is full (11/11)')),
          );
        }
        break;
      case 'remove_xi':
        notifier.setPlayingXI(sp.id, false);
        break;
      case 'remove':
        notifier.removePlayerFromSquad(sp.id);
        break;
    }
  }

  // ─── Empty Slot ──────────────────────────────────────────────────────────

  Widget _buildEmptySlot(int position, {String? label}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, style: BorderStyle.solid),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white10,
          ),
          child: const Icon(Icons.person_add, color: Colors.white24, size: 22),
        ),
        title: Text(
          label ?? 'Position $position',
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
        subtitle: Text(
          'Tap to add player  •  Slot $position',
          style: const TextStyle(color: Colors.white24, fontSize: 11),
        ),
        onTap: () => _showAddPlayerSheet(position),
      ),
    );
  }

  // ─── Add Player Sheet ────────────────────────────────────────────────────

  void _showAddPlayerSheet(int position, {String? filterRole}) {
    final allCards = ref.read(userCardsProvider).valueOrNull ?? [];
    final team = ref.read(teamProvider).valueOrNull;
    final squad = team?.activeSquad;
    // Filter out cards already assigned to the squad
    final assignedCardIds = squad?.players.map((p) => p.userCardId).toSet() ?? {};
    var cards = allCards.where((c) => !assignedCardIds.contains(c.id)).toList();
    // Sort by rating descending
    cards.sort((a, b) => (b.playerCard?.rating ?? 0).compareTo(a.playerCard?.rating ?? 0));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selectedRole = filterRole;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            var filtered = cards.toList();
            if (selectedRole != null) {
              filtered = filtered.where((c) => c.playerCard?.role == selectedRole).toList();
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    _buildSheetHandle(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'SELECT PLAYER — Slot $position',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Role filters
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('All', null, selectedRole, (role) {
                                  setSheetState(() => selectedRole = role);
                                }),
                                _filterChip('BAT', 'batsman', selectedRole, (role) {
                                  setSheetState(() => selectedRole = role);
                                }),
                                _filterChip('BOWL', 'bowler', selectedRole, (role) {
                                  setSheetState(() => selectedRole = role);
                                }),
                                _filterChip('ALL', 'all_rounder', selectedRole, (role) {
                                  setSheetState(() => selectedRole = role);
                                }),
                                _filterChip('WK', 'wicket_keeper', selectedRole, (role) {
                                  setSheetState(() => selectedRole = role);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No available cards\nOpen some packs first!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final card = filtered[index];
                            if (card.playerCard == null) return const SizedBox();
                            final pc = card.playerCard!;
                            final rarityColor = AppTheme.getRarityColor(pc.rarity);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: rarityColor.withValues(alpha: 0.2)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [rarityColor, rarityColor.withValues(alpha: 0.5)],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${pc.rating}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                      ),
                                      Text(
                                        pc.roleDisplay,
                                        style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                title: Text(pc.playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Row(
                                  children: [
                                    Text(pc.countryCode, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                    const SizedBox(width: 8),
                                    Text('BAT ${pc.batting}', style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                                    const SizedBox(width: 6),
                                    Text('BOWL ${pc.bowling}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                                    const SizedBox(width: 6),
                                    Text('FLD ${pc.fielding}', style: const TextStyle(fontSize: 11, color: Colors.tealAccent)),
                                  ],
                                ),
                                trailing: Text(
                                  pc.rarity.toUpperCase(),
                                  style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                onTap: () {
                                  final team = ref.read(teamProvider).valueOrNull;
                                  final squad = team?.activeSquad;
                                  if (squad != null) {
                                    ref.read(teamProvider.notifier).addPlayerToSquad(
                                      squad.id,
                                      card.id,
                                      position,
                                      isPlayingXI: position <= 11,
                                    );
                                  }
                                  Navigator.pop(ctx);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, String? role, String? selectedRole, ValueChanged<String?> onTap) {
    final isSelected = selectedRole == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onTap(role),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.accent : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.accent : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ─── Full Squad Tab ──────────────────────────────────────────────────────

  Widget _buildFullSquad(Team team) {
    final squad = team.activeSquad;
    if (squad == null) {
      return const Center(child: Text('No squad', style: TextStyle(color: Colors.white38)));
    }

    final squadPlayers = squad.players.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final xiPlayers = squadPlayers.where((p) => p.isPlayingXI).toList();
    final benchPlayers = squadPlayers.where((p) => !p.isPlayingXI).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _squadStat('Total', '${squad.players.length}'),
              _squadStat('In XI', '${xiPlayers.length}'),
              _squadStat('Bench', '${benchPlayers.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Playing XI section
        if (xiPlayers.isNotEmpty) ...[
          _sectionHeader('PLAYING XI', xiPlayers.length),
          const SizedBox(height: 8),
          ...xiPlayers.map((sp) => _buildSquadPlayerTile(sp, isXI: true)),
          const SizedBox(height: 16),
        ],

        // Bench section
        if (benchPlayers.isNotEmpty) ...[
          _sectionHeader('BENCH', benchPlayers.length),
          const SizedBox(height: 8),
          ...benchPlayers.map((sp) => _buildSquadPlayerTile(sp, showAddToXI: true)),
          const SizedBox(height: 16),
        ],

        // Add player button
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              // Find next free position for squad (not XI)
              final usedPositions = squad.players.map((p) => p.position).toSet();
              int freePos = 12;
              for (int i = 12; i <= 30; i++) {
                if (!usedPositions.contains(i)) {
                  freePos = i;
                  break;
                }
              }
              _showAddPlayerSheet(freePos);
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('ADD TO SQUAD'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _squadStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white54),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─── Tactics Tab ─────────────────────────────────────────────────────────

  Widget _buildTactics(Team team) {
    final squad = team.activeSquad;
    if (squad == null) return const Center(child: Text('No squad'));

    final xi = squad.playingXI;
    final bowlers = squad.bowlers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Batting order section
        const Text(
          'BATTING ORDER',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        const Text(
          'Drag to reorder batting positions',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),

        if (xi.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Add players to your Playing XI to set batting order',
              style: TextStyle(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: xi.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              // Update batting orders for all players in the new order
              final reordered = List<SquadPlayer>.from(xi);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              for (int i = 0; i < reordered.length; i++) {
                ref.read(teamProvider.notifier).setBattingOrder(reordered[i].id, i + 1);
              }
            },
            itemBuilder: (context, index) {
              final sp = xi[index];
              return _buildBattingOrderTile(sp, index + 1, key: ValueKey(sp.id));
            },
          ),

        const SizedBox(height: 24),

        // Bowling section
        const Text(
          'BOWLERS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        const Text(
          'All-rounders and bowlers in your XI',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),

        if (bowlers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No bowlers in your Playing XI!',
              style: TextStyle(color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...bowlers.map((sp) {
            final card = sp.userCard?.playerCard;
            if (card == null) return const SizedBox();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Text(
                        '${card.bowling}',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${card.roleDisplay} | Pace ${card.pace} | Spin ${card.spin}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBattingOrderTile(SquadPlayer sp, int order, {Key? key}) {
    final card = sp.userCard?.playerCard;
    if (card == null) return SizedBox(key: key);

    final rarityColor = AppTheme.getRarityColor(card.rarity);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '$order',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: rarityColor.withValues(alpha: 0.3),
            ),
            child: Center(
              child: Text(
                '${card.rating}',
                style: TextStyle(color: rarityColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(card.playerName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          Text(card.roleDisplay, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}
