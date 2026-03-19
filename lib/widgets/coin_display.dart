import 'package:flutter/material.dart';
import '../core/theme.dart';

class CoinDisplay extends StatelessWidget {
  final int coins;
  final int? premiumTokens;
  final bool compact;

  const CoinDisplay({
    super.key,
    required this.coins,
    this.premiumTokens,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCoinChip(
          icon: Icons.monetization_on,
          value: _formatNumber(coins),
          color: AppTheme.accent,
        ),
        if (premiumTokens != null) ...[
          const SizedBox(width: 8),
          _buildCoinChip(
            icon: Icons.diamond,
            value: _formatNumber(premiumTokens!),
            color: Colors.purpleAccent,
          ),
        ],
      ],
    );
  }

  Widget _buildCoinChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return '$number';
  }
}
