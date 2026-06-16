import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';

/// Daily login streak milestones for contract pack rewards.
class DailyStreakMilestones {
  static const Map<int, String> streakRewards = {
    3: 'Bronze Contract Pack',
    7: 'Silver Contract Pack',
    14: 'Gold Contract Pack',
    30: 'Elite Contract Pack',
    60: 'Legend Contract Pack',
  };

  static String? getRewardForStreak(int streak) {
    return streakRewards[streak];
  }
}

/// State holder for daily reward availability.
class DailyRewardState {
  final bool showReward;

  const DailyRewardState({this.showReward = false});

  DailyRewardState copyWith({bool? showReward}) =>
      DailyRewardState(showReward: showReward ?? this.showReward);
}

/// Provider for daily reward logic — checks eligibility and claims rewards.
final dailyRewardProvider =
    StateNotifierProvider<DailyRewardNotifier, DailyRewardState>((ref) {
  return DailyRewardNotifier(ref);
});

class DailyRewardNotifier extends StateNotifier<DailyRewardState> {
  final Ref _ref;

  DailyRewardNotifier(this._ref) : super(const DailyRewardState());

  /// Check if the daily reward is available (not yet claimed today).
  void checkDailyReward() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      state = const DailyRewardState(showReward: false);
      return;
    }
    final now = DateTime.now();
    final last = user.lastDailyReward;
    final claimed = last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
    state = DailyRewardState(showReward: !claimed);
  }

  /// Claim the daily reward and update streak.
  Future<void> claimDailyReward() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    // Calculate new streak
    int newStreak = 1;
    if (user.lastDailyReward != null) {
      final last = user.lastDailyReward!;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      if (last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day) {
        newStreak = (user.dailyStreak ?? 0) + 1;
      }
    }

    // Persist reward
    await SupabaseService.client.from('transactions').insert({
      'user_id': user.id,
      'type': 'daily_reward',
      'coins_amount': 100,
      'description': 'Daily login reward',
    });
    await SupabaseService.client.rpc('increment_user_coins', params: {
      'user_id': user.id,
      'delta': 100,
    });
    await SupabaseService.client.from('users').update({
      'last_daily_reward': DateTime.now().toUtc().toIso8601String(),
      'daily_streak': newStreak,
    }).eq('id', user.id);

    // Check for streak milestone reward
    final streakReward = DailyStreakMilestones.getRewardForStreak(newStreak);
    if (streakReward != null) {
      await _grantStreakContractPack(user.id, streakReward);
    }

    _ref.read(currentUserProvider.notifier).silentRefresh();
    state = const DailyRewardState(showReward: false);
  }

  Future<void> _grantStreakContractPack(
      String userId, String packName) async {
    try {
      final probs = AppConstants.contractPackProbabilities[packName];
      if (probs != null) {
        await SupabaseService.client.from('user_contract_packs').insert({
          'user_id': userId,
          'pack_name': packName,
          'contract_count': 4,
          'bronze_chance': (probs['bronze']! * 100),
          'silver_chance': (probs['silver']! * 100),
          'gold_chance': (probs['gold']! * 100),
          'elite_chance': (probs['elite']! * 100),
          'legend_chance': (probs['legend']! * 100),
          'source': 'daily_streak',
          'opened': false,
        });
      }
    } catch (e) {
      // Log failure without crashing — streak reward is a bonus
      Log.w('Daily streak: failed to grant contract pack');
    }
  }
}
