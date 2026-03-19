import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';

class DailyObjectivesCard extends StatelessWidget {
  final List<DailyObjective> objectives;

  const DailyObjectivesCard({super.key, required this.objectives});

  @override
  Widget build(BuildContext context) {
    if (objectives.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: Text('No daily objectives', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'DAILY OBJECTIVES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${objectives.where((o) => o.isCompleted).length}/${objectives.length}',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...objectives.map((obj) => _buildObjectiveRow(obj)),
        ],
      ),
    );
  }

  Widget _buildObjectiveRow(DailyObjective objective) {
    final isComplete = objective.isCompleted;
    final progress = objective.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Completion indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isComplete
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isComplete ? AppTheme.success : Colors.white24,
              ),
            ),
            child: isComplete
                ? const Icon(Icons.check, size: 16, color: AppTheme.success)
                : null,
          ),
          const SizedBox(width: 12),

          // Description + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objective.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isComplete ? Colors.white38 : Colors.white,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      isComplete ? AppTheme.success : AppTheme.accent,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Reward
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, size: 12, color: AppTheme.accent),
                const SizedBox(width: 2),
                Text(
                  '${objective.rewardCoins}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
