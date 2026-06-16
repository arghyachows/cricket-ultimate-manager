import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/cards_provider.dart';
import 'mini_stat.dart';

/// Featured star player card section.
class FeaturedCardSection extends ConsumerWidget {
  const FeaturedCardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider);

    return cardsAsync.when(
      data: (cards) {
        final validCards = cards.where((c) => c.playerCard != null).toList();
        if (validCards.isEmpty) return const SizedBox.shrink();
        final featured = validCards.reduce((a, b) => a.effectiveRating >= b.effectiveRating ? a : b);
        final playerCard = featured.playerCard!;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.getRarityColor(playerCard.rarity.value).withValues(alpha: 0.15),
                  AppTheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.getRarityColor(playerCard.rarity.value).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.getRarityColor(playerCard.rarity.value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(playerCard.rarity.value.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    const Text('STAR PLAYER',
                        style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go(AppConstants.collectionRoute),
                      child: const Text('View all', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Card preview
                    Container(
                      width: 70, height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [
                            AppTheme.getRarityColor(playerCard.rarity.value).withValues(alpha: 0.6),
                            AppTheme.getRarityColor(playerCard.rarity.value).withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getRarityColor(playerCard.rarity.value).withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(playerCard.playerName.split(' ').last,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(featured.level > 1 ? '+${(featured.level - 1) * 2}' : '',
                              style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('${featured.effectiveRating}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playerCard.playerName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${playerCard.role.value.replaceAll('_', ' ').toUpperCase()} · ${playerCard.country}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              MiniStat(label: 'BAT', value: featured.effectiveBatting, color: AppTheme.primaryLight),
                              const SizedBox(width: 8),
                              MiniStat(label: 'BOW', value: featured.effectiveBowling, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              MiniStat(label: 'FIE', value: playerCard.fielding, color: Colors.blueAccent),
                              if (featured.level > 1) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('LV${featured.level}',
                                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}