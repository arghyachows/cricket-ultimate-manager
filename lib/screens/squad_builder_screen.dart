import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/player_card_widget.dart';

class SquadBuilderScreen extends ConsumerStatefulWidget {
  const SquadBuilderScreen({super.key});

  @override
  ConsumerState<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends ConsumerState<SquadBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          tabs: const [
            Tab(text: 'PLAYING XI'),
            Tab(text: 'FULL SQUAD'),
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
        error: (e, _) => Center(child: Text('Error: $e')),
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

  Widget _buildCreateTeam() {
    final nameController = TextEditingController();
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
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Team Name',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref.read(teamProvider.notifier).createTeam(nameController.text);
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
    if (squad == null) return const Center(child: Text('No active squad'));

    final xi = squad.playingXI;
    // Build a map of position -> SquadPlayer for positions 1-11
    final Map<int, SquadPlayer> positionMap = {};
    for (final sp in squad.players.where((p) => p.isPlayingXI)) {
      positionMap[sp.position] = sp;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'OVR ${team.overallRating} | ${xi.length}/11 selected',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Render all 11 positions — filled or empty
        ...List.generate(11, (i) {
          final pos = i + 1;
          final sp = positionMap[pos];
          if (sp != null) {
            return _buildSquadPlayerTile(sp, isXI: true);
          }
          return _buildEmptySlot(pos);
        }),
      ],
    );
  }

  Widget _buildSquadPlayerTile(SquadPlayer sp, {bool isXI = false}) {
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
              : rarityColor.withValues(alpha: 0.3),
          width: sp.isCaptain ? 2 : 1,
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
          child: Center(
            child: Text(
              '${card.rating}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                card.playerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (sp.isCaptain)
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
                    fontSize: 12,
                  ),
                ),
              ),
            if (sp.isViceCaptain) ...[
              const SizedBox(width: 4),
              Container(
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
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text(card.roleDisplay, style: TextStyle(color: rarityColor, fontSize: 12)),
            const SizedBox(width: 8),
            Text(card.countryCode, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (sp.battingOrder != null) ...[
              const SizedBox(width: 8),
              Text('#${sp.battingOrder}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: AppTheme.surfaceLight,
          onSelected: (value) {
            switch (value) {
              case 'captain':
                ref.read(teamProvider.notifier).setCaptain(sp.id);
                break;
              case 'remove_xi':
                ref.read(teamProvider.notifier).setPlayingXI(sp.id, false);
                break;
              case 'remove':
                ref.read(teamProvider.notifier).removePlayerFromSquad(sp.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'captain', child: Text('Set Captain')),
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

  Widget _buildEmptySlot(int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white10,
          ),
          child: const Icon(Icons.add, color: Colors.white24),
        ),
        title: Text('Position $position', style: const TextStyle(color: Colors.white38)),
        subtitle: const Text('Tap to add player', style: TextStyle(color: Colors.white24, fontSize: 12)),
        onTap: () => _showAddPlayerSheet(position),
      ),
    );
  }

  void _showAddPlayerSheet(int position) {
    final allCards = ref.read(userCardsProvider).valueOrNull ?? [];
    final team = ref.read(teamProvider).valueOrNull;
    final squad = team?.activeSquad;
    // Filter out cards already assigned to the squad
    final assignedCardIds = squad?.players.map((p) => p.userCardId).toSet() ?? {};
    final cards = allCards.where((c) => !assignedCardIds.contains(c.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                _buildSheetHandle(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'SELECT PLAYER',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      if (card.playerCard == null) return const SizedBox();
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppTheme.getRarityColor(card.playerCard!.rarity),
                          ),
                          child: Center(
                            child: Text(
                              '${card.playerCard!.rating}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        title: Text(card.playerCard!.playerName),
                        subtitle: Text(
                          '${card.playerCard!.roleDisplay} | ${card.playerCard!.countryCode}',
                          style: const TextStyle(fontSize: 12),
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
                          Navigator.pop(context);
                        },
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

  Widget _buildFullSquad(Team team) {
    final squad = team.activeSquad;
    if (squad == null) return const Center(child: Text('No squad'));

    // Build a map of position -> SquadPlayer for all 30 slots
    final Map<int, SquadPlayer> positionMap = {};
    for (final sp in squad.players) {
      positionMap[sp.position] = sp;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...List.generate(30, (i) {
          final pos = i + 1;
          final sp = positionMap[pos];
          if (sp != null) {
            return _buildSquadPlayerTile(sp);
          }
          return _buildEmptySlot(pos);
        }),
      ],
    );
  }

  Widget _buildTactics(Team team) {
    final squad = team.activeSquad;
    if (squad == null) return const Center(child: Text('No squad'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Batting order section
        const Text(
          'BATTING ORDER',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...squad.playingXI.asMap().entries.map((entry) {
          final sp = entry.value;
          return _buildBattingOrderTile(sp, entry.key + 1);
        }),
        const SizedBox(height: 24),

        // Bowling selection
        const Text(
          'BOWLERS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...squad.bowlers.map((sp) {
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
                Text(card.playerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  'BOWL ${card.bowling}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBattingOrderTile(SquadPlayer sp, int order) {
    final card = sp.userCard?.playerCard;
    if (card == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(card.playerName, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(card.roleDisplay, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
