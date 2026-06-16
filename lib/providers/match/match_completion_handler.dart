import 'dart:io';

import 'package:postgrest/postgrest.dart';
import '../../core/logger.dart';
import '../../core/supabase_service.dart';
import '../../core/constants.dart';
import '../../core/notification_service.dart';
import 'match_state.dart';

/// Result of a contract consumption attempt.
class ContractConsumeResult {
  final bool success;
  final List<Map<String, dynamic>> consumed;
  final List<Map<String, dynamic>> errors;
  final Object? error;
  final StackTrace? stackTrace;

  const ContractConsumeResult({
    required this.success,
    this.consumed = const [],
    this.errors = const [],
    this.error,
    this.stackTrace,
  });

  ContractConsumeResult.failed({this.error, this.stackTrace})
      : success = false,
        consumed = const [],
        errors = const [];

  ContractConsumeResult.succeeded({
    required this.consumed,
    required this.errors,
  }) : success = true,
       error = null,
       stackTrace = null;

  int get totalConsumed => consumed.length;
  int get totalErrors => errors.length;
  List<String> get outOfContractsCardIds => consumed
      .where((c) => c['is_out_of_contracts'] == true)
      .map((c) => c['user_card_id'] as String)
      .toList();
}

/// Result of a reward persistence attempt.
class PersistResult {
  final bool success;
  final int oldLevel;
  final int newLevel;
  final String? contractPackAwarded;
  final Object? error;
  final StackTrace? stackTrace;

  const PersistResult({
    required this.success,
    this.oldLevel = 1,
    this.newLevel = 1,
    this.contractPackAwarded,
    this.error,
    this.stackTrace,
  });

  PersistResult.failed({this.error, this.stackTrace})
      : success = false,
        oldLevel = 1,
        newLevel = 1,
        contractPackAwarded = null;

  PersistResult.succeeded({required this.oldLevel, required this.newLevel, this.contractPackAwarded})
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
    required bool? won,
    required String difficulty,
    bool isMultiplayer = false,
    bool isRanked = false,
  }) async {
    int oldDbLevel = 1;
    int newDbLevel = 1;
    String? contractPackAwarded;

    // Determine contract pack for this match
    final String contractPackName = AppConstants.contractPackForDifficulty(
      difficulty,
      won: won,
      isMultiplayer: isMultiplayer,
      isRanked: isRanked,
    );

    // Attempt 1: RPC call (atomic server-side update)
    try {
      final result = await SupabaseService.client.rpc('award_match_rewards', params: {
        'p_user_id': userId,
        'p_coins': coins,
        'p_xp': xp,
        'p_won': won ?? false, // Draw (null) treated as not-won for coin/XP calc, but RPC handles it
        'p_contract_pack_name': contractPackName.isNotEmpty ? contractPackName : null,
        'p_is_multiplayer': isMultiplayer,
        'p_is_ranked': isRanked,
      });
      oldDbLevel = (result?['old_level'] as int? ?? 1);
      newDbLevel = (result?['new_level'] as int? ?? 1);
      contractPackAwarded = result?['contract_pack_awarded'] as String?;
      return PersistResult.succeeded(oldLevel: oldDbLevel, newLevel: newDbLevel, contractPackAwarded: contractPackAwarded);
    } on PostgrestException catch (e) {
      // Database/query error — log and fall through to fallback
      Log.w('PERSIST: PostgrestException during RPC');
    } on SocketException catch (e) {
      // Network unreachable — log and fall through to fallback
      Log.w('PERSIST: SocketException during RPC');
    } on FormatException catch (e) {
      // Malformed response — log and fall through to fallback
      Log.w('PERSIST: FormatException during RPC');
    } catch (e) {
      // Unknown error — log and fall through to fallback
      Log.w('PERSIST: Unexpected error during RPC');
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
        if (won == true) 'matches_won': dbMatchesWon + 1,
        'season_points': dbSeasonPoints + (won == true ? 100 + (clampedLevel * 5).clamp(0, 200) : 10 + clampedLevel.clamp(0, 50)),
      }).eq('id', userId);

      // Fallback: manually grant contract pack if earned
      if (contractPackName.isNotEmpty) {
        final probs = AppConstants.contractPackProbabilities[contractPackName];
        if (probs != null) {
          await SupabaseService.client.from('user_contract_packs').insert({
            'user_id': userId,
            'pack_name': contractPackName,
            'contract_count': 4,
            'bronze_chance': (probs['bronze']! * 100),
            'silver_chance': (probs['silver']! * 100),
            'gold_chance': (probs['gold']! * 100),
            'elite_chance': (probs['elite']! * 100),
            'legend_chance': (probs['legend']! * 100),
            'source': 'reward',
            'opened': false,
          });
          contractPackAwarded = contractPackName;
        }
      }

      return PersistResult.succeeded(oldLevel: oldDbLevel, newLevel: newDbLevel, contractPackAwarded: contractPackAwarded);
    } on PostgrestException catch (e, st) {
      Log.e('PERSIST: PostgrestException during fallback update');
      return PersistResult.failed(error: e, stackTrace: st);
    } on SocketException catch (e, st) {
      Log.e('PERSIST: SocketException during fallback update');
      return PersistResult.failed(error: e, stackTrace: st);
    } on FormatException catch (e, st) {
      Log.e('PERSIST: FormatException during fallback update');
      return PersistResult.failed(error: e, stackTrace: st);
    } catch (e, st) {
      Log.e('PERSIST: Unexpected error during fallback update', e);
      return PersistResult.failed(error: e, stackTrace: st);
    }
  }

  /// Grant level-up pack if user crossed a level boundary.
  static Future<void> grantLevelUpPackIfNeeded(String userId, int oldLevel, int newLevel) async {
    await SupabaseService.grantLevelUpPack(userId, oldLevel, newLevel);
    await SupabaseService.grantLevelUpContractPack(userId, oldLevel, newLevel);
  }

  /// Consume contracts for user's XI players after match completion.
  /// Called AFTER match simulation but BEFORE reward persistence.
  /// Uses idempotency key to prevent double-spending on retry.
  static Future<ContractConsumeResult> consumeContracts({
    required String userId,
    required String matchId,
    required List<String> userXiCardIds,
    String? idempotencyKey,
  }) async {
    try {
      final result = await SupabaseService.client.rpc(
        'consume_contracts_on_match_completion',
        params: {
          'p_user_id': userId,
          'p_match_id': matchId,
          'p_user_card_ids': userXiCardIds,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );

      final consumed = (result?['consumed'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
      final errors = (result?['errors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();

      return ContractConsumeResult.succeeded(
        consumed: consumed,
        errors: errors,
      );
    } on PostgrestException catch (e, st) {
      Log.e('CONTRACTS: PostgrestException during contract consumption');
      return ContractConsumeResult.failed(error: e, stackTrace: st);
    } on SocketException catch (e, st) {
      Log.e('CONTRACTS: SocketException during contract consumption');
      return ContractConsumeResult.failed(error: e, stackTrace: st);
    } on FormatException catch (e, st) {
      Log.e('CONTRACTS: FormatException during contract consumption');
      return ContractConsumeResult.failed(error: e, stackTrace: st);
    } catch (e, st) {
      Log.e('CONTRACTS: Unexpected error during contract consumption', e);
      return ContractConsumeResult.failed(error: e, stackTrace: st);
    }
  }
}
