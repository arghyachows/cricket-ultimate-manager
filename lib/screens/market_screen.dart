import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../models/models.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRANSFER MARKET'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(text: 'BUY'),
            Tab(text: 'SELL'),
            Tab(text: 'MY BIDS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyTab(),
          _buildSellTab(),
          _buildMyBidsTab(),
        ],
      ),
    );
  }

  Widget _buildBuyTab() {
    final listingsAsync = ref.watch(marketListingsProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search players...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _showMarketFilters(),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Listings
        Expanded(
          child: listingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (listings) {
              final filtered = _searchController.text.isEmpty
                  ? listings
                  : listings.where((l) {
                      final cardData = l.userCardData?['player_cards'];
                      final name = cardData?['player_name'] ?? '';
                      return name
                          .toString()
                          .toLowerCase()
                          .contains(_searchController.text.toLowerCase());
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
                  itemBuilder: (context, index) {
                    return _buildListingCard(filtered[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListingCard(MarketListing listing) {
    final cardData = listing.userCardData?['player_cards'];
    if (cardData == null) return const SizedBox();

    final name = cardData['player_name'] ?? 'Unknown';
    final rating = cardData['rating'] ?? 0;
    final rarity = cardData['rarity'] ?? 'bronze';
    final role = cardData['role'] ?? '';
    final country = cardData['country'] ?? '';
    final rarityColor = AppTheme.getRarityColor(rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
                  Text(
                    '$rating',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    rarity.toString().toUpperCase().substring(0, 3),
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        role.toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: rarityColor, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(country, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Seller: ${listing.sellerUsername ?? 'Unknown'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        listing.timeRemainingDisplay,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Price & actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Buy now price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.buyNowPrice}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Current bid
                if (listing.currentBid > 0)
                  Text(
                    'Bid: ${listing.currentBid}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                const SizedBox(height: 6),
                // Buy button
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _confirmBuy(listing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('BUY NOW'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBuy(MarketListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Confirm Purchase'),
        content: Text(
          'Buy this card for ${listing.buyNowPrice} coins?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(marketListingsProvider.notifier)
                  .buyNow(listing.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Purchase successful!' : 'Purchase failed'),
                    backgroundColor: success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('BUY'),
          ),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    final cardsAsync = ref.watch(userCardsProvider);

    return cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cards) {
        final tradeable = cards.where((c) => c.isTradeable).toList();

        if (tradeable.isEmpty) {
          return const Center(
            child: Text('No tradeable cards', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tradeable.length,
          itemBuilder: (context, index) {
            final card = tradeable[index];
            if (card.playerCard == null) return const SizedBox();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.getRarityColor(card.playerCard!.rarity),
                  ),
                  child: Center(
                    child: Text(
                      '${card.playerCard!.rating}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                title: Text(card.playerCard!.playerName),
                subtitle: Text(card.playerCard!.rarity.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.getRarityColor(card.playerCard!.rarity),
                      fontSize: 12,
                    )),
                trailing: ElevatedButton(
                  onPressed: () => _showSellDialog(card),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('SELL'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSellDialog(UserCard card) {
    final priceController = TextEditingController();
    final bidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('List ${card.playerCard!.playerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Buy Now Price',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bidController,
              decoration: const InputDecoration(
                labelText: 'Starting Bid',
                prefixIcon: Icon(Icons.gavel),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceController.text) ?? 0;
              final bid = int.tryParse(bidController.text) ?? 0;
              if (price > 0 && bid > 0) {
                Navigator.pop(context);
                await ref.read(marketListingsProvider.notifier).listCard(
                  userCardId: card.id,
                  buyNowPrice: price,
                  startingBid: bid,
                );
              }
            },
            child: const Text('LIST'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBidsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text('Your active bids will appear here',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  void _showMarketFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MARKET FILTERS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Filter options coming soon', style: TextStyle(color: Colors.white54)),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
