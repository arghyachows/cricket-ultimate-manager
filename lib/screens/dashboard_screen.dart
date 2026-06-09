import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/supabase_service.dart';
import '../providers/providers.dart';
import 'dashboard/hero_header.dart';
import 'dashboard/featured_card_section.dart';
import 'dashboard/quick_actions_section.dart';
import 'dashboard/recent_matches_section.dart';
import 'dashboard/daily_objectives_section.dart';
import 'dashboard/pack_highlights_section.dart';

class DailyObjectivesCardPlaceholder extends StatelessWidget {
  const DailyObjectivesCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Daily login streak milestones for contract pack rewards
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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showDailyReward = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkDailyReward);
  }

  Future<void> _checkDailyReward() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final now = DateTime.now();
    final last = user.lastDailyReward;
    final claimed = last != null &&
        last.year == now.year && last.month == now.month && last.day == now.day;
    if (!claimed) setState(() => _showDailyReward = true);
  }

  Future<void> _claimDailyReward() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    
    // Calculate new streak
    int newStreak = 1;
    if (user.lastDailyReward != null) {
      final last = user.lastDailyReward!;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      if (last.year == yesterday.year && last.month == yesterday.month && last.day == yesterday.day) {
        newStreak = (user.dailyStreak ?? 0) + 1;
      }
    }
    
    await SupabaseService.client.from('transactions').insert({
      'user_id': user.id,
      'type': 'daily_reward',
      'coins_amount': 100,
      'description': 'Daily login reward',
    });
    await SupabaseService.client.rpc('increment_user_coins', params: {'user_id': user.id, 'delta': 100});
    await SupabaseService.client.from('users').update({
      'last_daily_reward': DateTime.now().toUtc().toIso8601String(),
      'daily_streak': newStreak,
    }).eq('id', user.id);
    
    // Check for streak milestone reward
    final streakReward = DailyStreakMilestones.getRewardForStreak(newStreak);
    if (streakReward != null) {
      await _grantStreakContractPack(user.id, streakReward);
    }
    
    ref.read(currentUserProvider.notifier).silentRefresh();
    setState(() => _showDailyReward = false);
    if (mounted) {
      String message = '💰 +100 coins claimed!';
      if (streakReward != null) {
        message += ' 🎁 $streakReward (Streak: $newStreak days!)';
      } else {
        message += ' Streak: $newStreak days';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  Future<void> _grantStreakContractPack(String userId, String packName) async {
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
      print('❌ [DAILY STREAK] Failed to grant contract pack: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppConstants.loginRoute));
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async => ref.read(currentUserProvider.notifier).silentRefresh(),
            child: ListView(
              children: [
                HeroHeader(
                  user: user,
                  showDailyReward: _showDailyReward,
                  onClaimDailyReward: _claimDailyReward,
                ),
                const FeaturedCardSection(),
                const QuickActionsSection(),
                const RecentMatchesSection(),
                const DailyObjectivesSection(),
                const PackHighlightsSection(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}