import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/profanity_filter.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class SquadBuilderScreen extends ConsumerStatefulWidget {
  const SquadBuilderScreen({super.key});

  @override
  ConsumerState<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends ConsumerState<SquadBuilderScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _teamNameController = TextEditingController();
  late final TabController _tabController;
  StatsSortField _sortField = StatsSortField.runs;

  static const Map<int, String> _xiSlotLabels = {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);
    final chemistry = ref.watch(chemistryProvider);
    ref.watch(userCardsProvider);

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
            Tab(text: 'STATS'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _chemistryColor(chemistry).withValues(alpha: 0.15),
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
        error: (error, _) => _buildError(error),
        data: (team) {
          if (team == null) return _buildCreateTeam();
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPlayingXI(team),
              _buildStatsTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $error', style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(teamProvider.notifier).refresh(),
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTeam() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 72, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Create Your Team',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _teamNameController,
              decoration: const InputDecoration(
                hintText: 'Team Name',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: ProfanityFilter.validateTeamNameSync,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                final name = _teamNameController.text.trim();
                final error = await ProfanityFilter.validateTeamName(name);
                if (error != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                  return;
                }
                if (name.isNotEmpty) {
                  await ref.read(teamProvider.notifier).createTeam(name);
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

  Widget _buildPlayingXI(Team team) {
    final squad = team.activeSquad;
    if (squad == null) {
      return const Center(
        child: Text(
          'No active squad found',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final lineup = squad.playingXI;
    final bench = squad.players.where((p) => !p.isPlayingXI).toList()
      ..sort((a, b) {
        final ar = a.userCard?.playerCard?.rating ?? 0;
        final br = b.userCard?.playerCard?.rating ?? 0;
        return br.compareTo(ar);
      });

    final roleCounts = <String, int>{};
    for (final player in lineup) {
      final role = player.userCard?.playerCard?.role ?? 'unknown';
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }

    final avgRating = lineup.isEmpty
        ? 0
        : lineup.fold<int>(0, (sum, p) => sum + (p.userCard?.playerCard?.rating ?? 0)) ~/
            lineup.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildTeamSummaryCard(team, lineup.length, avgRating),
        const SizedBox(height: 10),
        if (lineup.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _roleChip('BAT', roleCounts['batsman'] ?? 0, Colors.blueAccent),
              _roleChip('BOWL', roleCounts['bowler'] ?? 0, Colors.redAccent),
              _roleChip('ALL', roleCounts['all_rounder'] ?? 0, Colors.orangeAccent),
              _roleChip('WK', roleCounts['wicket_keeper'] ?? 0, Colors.tealAccent),
            ],
          ),
        const SizedBox(height: 10),
        const Text(
          'Batting Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Drag players to reorder your XI lineup.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (lineup.isEmpty)
          _buildEmptyLineupState(squad)
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lineup.length,
            proxyDecorator: (child, _, __) => Material(
              color: Colors.transparent,
              elevation: 4,
              child: child,
            ),
            onReorder: (oldIndex, newIndex) {
              ref.read(teamProvider.notifier).reorderPlayingXI(
                    lineup,
                    oldIndex,
                    newIndex,
                  );
            },
            itemBuilder: (context, index) {
              final player = lineup[index];
              return _buildLineupTile(
                player,
                battingOrder: index + 1,
                key: ValueKey(player.id),
              );
            },
          ),
        if (lineup.length < 11) ...[
          const SizedBox(height: 10),
          ...List.generate(
            11 - lineup.length,
            (index) {
              final battingSlot = lineup.length + index + 1;
              return _buildEmptyLineupSlot(
                battingSlot,
                squad,
                key: ValueKey('empty_$battingSlot'),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Bench',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              '${bench.length} players',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (bench.isEmpty)
          _buildEmptyBenchCard(squad)
        else
          ...bench.map((player) => _buildBenchTile(player, squad)),
      ],
    );
  }

  Widget _buildTeamSummaryCard(Team team, int xiCount, int avgRating) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.35),
            AppTheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: AppTheme.accent, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'OVR $avgRating • $xiCount/11 selected',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: xiCount == 11
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : AppTheme.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              xiCount == 11 ? 'READY' : '${11 - xiCount} NEEDED',
              style: TextStyle(
                color: xiCount == 11 ? AppTheme.accent : AppTheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLineupState(Squad squad) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.sports_cricket, size: 34, color: Colors.white24),
          const SizedBox(height: 8),
          const Text(
            'No players in Playing XI yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your first player to start building your lineup.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              final freePos = _nextAvailableXiPosition(squad);
              if (freePos != null) {
                _showAddPlayerSheet(freePos);
              }
            },
            icon: const Icon(Icons.person_add),
            label: const Text('ADD TO XI'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineupTile(
    SquadPlayer player, {
    required int battingOrder,
    Key? key,
  }) {
    final card = player.userCard?.playerCard;
    if (card == null) {
      return SizedBox(key: key);
    }

    final rarityColor = AppTheme.getRarityColor(card.rarity);
    final slotLabel = _xiSlotLabels[battingOrder] ?? 'Slot $battingOrder';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: player.isCaptain
              ? AppTheme.accent
              : player.isViceCaptain
                  ? Colors.blueAccent
                  : rarityColor.withValues(alpha: 0.35),
          width: (player.isCaptain || player.isViceCaptain) ? 2 : 1,
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
                  fontSize: 15,
                ),
              ),
              Text(
                card.roleDisplay,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$battingOrder',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                card.playerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (player.isCaptain)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'C',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            if (player.isViceCaptain)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$slotLabel • ${card.countryCode} • BAT ${card.batting} BOWL ${card.bowling}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.white54),
              color: AppTheme.surfaceLight,
              onSelected: (value) => _handleLineupAction(value, player),
              itemBuilder: (_) => [
                if (!player.isCaptain)
                  const PopupMenuItem(value: 'captain', child: Text('Set Captain')),
                if (!player.isViceCaptain)
                  const PopupMenuItem(
                    value: 'vice_captain',
                    child: Text('Set Vice Captain'),
                  ),
                const PopupMenuItem(
                  value: 'remove_xi',
                  child: Text('Remove from XI'),
                ),
                const PopupMenuItem(
                  value: 'remove_squad',
                  child: Text(
                    'Remove from Squad',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ),
            const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLineupSlot(int battingSlot, Squad squad, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1, color: Colors.white24),
        title: Text(
          'Batting Slot #$battingSlot',
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _xiSlotLabels[battingSlot] ?? 'Add a player',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: const Icon(Icons.add, color: Colors.white54),
        onTap: () {
          final freePos = _nextAvailableXiPosition(squad);
          if (freePos == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playing XI is full (11/11)')),
            );
            return;
          }
          _showAddPlayerSheet(freePos);
        },
      ),
    );
  }

  Widget _buildEmptyBenchCard(Squad squad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'No bench players',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap below to add players directly to your XI.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              final freePos = _nextAvailableXiPosition(squad);
              if (freePos != null) {
                _showAddPlayerSheet(freePos);
              }
            },
            icon: const Icon(Icons.person_add),
            label: const Text('ADD PLAYER'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchTile(SquadPlayer player, Squad squad) {
    final card = player.userCard?.playerCard;
    if (card == null) return const SizedBox();

    final rarityColor = AppTheme.getRarityColor(card.rarity);
    final notifier = ref.read(teamProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarityColor.withValues(alpha: 0.25)),
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
                '${card.rating}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                card.roleDisplay,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          card.playerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${card.countryCode} • BAT ${card.batting} BOWL ${card.bowling}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Add to XI',
              icon: const Icon(Icons.playlist_add_check, color: AppTheme.accent),
              onPressed: () {
                final freePos = _nextAvailableXiPosition(squad);
                if (freePos == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playing XI is full (11/11)')),
                  );
                  return;
                }
                notifier.addPlayerToSquad(
                  squad.id,
                  player.userCardId,
                  freePos,
                  isPlayingXI: true,
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.white54),
              color: AppTheme.surfaceLight,
              onSelected: (value) {
                if (value == 'remove_squad') {
                  notifier.removePlayerFromSquad(player.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove_squad',
                  child: Text(
                    'Remove from Squad',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  int? _nextAvailableXiPosition(Squad squad) {
    final usedPositions = squad.players
        .where((p) => p.isPlayingXI)
        .map((p) => p.position)
        .toSet();
    for (int i = 1; i <= 11; i++) {
      if (!usedPositions.contains(i)) {
        return i;
      }
    }
    return null;
  }

  void _handleLineupAction(String action, SquadPlayer player) {
    final notifier = ref.read(teamProvider.notifier);
    switch (action) {
      case 'captain':
        notifier.setCaptain(player.id);
        break;
      case 'vice_captain':
        notifier.setViceCaptain(player.id);
        break;
      case 'remove_xi':
        notifier.setPlayingXI(player.id, false);
        break;
      case 'remove_squad':
        notifier.removePlayerFromSquad(player.id);
        break;
    }
  }

  void _showAddPlayerSheet(int position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        String? selectedRole;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allCards = ref.read(userCardsProvider).valueOrNull ?? [];
            final team = ref.read(teamProvider).valueOrNull;
            final squad = team?.activeSquad;

            final xiPlayers = squad?.players.where((p) => p.isPlayingXI) ?? [];
            final assignedUserCardIds = xiPlayers.map((p) => p.userCardId).toSet();
            final assignedPlayerCardIds = xiPlayers
                .where((p) => p.userCard?.playerCard != null)
                .map((p) => p.userCard!.cardId)
                .toSet();

            var availableCards = allCards.where((card) {
              if (assignedUserCardIds.contains(card.id)) return false;
              if (assignedPlayerCardIds.contains(card.cardId)) return false;
              return true;
            }).toList()
              ..sort((a, b) {
                final ar = a.playerCard?.rating ?? 0;
                final br = b.playerCard?.rating ?? 0;
                return br.compareTo(ar);
              });

            if (selectedRole != null) {
              availableCards = availableCards
                  .where((card) => card.playerCard?.role == selectedRole)
                  .toList();
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    _buildSheetHandle(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'SELECT PLAYER — XI SLOT $position',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                    if (availableCards.isEmpty)
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
                          itemCount: availableCards.length,
                          itemBuilder: (_, index) {
                            final userCard = availableCards[index];
                            final card = userCard.playerCard;
                            if (card == null) return const SizedBox();

                            final rarityColor = AppTheme.getRarityColor(card.rarity);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        rarityColor,
                                        rarityColor.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${card.rating}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        card.roleDisplay,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  card.playerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      card.countryCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'BAT ${card.batting}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'BOWL ${card.bowling}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  card.rarity.toUpperCase(),
                                  style: TextStyle(
                                    color: rarityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () {
                                  final activeTeam = ref.read(teamProvider).valueOrNull;
                                  final activeSquad = activeTeam?.activeSquad;
                                  if (activeSquad != null) {
                                    ref.read(teamProvider.notifier).addPlayerToSquad(
                                          activeSquad.id,
                                          userCard.id,
                                          position,
                                          isPlayingXI: position <= 11,
                                        );
                                  }
                                  Navigator.of(bottomSheetContext).pop();
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

  Widget _filterChip(
    String label,
    String? role,
    String? selectedRole,
    ValueChanged<String?> onTap,
  ) {
    final isSelected = selectedRole == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onTap(role),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.2)
                : AppTheme.surfaceLight,
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

  Widget _buildStatsTab() {
    final stats = ref.watch(careerStatsProvider(_sortField));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: AppTheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'SORT BY  ',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _sortChip('Runs', StatsSortField.runs),
                _sortChip('Wickets', StatsSortField.wickets),
                _sortChip('4s', StatsSortField.fours),
                _sortChip('6s', StatsSortField.sixes),
                _sortChip('Catches', StatsSortField.catches),
                _sortChip('Matches', StatsSortField.matches),
              ],
            ),
          ),
        ),
        if (stats.isEmpty)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No match stats yet.\nPlay some matches to see player performance!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: stats.length,
              itemBuilder: (_, index) => _buildStatRow(stats[index], index + 1),
            ),
          ),
      ],
    );
  }

  Widget _sortChip(String label, StatsSortField field) {
    final isSelected = _sortField == field;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _sortField = field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
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

  Widget _buildStatRow(PlayerCareerStats stats, int rank) {
    String primaryValue;
    switch (_sortField) {
      case StatsSortField.runs:
        primaryValue = '${stats.runs} runs';
        break;
      case StatsSortField.wickets:
        primaryValue = '${stats.wickets} wkts';
        break;
      case StatsSortField.fours:
        primaryValue = '${stats.fours} fours';
        break;
      case StatsSortField.sixes:
        primaryValue = '${stats.sixes} sixes';
        break;
      case StatsSortField.catches:
        primaryValue = '${stats.catches} catches';
        break;
      case StatsSortField.matches:
        primaryValue = '${stats.matches} matches';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: rank <= 3 ? AppTheme.accent : Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stats.playerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  primaryValue,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _miniStat('M', '${stats.matches}', Colors.white70),
              _miniStat('R', '${stats.runs}', Colors.blueAccent),
              _miniStat('HS', '${stats.highScore}', Colors.lightBlueAccent),
              _miniStat('4s', '${stats.fours}', Colors.orangeAccent),
              _miniStat('6s', '${stats.sixes}', Colors.purpleAccent),
              _miniStat('W', '${stats.wickets}', Colors.redAccent),
              _miniStat('CT', '${stats.catches}', Colors.tealAccent),
              if (stats.ballsFaced > 0)
                _miniStat('SR', stats.strikeRate.toStringAsFixed(1), Colors.white54),
              if (stats.ballsBowled > 0)
                _miniStat('ECO', stats.bowlingEconomy.toStringAsFixed(1), Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
}
