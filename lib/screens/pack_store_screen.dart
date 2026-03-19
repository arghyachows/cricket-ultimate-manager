import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';

class PackStoreScreen extends ConsumerWidget {
  const PackStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packTypesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PACK STORE'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 4),
                  Text('${user.coins}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  const Icon(Icons.diamond, color: AppTheme.cardElite, size: 20),
                  const SizedBox(width: 4),
                  Text('${user.premiumTokens}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (packs) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(packTypesProvider);
            await ref.read(packTypesProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: packs.length,
            itemBuilder: (context, index) {
              final pack = packs[index];
              return _PackCard(pack: pack, user: user);
            },
          ),
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final PackType pack;
  final dynamic user;

  const _PackCard({required this.pack, this.user});

  Color get _packColor {
    if (pack.name.contains('Legend')) return AppTheme.cardLegend;
    if (pack.name.contains('Elite')) return AppTheme.cardElite;
    if (pack.name.contains('Gold')) return AppTheme.cardGold;
    if (pack.name.contains('Silver')) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _packColor.withValues(alpha: 0.3),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _packColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.go('${AppConstants.packOpeningRoute}?packTypeId=${pack.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Pack icon
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [_packColor, _packColor.withValues(alpha: 0.5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _packColor.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.card_giftcard, size: 36, color: Colors.white),
                      const SizedBox(height: 4),
                      Text(
                        '${pack.cardCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'CARDS',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Pack info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name.toUpperCase(),
                        style: TextStyle(
                          color: _packColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                      ),
                      if (pack.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          pack.description!,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Rarity chances
                      _buildRarityBar(pack),
                      const SizedBox(height: 12),
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _packColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pack.isCoinPurchase ? Icons.monetization_on : Icons.diamond,
                              size: 18,
                              color: pack.isCoinPurchase ? AppTheme.accent : AppTheme.cardElite,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              pack.isCoinPurchase
                                  ? '${pack.coinCost}'
                                  : '${pack.premiumCost}',
                              style: TextStyle(
                                color: _packColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _packColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRarityBar(PackType pack) {
    return Row(
      children: [
        if (pack.bronzeChance > 0)
          _RarityDot(color: AppTheme.cardBronze, label: '${pack.bronzeChance.round()}%'),
        if (pack.silverChance > 0)
          _RarityDot(color: AppTheme.cardSilver, label: '${pack.silverChance.round()}%'),
        if (pack.goldChance > 0)
          _RarityDot(color: AppTheme.cardGold, label: '${pack.goldChance.round()}%'),
        if (pack.eliteChance > 0)
          _RarityDot(color: AppTheme.cardElite, label: '${pack.eliteChance.round()}%'),
        if (pack.legendChance > 0)
          _RarityDot(color: AppTheme.cardLegend, label: '${pack.legendChance.round()}%'),
      ],
    );
  }
}

class _RarityDot extends StatelessWidget {
  final Color color;
  final String label;

  const _RarityDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
