import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Season tier badge shown next to username.
class SeasonTierBadge extends StatelessWidget {
  final String tier;
  const SeasonTierBadge({super.key, required this.tier});

  Color get _c {
    switch (tier) {
      case 'champion': return Colors.amber;
      case 'elite': return AppTheme.cardElite;
      case 'gold': return AppTheme.cardGold;
      case 'silver': return AppTheme.cardSilver;
      default: return AppTheme.cardBronze;
    }
  }

  String get _label {
    switch (tier) {
      case 'champion': return '⚔️ CHAMPION';
      case 'elite': return '💎 ELITE';
      case 'gold': return '🥇 GOLD';
      case 'silver': return '🥈 SILVER';
      default: return '🥉 BRONZE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c.withValues(alpha: 0.4)),
      ),
      child: Text(_label,
          style: TextStyle(color: _c, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
    );
  }
}