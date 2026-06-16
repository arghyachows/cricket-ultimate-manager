import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/player_card_widget.dart';

int quickSellPrice(String rarity) => AppConstants.quickSellPrices[rarity] ?? 25;

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;

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
      appBar: AppBar(
        title: const Text('CARDS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(userCardsProvider.notifier).refresh();
              ref.read(userCardPacksProvider.notifier).refresh();
              ref.read(currentUserProvider.notifier).silentRefresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'MY CARDS'),
            Tab(text: 'CARD PACKS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCardsTab(),
          _buildCardPacksTab(),
        ],
      ),
    );
  }

  // ─── My Cards Tab ───────────────────────────────────────

  Widget _buildMyCardsTab() {
    final cards = ref.watch(filteredUserCardsProvider);
    final filter = ref.watch(cardFilterProvider);
    final cardsAsync = ref.watch(userCardsProvider);
    final allCards = cardsAsync.valueOrNull ?? [];

    return cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (_) {
        return Column(
          children: [
            // Stats bar
            _buildStatsBar(allCards, cards, filter),
            // Filter bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${cards.length} of ${allCards.length} cards',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  // View toggle
                  _ViewToggle(
                    isGrid: _isGridView,
                    onToggle: () => setState(() => _isGridView = !_isGridView),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list, size: 20),
                    onPressed: () => _showFilterSheet(context, ref, filter),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cards.isEmpty
                  ? _buildEmptyState(filter)
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(userCardsProvider.notifier).refresh();
                        await ref.read(currentUserProvider.notifier).silentRefresh();
                      },
                      child: _isGridView
                                                ? GridView.builder(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: _getCrossAxisCount(context),
                                                      childAspectRatio: 0.65,
                                                      crossAxisSpacing: 6,
                                                      mainAxisSpacing: 6,
                                                    ),
                                                    itemCount: cards.length,
                                                    itemBuilder: (context, index) {
                                                      final card = cards[index];
                                                      if (card.playerCard == null) return const SizedBox();
                                                      return GestureDetector(
                                                        onTap: () => context.go('/card/${card.id}'),
                                                        onLongPress: () => _showQuickActions(context, card),
                                                        child: PlayerCardWidget(
                                                          playerCard: card.playerCard!,
                                                          userCard: card,
                                                          size: CardSize.small,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : ListView.builder(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    itemCount: cards.length,
                                                    itemBuilder: (context, index) {
                                                      final card = cards[index];
                                                      if (card.playerCard == null) return const SizedBox();
                                                      final rarityColor = AppTheme.getRarityColor(card.playerCard!.rarity.value);
                                                      return Card(
                                                        color: AppTheme.surface,
                                                        margin: const EdgeInsets.only(bottom: 8),
                                                        child: ListTile(
                                                          leading: Container(
                                                            width: 44,
                                                            height: 60,
                                                            decoration: BoxDecoration(
                                                              color: rarityColor.withValues(alpha: 0.2),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                                                            ),
                                                            child: Icon(Icons.person, color: rarityColor, size: 24),
                                                          ),
                                                          title: Text(card.playerCard!.playerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                          subtitle: Text(
                                                            '${card.playerCard!.role.value.toUpperCase()} • ${card.playerCard!.rarity.value.toUpperCase()}',
                                                            style: TextStyle(color: rarityColor, fontSize: 11),
                                                          ),
                                                          trailing: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            children: [
                                                              Text('${card.playerCard!.rating}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: rarityColor)),
                                                              const Text('OVR', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                                            ],
                                                          ),
                                                          onTap: () => context.go('/card/${card.id}'),
                                                          onLongPress: () => _showQuickActions(context, card),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
            ),
          ],
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 10;
    if (width > 900) return 8;
    if (width > 600) return 7;
    if (width > 400) return 6;
    return 5;
  }

  Widget _buildStatsBar(List<UserCard> all, List<UserCard> filtered, CardFilter filter) {
    final hasFilters = filter.rarity != null || filter.role != null;
    final avgRating = all.isEmpty ? 0 : (all.fold<int>(0, (sum, c) => sum + (c.playerCard?.rating ?? 0)) / all.length).round();
    final legendaryCount = all.where((c) => c.playerCard?.rarity == CardRarity.legend).length;
    final eliteCount = all.where((c) => c.playerCard?.rarity == CardRarity.elite).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'TOTAL', value: '${all.length}', icon: Icons.style),
          _StatChip(label: 'AVG', value: '$avgRating', icon: Icons.star),
          if (legendaryCount > 0) _StatChip(label: 'LEGEND', value: '$legendaryCount', icon: Icons.auto_awesome, color: AppTheme.cardLegend),
          if (eliteCount > 0) _StatChip(label: 'ELITE', value: '$eliteCount', icon: Icons.diamond, color: AppTheme.cardElite),
          if (hasFilters)
            TextButton.icon(
              onPressed: () => ref.read(cardFilterProvider.notifier).state = const CardFilter(),
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('CLEAR', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CardFilter filter) {
    final hasFilters = filter.rarity != null || filter.role != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 80, color: hasFilters ? Colors.orange : Colors.white24),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching cards!' : 'No cards yet!',
            style: const TextStyle(fontSize: 20, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters ? 'Try different filters' : 'Open packs to get player cards',
            style: const TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: () => ref.read(cardFilterProvider.notifier).state = const CardFilter(),
              icon: const Icon(Icons.filter_list_off),
              label: const Text('CLEAR FILTERS'),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('OPEN PACKS'),
            ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context, UserCard card) {
    final rarityColor = AppTheme.getRarityColor(card.playerCard?.rarity.value ?? 'bronze');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.person, color: rarityColor, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.playerCard?.playerName ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${card.playerCard!.role.value.toUpperCase()} • ${card.playerCard!.rarity.value.toUpperCase()}', style: TextStyle(color: rarityColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () { Navigator.pop(context); context.go('/card/${card.id}'); },
            ),
            ListTile(
              leading: const Icon(Icons.sell),
              title: const Text('Sell on Market'),
              onTap: () { Navigator.pop(context); _showSellDialog(context, card); },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_photos),
              title: const Text('Add to Squad'),
              onTap: () { Navigator.pop(context); context.go('/squad'); },
            ),
          ],
        ),
      ),
    );
  }

  void _showSellDialog(BuildContext context, UserCard card) {
    final priceController = TextEditingController(text: '${quickSellPrice(card.playerCard?.rarity.value ?? 'bronze') * 10}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('SELL CARD'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (coins)', prefixText: '🪙 '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!'))); },
            child: const Text('LIST'),
          ),
        ],
      ),
    );
  }

  // ─── Card Packs Tab ─────────────────────────────────────

  Widget _buildCardPacksTab() {
    final packsAsync = ref.watch(userCardPacksProvider);

    return packsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (packs) {
        return Column(
          children: [
            // Link to pack store
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('${packs.length} pack${packs.length == 1 ? '' : 's'} available',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go(AppConstants.packsRoute),
                    icon: const Icon(Icons.storefront, size: 16),
                    label: const Text('PACK STORE'),
                  ),
                ],
              ),
            ),
            if (packs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.card_giftcard_outlined,
                          size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No packs available',
                          style: TextStyle(fontSize: 20, color: Colors.white54)),
                      const SizedBox(height: 8),
                      const Text('Earn packs from matches or buy from the store',
                          style: TextStyle(color: Colors.white38)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go(AppConstants.packsRoute),
                        icon: const Icon(Icons.storefront),
                        label: const Text('GO TO STORE'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(userCardPacksProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: packs.length,
                    itemBuilder: (context, index) =>
                        _PackTile(pack: packs[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref, CardFilter filter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(cardFilterProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FILTER & SORT',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Rarity', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter.rarity == null,
                        color: Colors.white,
                        onTap: () =>
                            ref.read(cardFilterProvider.notifier).state =
                                filter.copyWith(rarity: null),
                      ),
                      ...['bronze', 'silver', 'gold', 'elite', 'legend'].map(
                        (r) => _FilterChip(
                          label: r.toUpperCase(),
                          selected: filter.rarity == r,
                          color: AppTheme.getRarityColor(r),
                          onTap: () =>
                              ref.read(cardFilterProvider.notifier).state =
                                  filter.copyWith(rarity: r),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Role', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter.role == null,
                        color: Colors.white,
                        onTap: () =>
                            ref.read(cardFilterProvider.notifier).state =
                                filter.copyWith(role: null),
                      ),
                      ...['batsman', 'bowler', 'all_rounder', 'wicket_keeper'].map(
                        (r) => _FilterChip(
                          label: r.replaceAll('_', ' ').toUpperCase(),
                          selected: filter.role == r,
                          color: Colors.blueAccent,
                          onTap: () =>
                              ref.read(cardFilterProvider.notifier).state =
                                  filter.copyWith(role: r),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort By', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['rating', 'batting', 'bowling', 'name'].map(
                      (s) => _FilterChip(
                        label: s.toUpperCase(),
                        selected: filter.sortBy == s,
                        color: AppTheme.accent,
                        onTap: () =>
                            ref.read(cardFilterProvider.notifier).state =
                                filter.copyWith(sortBy: s),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatChip({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onToggle;

  const _ViewToggle({required this.isGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.grid_view, size: 18, color: isGrid ? AppTheme.accent : Colors.white54),
            onPressed: isGrid ? null : onToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: Icon(Icons.view_list, size: 18, color: !isGrid ? AppTheme.accent : Colors.white54),
            onPressed: !isGrid ? null : onToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PackTile extends ConsumerStatefulWidget {
  final UserCardPack pack;
  const _PackTile({required this.pack});

  @override
  ConsumerState<_PackTile> createState() => _PackTileState();
}

class _PackTileState extends ConsumerState<_PackTile> {
  bool _opening = false;

  Color get _packColor {
    final name = widget.pack.packName.toLowerCase();
    if (name.contains('legend')) return AppTheme.cardLegend;
    if (name.contains('elite')) return AppTheme.cardElite;
    if (name.contains('gold')) return AppTheme.cardGold;
    if (name.contains('silver')) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }

  String get _sourceLabel {
    switch (widget.pack.source) {
      case 'starter':
        return 'STARTER';
      case 'reward':
        return 'REWARD';
      case 'tournament':
        return 'TOURNAMENT';
      case 'purchase':
        return 'PURCHASED';
      default:
        return widget.pack.source.toUpperCase();
    }
  }

  Future<void> _openPack() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final cards = await ref
          .read(userCardPacksProvider.notifier)
          .openPack(widget.pack);

      if (!mounted) return;

      // Load cards into the shared pack opening provider and navigate to reveal screen
      ref.read(packOpeningProvider.notifier).openWithCards(cards);
      context.go('${AppConstants.packOpeningRoute}?fromInventory=true');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open pack: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final color = _packColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), AppTheme.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Pack icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.card_giftcard_rounded, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            // Pack info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.packName.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pack.cardCount} cards  •  $_sourceLabel',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Rarity breakdown bar
                  _RarityBar(pack: pack),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Open button
            ElevatedButton(
              onPressed: _opening ? null : _openPack,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _opening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('OPEN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RarityBar extends StatelessWidget {
  final UserCardPack pack;
  const _RarityBar({required this.pack});

  @override
  Widget build(BuildContext context) {
    final segments = <_RaritySegment>[];
    if (pack.bronzeChance > 0) {
      segments.add(_RaritySegment(pack.bronzeChance, AppTheme.cardBronze));
    }
    if (pack.silverChance > 0) {
      segments.add(_RaritySegment(pack.silverChance, AppTheme.cardSilver));
    }
    if (pack.goldChance > 0) {
      segments.add(_RaritySegment(pack.goldChance, AppTheme.cardGold));
    }
    if (pack.eliteChance > 0) {
      segments.add(_RaritySegment(pack.eliteChance, AppTheme.cardElite));
    }
    if (pack.legendChance > 0) {
      segments.add(_RaritySegment(pack.legendChance, AppTheme.cardLegend));
    }

    final total = segments.fold<double>(0, (s, seg) => s + seg.value);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: segments.map((seg) {
            return Expanded(
              flex: (seg.value / total * 100).round(),
              child: Container(color: seg.color),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RaritySegment {
  final double value;
  final Color color;
  const _RaritySegment(this.value, this.color);
}
