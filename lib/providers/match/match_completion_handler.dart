import 'dart:io';

import 'package:postgrest/postgrest.dart';
import '../../core/supabase_service.dart';
import '../../core/constants.dart';
import '../../core/notification_service.dart';
import 'match_state.dart';

/// Result of a reward persistence attempt.
class PersistResult {
  final bool success;
  final int oldLevel;
  final int newLevel;
  final Object? error;
  final StackTrace? stackTrace;

  const PersistResult({
    required this.success,
    this.oldLevel = 1,
    this.newLevel = 1,
    this.error,
    this.stackTrace,
  });

  PersistResult.failed({Object? error, StackTrace? stackTrace})
      : success = false,
        oldLevel = 1,
        newLevel = 1,
        error = error,
        stackTrace = stackTrace;

  PersistResult.succeeded({required this.oldLevel, required this.newLevel})
      : success = true,
        error = null,
        stackTrace = null;
}

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

  /// Persist rewards to database.
  /// Returns a [PersistResult] indicating success or failure with error details.
  /// On failure, the caller must NOT apply local state updates (coins/XP).
  static Future<PersistResult> persistRewards({
    required String userId,
    required int coins,
    required int xp,
    required bool won,
  }) async {
    int oldDbLevel = 1;
    int newDbLevel = 1;

    // Attempt 1: RPC call (atomic server-side update)
    try {
      final result = await SupabaseService.client.rpc('award_match_rewards', params: {
        'p_user_id': userId,
        'p_coins': coins,
        'p_xp': xp,
        'p_won': won,
      });
      oldDbLevel = (result?['old_level'] as int? ?? 1);
      newDbLevel = (result?['new_level'] as int? ?? 1);
      return PersistResult.succeeded(oldLevel: oldDbLevel, newLevel: newDbLevel);
    } on PostgrestException catch (e) {
      // Database/query error — log and fall through to fallback
      print('⚠️ [PERSIST] PostgrestException during RPC: ${e.message}');
    } on SocketException catch (e) {
      // Network unreachable — log and fall through to fallback
      print('⚠️ [PERSIST] SocketException during RPC: ${e.message}');
    } on FormatException catch (e) {
      // Malformed response — log and fall through to fallback
      print('⚠️ [PERSIST] FormatException during RPC: ${e.message}');
    } catch (e) {
      // Unknown error — log and fall through to fallback
      print('⚠️ [PERSIST] Unexpected error during RPC: $e');
    }

    // Attempt 2: Fallback direct table update
    try {
      final data = await SupabaseService.getCurrentUser();
      if (data == null) {
        return PersistResult.failed(
          error: 'Could not fetch current user data for fallback update',
          stackTrace: StackTrace.current,
        );
      }
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
      return PersistResult.succeeded(oldLevel: oldDbLevel, newLevel: newDbLevel);
    } on PostgrestException catch (e, st) {
      print('❌ [PERSIST] PostgrestException during fallback update: ${e.message}');
      return PersistResult.failed(error: e, stackTrace: st);
    } on SocketException catch (e, st) {
      print('❌ [PERSIST] SocketException during fallback update: ${e.message}');
      return PersistResult.failed(error: e, stackTrace: st);
    } on FormatException catch (e, st) {
      print('❌ [PERSIST] FormatException during fallback update: ${e.message}');
      return PersistResult.failed(error: e, stackTrace: st);
    } catch (e, st) {
      print('❌ [PERSIST] Unexpected error during fallback update: $e');
      return PersistResult.failed(error: e, stackTrace: st);
    }
  }

  /// Grant level-up pack if user crossed a level boundary.
  static Future<void> grantLevelUpPackIfNeeded(String userId, int oldLevel, int newLevel) async {
    await SupabaseService.grantLevelUpPack(userId, oldLevel, newLevel);
  }
}
