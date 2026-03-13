import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart' show AppConstants;
import '../core/supabase_service.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/player_card_widget.dart';

int quickSellPrice(String rarity) =>
    AppConstants.quickSellPrices[rarity] ?? 25;

class CardDetailScreen extends ConsumerWidget {
  final String cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider);

    return cardsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (cards) {
        final userCard = cards.where((c) => c.id == cardId).firstOrNull;
        if (userCard == null || userCard.playerCard == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Card not found')),
          );
        }

        final card = userCard.playerCard!;
        final rarityColor = AppTheme.getRarityColor(card.rarity);

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              // Card hero header
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: rarityColor.withValues(alpha: 0.3),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildCardHero(card, userCard, rarityColor),
                ),
              ),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick info
                      _buildQuickInfo(card, userCard, rarityColor),
                      const SizedBox(height: 20),

                      // Main stats
                      const Text(
                        'ATTRIBUTES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatsGrid(card, rarityColor),
                      const SizedBox(height: 20),

                      // Card info
                      const Text(
                        'CARD INFO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCardInfo(userCard, rarityColor),
                      const SizedBox(height: 20),

                      // Actions
                      _buildActions(context, ref, userCard, rarityColor),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardHero(PlayerCard card, UserCard userCard, Color rarityColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        CachedNetworkImage(
          imageUrl: playerCardImageUrl(card),
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: rarityColor.withValues(alpha: 0.3)),
          errorWidget: (_, __, ___) => Container(color: rarityColor.withValues(alpha: 0.3)),
        ),

        // Dark overlay so text is readable
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                AppTheme.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.25, 0.45, 0.75, 1.0],
            ),
          ),
        ),

        // Rarity accent tint
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                rarityColor.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.center,
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Large rating circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [rarityColor, rarityColor.withValues(alpha: 0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${userCard.effectiveRating}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black87),
                        ],
                      ),
                    ),
                    Text(
                      card.rarity.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                card.playerName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black87),
                    Shadow(offset: Offset(0, 0), blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.country,
                    style: const TextStyle(
                      color: Colors.white70,
                      shadows: [
                        Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    card.roleDisplay,
                    style: TextStyle(
                      color: rarityColor,
                      shadows: const [
                        Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
              if (card.team != null) ...[
                const SizedBox(height: 4),
                Text(
                  card.team!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    shadows: [
                      Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo(PlayerCard card, UserCard userCard, Color rarityColor) {
    return Row(
      children: [
        _buildQuickInfoTile('Level', '${userCard.level}', Icons.arrow_upward, rarityColor),
        const SizedBox(width: 8),
        _buildQuickInfoTile('Form', '${userCard.form}', Icons.trending_up, AppTheme.success),
        const SizedBox(width: 8),
        _buildQuickInfoTile(
          'Fatigue',
          '${userCard.fatigue}%',
          Icons.battery_charging_full,
          userCard.fatigue > 70 ? AppTheme.error : AppTheme.accent,
        ),
        const SizedBox(width: 8),
        _buildQuickInfoTile(
          'Matches',
          '${userCard.matchesPlayed}',
          Icons.sports_cricket,
          Colors.white54,
        ),
      ],
    );
  }

  Widget _buildQuickInfoTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(PlayerCard card, Color rarityColor) {
    final stats = [
      ('BAT', card.batting, Icons.sports_cricket),
      ('BOWL', card.bowling, Icons.blur_circular),
      ('FIELD', card.fielding, Icons.sports_handball),
      ('PACE', card.pace, Icons.speed),
      ('SPIN', card.spin, Icons.rotate_right),
      ('STAM', card.stamina, Icons.fitness_center),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: stats.map((stat) {
        final (label, value, icon) = stat;
        final statColor = value >= 90
            ? AppTheme.getRarityColor('legend')
            : value >= 80
                ? AppTheme.getRarityColor('elite')
                : value >= 70
                    ? AppTheme.getRarityColor('gold')
                    : value >= 60
                        ? AppTheme.getRarityColor('silver')
                        : AppTheme.getRarityColor('bronze');

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: statColor),
                  const SizedBox(width: 4),
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: statColor,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardInfo(UserCard userCard, Color rarityColor) {
    final card = userCard.playerCard!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Card Type', card.cardType.toUpperCase()),
          _buildInfoRow('Rarity', card.rarity.toUpperCase()),
          _buildInfoRow('League', card.league ?? '-'),
          _buildInfoRow('Acquired', userCard.acquiredAt.toString().substring(0, 10)),
          _buildInfoRow('Tradeable', userCard.isTradeable ? 'Yes' : 'No'),
          _buildInfoRow('Effective Batting', '${userCard.effectiveBatting}'),
          _buildInfoRow('Effective Bowling', '${userCard.effectiveBowling}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, WidgetRef ref, UserCard userCard, Color rarityColor) {
    final card = userCard.playerCard!;
    final sellPrice = quickSellPrice(card.rarity);

    return Column(
      children: [
        if (userCard.isTradeable)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to sell screen')),
                );
              },
              icon: const Icon(Icons.sell),
              label: const Text('SELL ON MARKET'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: rarityColor),
                foregroundColor: rarityColor,
              ),
            ),
          ),
        if (userCard.isTradeable) const SizedBox(height: 12),
        // Quick Sell button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showQuickSellDialog(context, ref, userCard, sellPrice),
            icon: const Icon(Icons.monetization_on_outlined, size: 18),
            label: Text('QUICK SELL  •  $sellPrice coins'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
              foregroundColor: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }

  void _showQuickSellDialog(
      BuildContext context, WidgetRef ref, UserCard userCard, int sellPrice) {
    final card = userCard.playerCard!;
    final rarityColor = AppTheme.getRarityColor(card.rarity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quick Sell', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerCardWidget(
              playerCard: card,
              userCard: userCard,
              size: CardSize.small,
            ),
            const SizedBox(height: 16),
            Text(
              'Sell ${card.playerName} for',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                const SizedBox(width: 6),
                Text(
                  '$sellPrice',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('coins', style: TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.error, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Atomic: remove card + credit coins in one RPC
                await SupabaseService.quickSellCard(userCard.id, sellPrice);
                // Update local state
                ref.read(userCardsProvider.notifier).removeCard(userCard.id);
                ref.read(currentUserProvider.notifier).updateCoins(sellPrice);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sold ${card.playerName} for $sellPrice coins!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  context.go(AppConstants.collectionRoute);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to sell: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('SELL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
