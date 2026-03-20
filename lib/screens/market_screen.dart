import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../providers/cards_provider.dart' show listedCardIdsProvider;
import '../models/models.dart';

/// Reusable sell-on-market dialog (called from card detail & sell tab)
void showSellOnMarketDialog(BuildContext context, WidgetRef ref, UserCard card) {
  // Block listing a player currently in the Playing XI
  final team = ref.read(teamProvider).valueOrNull;
  final squad = team?.activeSquad;
  if (squad != null) {
    final inXI = squad.isInLineup(card.id);
    if (inXI) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remove this player from your Playing XI before listing'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
  }

  final pc = card.playerCard!;
  final minBid = AppConstants.minBidByRarity[pc.rarity] ?? 50;
  final bidController = TextEditingController(text: '$minBid');
  final buyNowController = TextEditingController(text: '${minBid * 3}');
  int duration = AppConstants.listingDurationHours;
  bool listing = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Sell ${pc.playerName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppTheme.getRarityColor(pc.rarity),
                    ),
                    child: Center(
                      child: Text('${pc.rating}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pc.playerName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${pc.rarity.toUpperCase()} • ${pc.role.replaceAll('_', ' ')}',
                            style: TextStyle(
                                color: AppTheme.getRarityColor(pc.rarity),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Minimum starting bid: $minBid coins',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: bidController,
                decoration: const InputDecoration(
                  labelText: 'Starting Bid',
                  prefixIcon: Icon(Icons.gavel),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: buyNowController,
                decoration: const InputDecoration(
                  labelText: 'Buy Now Price',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Auction Duration', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [1, 3, 6, 12].map((h) {
                  final selected = duration == h;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${h}h'),
                        selected: selected,
                        onSelected: (_) => setDialogState(() => duration = h),
                        selectedColor: AppTheme.accent,
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('5% tax on sale', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: listing ? null : () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: listing
                ? null
                : () async {
              final bid = int.tryParse(bidController.text) ?? 0;
              final buyNow = int.tryParse(buyNowController.text) ?? 0;

              if (bid < minBid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting bid must be at least $minBid')),
                );
                return;
              }
              if (buyNow <= bid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Buy now price must be higher than starting bid')),
                );
                return;
              }
              if (buyNow > AppConstants.maxListingPrice) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Max price is ${AppConstants.maxListingPrice}')),
                );
                return;
              }

              setDialogState(() => listing = true);
              final success = await ref
                  .read(marketListingsProvider.notifier)
                  .listCard(
                    userCardId: card.id,
                    buyNowPrice: buyNow,
                    startingBid: bid,
                    durationHours: duration,
                  );
              ref.read(myListingsProvider.notifier).refresh();
              ref.invalidate(listedCardIdsProvider);

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '${pc.playerName} listed for auction!'
                        : 'Failed to list card'),
                    backgroundColor: success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: listing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('LIST FOR SALE'),
          ),
        ],
      ),
    ),
  );
}

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Tick every second to update countdown timers
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        ref.read(marketListingsProvider.notifier).refresh();
        break;
      case 1:
        ref.read(userCardsProvider.notifier).refresh();
        break;
      case 2:
        ref.read(myBidsProvider.notifier).refresh();
        break;
      case 3:
        ref.read(myListingsProvider.notifier).refresh();
        break;
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRANSFER MARKET'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(marketListingsProvider.notifier).refresh();
              ref.read(myBidsProvider.notifier).refresh();
              ref.read(myListingsProvider.notifier).refresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'BUY'),
            Tab(text: 'SELL'),
            Tab(text: 'MY BIDS'),
            Tab(text: 'MY LISTINGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BuyTab(searchController: _searchController),
          const _SellTab(),
          const _MyBidsTab(),
          const _MyListingsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BUY TAB
// ═══════════════════════════════════════════════════════════════════
class _BuyTab extends ConsumerWidget {
  final TextEditingController searchController;
  const _BuyTab({required this.searchController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(marketListingsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Search players...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
        ),

        // Coin balance
        if (user != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppTheme.cardGold, size: 16),
                const SizedBox(width: 4),
                Text('${user.coins} coins',
                    style: const TextStyle(color: AppTheme.cardGold, fontSize: 13)),
              ],
            ),
          ),

        // Listings
        Expanded(
          child: listingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (listings) {
              final userId = user?.id;
              final query = searchController.text.toLowerCase();
              final filtered = listings.where((l) {
                // Hide seller's own listings
                if (userId != null && l.sellerId == userId) return false;
                if (query.isNotEmpty) {
                  final cardData = l.userCardData?['player_cards'];
                  final name = (cardData?['player_name'] ?? '').toString().toLowerCase();
                  if (!name.contains(query)) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No listings found', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(marketListingsProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ListingCard(listing: filtered[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListingCard extends ConsumerWidget {
  final MarketListing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardData = listing.userCardData?['player_cards'];
    if (cardData == null) return const SizedBox();

    final name = cardData['player_name'] ?? 'Unknown';
    final rating = cardData['rating'] ?? 0;
    final rarity = cardData['rarity'] ?? 'bronze';
    final role = cardData['role'] ?? '';
    final country = cardData['country'] ?? '';
    final rarityColor = AppTheme.getRarityColor(rarity);
    final userId = ref.watch(currentUserProvider).valueOrNull?.id;
    final userCoins = ref.watch(currentUserProvider).valueOrNull?.coins ?? 0;
    final isSeller = listing.sellerId == userId;
    final isHighestBidder = listing.currentBidderId == userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Rating badge
                Container(
                  width: 56,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [rarityColor, rarityColor.withValues(alpha: 0.5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$rating',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(rarity.toString().toUpperCase().substring(0, 3),
                          style: const TextStyle(fontSize: 9, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(role.toString().replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(color: rarityColor, fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(country,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('Seller: ${listing.sellerUsername ?? 'Unknown'}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        const Spacer(),
                        Icon(Icons.timer_outlined,
                            size: 12, color: Colors.orangeAccent),
                        const SizedBox(width: 3),
                        Text(listing.timeRemainingDisplay,
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Price row + action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Starting bid
                _PriceChip(
                  label: 'Start',
                  amount: listing.startingBid,
                  color: Colors.white54,
                ),
                // Current bid
                _PriceChip(
                  label: listing.currentBid > 0 ? 'Current Bid' : 'No bids',
                  amount: listing.currentBid > 0 ? listing.currentBid : null,
                  color: AppTheme.primaryLight,
                ),
                if (!isSeller) ...[
                  // Bid button
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: isHighestBidder
                          ? null
                          : () => _showBidDialog(context, ref, userCoins),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isHighestBidder ? Colors.white24 : AppTheme.primaryLight),
                        foregroundColor: AppTheme.primaryLight,
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(isHighestBidder ? 'YOUR BID' : 'BID'),
                    ),
                  ),
                  // Buy now button
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => _confirmBuyNow(context, ref, userCoins),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text('BUY ${listing.buyNowPrice}'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBidDialog(BuildContext context, WidgetRef ref, int userCoins) {
    final minBid = listing.currentBid > 0
        ? listing.currentBid + AppConstants.minBidIncrement
        : listing.startingBid;
    final controller = TextEditingController(text: '$minBid');

    if (userCoins < minBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough coins. You have $userCoins but need at least $minBid.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        bool bidding = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Place Bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current bid: ${listing.currentBid > 0 ? listing.currentBid : "None"}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Text('Minimum bid: $minBid',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Your balance: $userCoins coins',
                style: TextStyle(
                    color: userCoins >= minBid ? AppTheme.cardGold : AppTheme.error,
                    fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Your coins will be held until you are outbid or the auction ends.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Your Bid',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: bidding ? null : () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: bidding
                ? null
                : () async {
              final amount = int.tryParse(controller.text) ?? 0;
              if (amount < minBid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bid must be at least $minBid')),
                );
                return;
              }
              if (amount > userCoins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Not enough coins. You have $userCoins.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
              setDialogState(() => bidding = true);
              final result = await ref
                  .read(marketListingsProvider.notifier)
                  .placeBid(listing.id, amount);
              final success = result['success'] == true;
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Bid placed! $amount coins held.'
                        : result['error'] ?? 'Bid failed'),
                    backgroundColor: success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            child: bidding
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('PLACE BID'),
          ),
        ],
      ),
        );
      },
    );
  }

  void _confirmBuyNow(BuildContext context, WidgetRef ref, int userCoins) {
    if (userCoins < listing.buyNowPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough coins. You have $userCoins but need ${listing.buyNowPrice}.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        bool buying = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Buy Now'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buy this card for ${listing.buyNowPrice} coins?'),
            const SizedBox(height: 8),
            Text(
              '5% market tax applies. Seller receives ${(listing.buyNowPrice * 0.95).round()} coins.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: buying ? null : () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: buying
                ? null
                : () async {
              setDialogState(() => buying = true);
              final result = await ref
                  .read(marketListingsProvider.notifier)
                  .buyNow(listing.id);
              final success = result['success'] == true;
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Purchase successful! Card added to your collection.'
                        : result['error'] ?? 'Purchase failed'),
                    backgroundColor: success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: buying
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('BUY'),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final int? amount;
  final Color color;

  const _PriceChip({required this.label, this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amount != null) ...[
            Icon(Icons.monetization_on, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            amount != null ? '$amount' : label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (amount != null) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SELL TAB
// ═══════════════════════════════════════════════════════════════════
class _SellTab extends ConsumerWidget {
  const _SellTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider);

    return cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cards) {
        // Exclude cards in Playing XI and those already listed
        final team = ref.watch(teamProvider).valueOrNull;
        final squad = team?.activeSquad;
        final xiCardIds = squad?.lineup
            .map((p) => p.userCardId)
            .toSet() ?? {};
        final listedIds = ref.watch(listedCardIdsProvider).valueOrNull ?? {};

        final tradeable = cards.where((c) =>
            c.isTradeable &&
            c.playerCard != null &&
            !xiCardIds.contains(c.id) &&
            !listedIds.contains(c.id)).toList();

        if (tradeable.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(userCardsProvider.notifier).loadCards(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: Icon(Icons.sell_outlined, size: 64, color: Colors.white24)),
                SizedBox(height: 16),
                Center(child: Text('No tradeable cards', style: TextStyle(color: Colors.white54))),
                SizedBox(height: 4),
                Center(child: Text('Open packs to get cards you can sell',
                    style: TextStyle(color: Colors.white38, fontSize: 12))),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(userCardsProvider.notifier).loadCards(),
          child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: tradeable.length,
          itemBuilder: (context, index) {
            final card = tradeable[index];
            final pc = card.playerCard!;
            final rarityColor = AppTheme.getRarityColor(pc.rarity);
            final minBid = AppConstants.minBidByRarity[pc.rarity] ?? 50;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rarityColor.withValues(alpha: 0.2)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: rarityColor,
                  ),
                  child: Center(
                    child: Text('${pc.rating}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                title: Text(pc.playerName),
                subtitle: Row(
                  children: [
                    Text(pc.rarity.toUpperCase(),
                        style: TextStyle(color: rarityColor, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('Min bid: $minBid',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => showSellOnMarketDialog(context, ref, card),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('SELL'),
                ),
              ),
            );
          },
        ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MY BIDS TAB
// ═══════════════════════════════════════════════════════════════════
class _MyBidsTab extends ConsumerWidget {
  const _MyBidsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(myBidsProvider);

    return bidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bids) {
        if (bids.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gavel_outlined, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text('No bids yet', style: TextStyle(color: Colors.white54, fontSize: 18)),
                SizedBox(height: 4),
                Text('Place bids on cards in the BUY tab',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(myBidsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bids.length,
            itemBuilder: (context, index) => _BidTile(bid: bids[index]),
          ),
        );
      },
    );
  }
}

class _BidTile extends StatelessWidget {
  final MarketBid bid;
  const _BidTile({required this.bid});

  @override
  Widget build(BuildContext context) {
    final listing = bid.listing;
    final cardData = listing?.userCardData?['player_cards'];
    final name = cardData?['player_name'] ?? 'Unknown';
    final rarity = cardData?['rarity'] ?? 'bronze';
    final rating = cardData?['rating'] ?? 0;
    final rarityColor = AppTheme.getRarityColor(rarity);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (bid.status) {
      case 'active':
        statusColor = AppTheme.success;
        statusLabel = 'LEADING';
        statusIcon = Icons.check_circle;
        break;
      case 'outbid':
        statusColor = Colors.orangeAccent;
        statusLabel = 'OUTBID';
        statusIcon = Icons.warning_amber;
        break;
      case 'won':
        statusColor = AppTheme.accent;
        statusLabel = 'WON';
        statusIcon = Icons.emoji_events;
        break;
      case 'lost':
        statusColor = Colors.white38;
        statusLabel = 'LOST';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.white38;
        statusLabel = bid.status.toUpperCase();
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rating
            Container(
              width: 44,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: rarityColor,
              ),
              child: Center(
                child: Text('$rating',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.monetization_on, size: 13, color: AppTheme.cardGold),
                    const SizedBox(width: 3),
                    Text('Your bid: ${bid.bidAmount}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (listing != null && listing.currentBid > bid.bidAmount) ...[
                      const SizedBox(width: 8),
                      Text('Current: ${listing.currentBid}',
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 12)),
                    ],
                  ]),
                  if (listing != null)
                    Text(listing.hasExpired ? 'Auction ended' : 'Ends: ${listing.timeRemainingDisplay}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MY LISTINGS TAB
// ═══════════════════════════════════════════════════════════════════
class _MyListingsTab extends ConsumerWidget {
  const _MyListingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return listingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (listings) {
        if (listings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sell_outlined, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text('No listings', style: TextStyle(color: Colors.white54, fontSize: 18)),
                SizedBox(height: 4),
                Text('List cards from the SELL tab',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(myListingsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listings.length,
            itemBuilder: (context, index) =>
                _MyListingTile(listing: listings[index]),
          ),
        );
      },
    );
  }
}

class _MyListingTile extends ConsumerWidget {
  final MarketListing listing;
  const _MyListingTile({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardData = listing.userCardData?['player_cards'];
    final name = cardData?['player_name'] ?? 'Unknown';
    final rarity = cardData?['rarity'] ?? 'bronze';
    final rating = cardData?['rating'] ?? 0;
    final rarityColor = AppTheme.getRarityColor(rarity);

    Color statusColor;
    String statusLabel;
    switch (listing.status) {
      case 'active':
        statusColor = listing.hasExpired ? Colors.orangeAccent : AppTheme.success;
        statusLabel = listing.hasExpired ? 'ENDED' : 'ACTIVE';
        break;
      case 'sold':
        statusColor = AppTheme.accent;
        statusLabel = 'SOLD';
        break;
      case 'expired':
        statusColor = Colors.white38;
        statusLabel = 'EXPIRED';
        break;
      case 'cancelled':
        statusColor = Colors.white38;
        statusLabel = 'CANCELLED';
        break;
      default:
        statusColor = Colors.white38;
        statusLabel = listing.status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarityColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: rarityColor,
              ),
              child: Center(
                child: Text('$rating',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('Buy now: ${listing.buyNowPrice}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 10),
                    if (listing.currentBid > 0)
                      Text('Bid: ${listing.currentBid}',
                          style: const TextStyle(
                              color: AppTheme.accent, fontSize: 12)),
                  ]),
                  if (listing.isActive && !listing.hasExpired)
                    Text('Ends: ${listing.timeRemainingDisplay}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                // Cancel button (only for active listings)
                if (listing.isActive && !listing.hasExpired)
                  SizedBox(
                    height: 28,
                    child: TextButton(
                      onPressed: () => _confirmCancel(context, ref),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool cancelling = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cancel Listing'),
        content: listing.currentBid > 0
            ? Text(
                'This listing has a bid of ${listing.currentBid} coins. '
                'Cancelling will refund the bidder. Continue?')
            : const Text('Remove this card from the market?'),
        actions: [
          TextButton(
            onPressed: cancelling ? null : () => Navigator.pop(ctx),
            child: const Text('KEEP'),
          ),
          ElevatedButton(
            onPressed: cancelling
                ? null
                : () async {
              setDialogState(() => cancelling = true);
              final result = await ref
                  .read(marketListingsProvider.notifier)
                  .cancelListing(listing.id);
              final success = result['success'] == true;
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        success ? 'Listing cancelled' : result['error'] ?? 'Failed to cancel'),
                    backgroundColor: success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: cancelling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('CANCEL LISTING'),
          ),
        ],
      ),
        );
      },
    );
  }
}
