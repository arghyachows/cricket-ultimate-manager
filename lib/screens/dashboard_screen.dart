import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import 'dashboard/hero_header.dart';
import 'dashboard/featured_card_section.dart';
import 'dashboard/quick_actions_section.dart';
import 'dashboard/recent_matches_section.dart';
import 'dashboard/daily_objectives_section.dart';
import 'dashboard/pack_highlights_section.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dailyRewardProvider.notifier).checkDailyReward());
  }

  Future<void> _claimDailyReward() async {
    final notifier = ref.read(dailyRewardProvider.notifier);
    final oldUser = ref.read(currentUserProvider).valueOrNull;
    await notifier.claimDailyReward();
    if (mounted && oldUser != null) {
      final newUser = ref.read(currentUserProvider).valueOrNull;
      final oldStreak = oldUser.dailyStreak ?? 0;
      final newStreak = newUser?.dailyStreak ?? 0;
      final wasMilestone = DailyStreakMilestones.getRewardForStreak(newStreak) != null;
      String message = '💰 +100 coins claimed! Streak: $newStreak days';
      if (wasMilestone) message += ' 🎁 Streak reward unlocked!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final rewardState = ref.watch(dailyRewardProvider);

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
                  showDailyReward: rewardState.showReward,
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