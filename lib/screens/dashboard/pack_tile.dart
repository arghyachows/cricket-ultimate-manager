import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

/// Pack tile shown in pack highlights horizontal scroll.
class PackTile extends StatelessWidget {
  final Map<String, dynamic> pack;
  const PackTile({super.key, required this.pack});

  Color get _color {
    final name = pack['name'] as String? ?? '';
    if (name.contains('Legend')) return AppTheme.cardLegend;
    if (name.contains('Elite')) return AppTheme.cardElite;
    if (name.contains('Gold')) return AppTheme.cardGold;
    if (name.contains('Silver')) return AppTheme.cardSilver;
    return AppTheme.cardBronze;
  }

  IconData get _icon {
    final name = pack['name'] as String? ?? '';
    if (name.contains('Legend')) return Icons.auto_awesome;
    if (name.contains('Elite')) return Icons.diamond;
    if (name.contains('Gold')) return Icons.military_tech;
    if (name.contains('Silver')) return Icons.workspace_premium;
    return Icons.style;
  }

  @override
  Widget build(BuildContext context) {
    final name = pack['name'] as String? ?? 'Pack';
    final coinCost = pack['coin_cost'] as int? ?? 0;
    final premiumCost = pack['premium_cost'] as int? ?? 0;
    final cardCount = pack['card_count'] as int? ?? 3;
    final color = _color;

    return GestureDetector(
      onTap: () => context.go(AppConstants.packsRoute),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), AppTheme.surface],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('$cardCount cards', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            if (coinCost > 0)
              Row(
                children: [
                  Icon(Icons.monetization_on, size: 12, color: Colors.amber.shade300),
                  const SizedBox(width: 4),
                  Text('$coinCost', style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              )
            else if (premiumCost > 0)
              Row(
                children: [
                  Icon(Icons.diamond, size: 12, color: Colors.blue.shade300),
                  const SizedBox(width: 4),
                  Text('$premiumCost', style: TextStyle(color: Colors.blue.shade300, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}