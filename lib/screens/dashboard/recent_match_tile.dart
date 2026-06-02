import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';

/// Single recent match tile shown in dashboard.
class RecentMatchTile extends StatelessWidget {
  final Map<String, dynamic> match;
  const RecentMatchTile({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentUserId;
    final isHome = match['home_user_id'] == userId;
    final myScore = isHome ? match['home_score'] : match['away_score'];
    final myWickets = isHome ? match['home_wickets'] : match['away_wickets'];
    final oppScore = isHome ? match['away_score'] : match['home_score'];
    final oppWickets = isHome ? match['away_wickets'] : match['home_wickets'];
    final winnerId = match['winner_user_id'];
    final won = winnerId == userId;
    final draw = winnerId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: won
              ? Colors.green.withValues(alpha: 0.3)
              : (draw ? Colors.orange.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: won ? Colors.green : (draw ? Colors.orange : Colors.red),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match['format']?.toString().toUpperCase() ?? 'T20',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(won ? 'Victory!' : (draw ? 'Draw' : 'Defeat'),
                    style: TextStyle(
                      color: won ? Colors.green : (draw ? Colors.orange : Colors.red),
                      fontWeight: FontWeight.bold, fontSize: 14,
                    )),
              ],
            ),
          ),
          Text('$myScore/$myWickets', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          const Text('vs', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Text('$oppScore/$oppWickets', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 8),
          Text('(${match['home_overs'] ?? 0} ov)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}