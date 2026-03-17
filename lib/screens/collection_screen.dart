import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/player_card_widget.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen>
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

    return cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (_) {
        if (cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.style_outlined, size: 80, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'No cards yet!',
                  style: TextStyle(fontSize: 20, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open packs to get player cards',
                  style: TextStyle(color: Colors.white38),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('OPEN PACKS'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Filter bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text('${cards.length} cards',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list, size: 20),
                    onPressed: () => _showFilterSheet(context, ref, filter),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
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
                    child: PlayerCardWidget(
                      playerCard: card.playerCard!,
                      userCard: card,
                      size: CardSize.small,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: packs.length,
                  itemBuilder: (context, index) =>
                      _PackTile(pack: packs[index]),
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

      // Show revealed cards in a dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PackRevealDialog(cards: cards),
      );
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

class _PackRevealDialog extends StatelessWidget {
  final List<UserCard> cards;
  const _PackRevealDialog({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PACK OPENED!',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${cards.length} cards received',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  if (card.playerCard == null) return const SizedBox();
                  return PlayerCardWidget(
                    playerCard: card.playerCard!,
                    userCard: card,
                    size: CardSize.small,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'AWESOME!',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
