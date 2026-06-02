import '../../core/supabase_service.dart';
import '../../core/constants.dart';
import '../../core/notification_service.dart';
import 'match_state.dart';

/// Pure calculation helpers for match completion — no Ref dependency.
class MatchCompletionHandler {
  /// Calculate coins, XP, and winner from final scores.
  static ({int coins, int xp, bool? homeWon}) calculateRewards(
    int homeScore,
    int awayScore,
    String difficulty,
    int overs,
  ) {
    double diffMultiplier;
    switch (difficulty) {
      case 'Village': diffMultiplier = 0.5; break;
      case 'Domestic': diffMultiplier = 1.0; break;
      case 'International': diffMultiplier = 2.0; break;
      default: diffMultiplier = 1.0;
    }
    double oversMultiplier;
    switch (overs) {
      case 5: oversMultiplier = 0.25; break;
      case 10: oversMultiplier = 0.5; break;
      case 20: oversMultiplier = 1.0; break;
      case 50: oversMultiplier = 2.0; break;
      default: oversMultiplier = 1.0;
    }

    bool? homeWon;
    int coins;
    int xp;
    if (homeScore > awayScore) {
      homeWon = true;
      coins = (AppConstants.matchWinCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchWinXP;
    } else if (awayScore > homeScore) {
      homeWon = false;
      coins = (AppConstants.matchLoseCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchPlayXP;
    } else {
      homeWon = null;
      coins = (AppConstants.matchDrawCoins * diffMultiplier * oversMultiplier).round();
      xp = AppConstants.matchPlayXP + 20;
    }
    return (coins: coins, xp: xp, homeWon: homeWon);
  }

  static String resultLabel(bool? homeWon) {
    return homeWon == true ? 'Victory!' : homeWon == false ? 'Defeat' : 'Draw';
  }

  /// Send local push notification.
  static void showNotification(MatchState state, bool? homeWon, int coins, int xp) {
    NotificationService.instance.showMatchResult(
      title: 'Quick Match ${resultLabel(homeWon)}',
      body: '${state.homeTeamName} ${state.homeScore}/${state.homeWickets} vs '
          '${state.awayTeamName} ${state.awayScore}/${state.awayWickets} — '
          '+$coins coins, +$xp XP',
    );
  }

  /// Persist rewards to database. Returns (oldLevel, newLevel).
  static Future<({int oldLevel, int newLevel})> persistRewards({
    required String userId,
    required int coins,
    required int xp,
    required bool won,
  }) async {
    int oldDbLevel = 1;
    int newDbLevel = 1;
    try {
      final result = await SupabaseService.client.rpc('award_match_rewards', params: {
        'p_user_id': userId,
        'p_coins': coins,
        'p_xp': xp,
        'p_won': won,
      });
      oldDbLevel = (result?['old_level'] as int? ?? 1);
      newDbLevel = (result?['new_level'] as int? ?? 1);
    } catch (_) {
      try {
        final data = await SupabaseService.getCurrentUser();
        if (data != null) {
          final dbCoins = (data['coins'] as int? ?? 0);
          final dbXp = (data['xp'] as int? ?? 0);
          final dbMatchesPlayed = (data['matches_played'] as int? ?? 0);
          final dbMatchesWon = (data['matches_won'] as int? ?? 0);
          final dbSeasonPoints = (data['season_points'] as int? ?? 0);
          oldDbLevel = (dbXp ~/ AppConstants.xpPerLevel) + 1;
          final newXp = dbXp + xp;
          newDbLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
          final clampedLevel = newDbLevel > AppConstants.maxLevel ? AppConstants.maxLevel : newDbLevel;
          await SupabaseService.client.from('users').update({
            'coins': dbCoins + coins,
            'xp': newXp,
            'level': clampedLevel,
            'matches_played': dbMatchesPlayed + 1,
            if (won) 'matches_won': dbMatchesWon + 1,
            'season_points': dbSeasonPoints + (won ? 100 + (clampedLevel * 5).clamp(0, 200) : 10 + clampedLevel.clamp(0, 50)),
          }).eq('id', userId);
        }
      } catch (_) {}
    }
    return (oldLevel: oldDbLevel, newLevel: newDbLevel);
  }

  /// Grant level-up pack if user crossed a level boundary.
  static Future<void> grantLevelUpPackIfNeeded(String userId, int oldLevel, int newLevel) async {
    await SupabaseService.grantLevelUpPack(userId, oldLevel, newLevel);
  }
}