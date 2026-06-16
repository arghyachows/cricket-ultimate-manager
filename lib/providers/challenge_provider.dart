import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/supabase_service.dart';
import '../models/challenge_model.dart';
import '../engine/ai_opponent.dart';
import 'card_packs_provider.dart';

/// Provider for the quick match challenge ladder state.
final challengeProvider =
    StateNotifierProvider<ChallengeNotifier, ChallengeState>((ref) {
  return ChallengeNotifier(ref);
});

class ChallengeState {
  final List<ChallengeOpponent> opponents;
  final bool isLoaded;
  final bool allCompleted;
  final int currentOpponentIndex;
  final String? packAwarded;

  const ChallengeState({
    this.opponents = const [],
    this.isLoaded = false,
    this.allCompleted = false,
    this.currentOpponentIndex = 0,
    this.packAwarded,
  });

  ChallengeOpponent? get currentOpponent {
    if (currentOpponentIndex < 0 || currentOpponentIndex >= opponents.length) {
      return null;
    }
    return opponents[currentOpponentIndex];
  }

  /// Next locked opponent (first locked after the current highest unlocked).
  int get nextLockedIndex {
    for (int i = 0; i < opponents.length; i++) {
      if (opponents[i].isLocked) return i;
    }
    return opponents.length; // all are unlocked
  }

  int get defeatedCount => opponents.where((o) => o.isDefeated).length;
  int get totalCount => opponents.length;

  ChallengeState copyWith({
    List<ChallengeOpponent>? opponents,
    bool? isLoaded,
    bool? allCompleted,
    int? currentOpponentIndex,
    String? packAwarded,
    bool clearPackAwarded = false,
  }) {
    return ChallengeState(
      opponents: opponents ?? this.opponents,
      isLoaded: isLoaded ?? this.isLoaded,
      allCompleted: allCompleted ?? this.allCompleted,
      currentOpponentIndex: currentOpponentIndex ?? this.currentOpponentIndex,
      packAwarded: clearPackAwarded ? null : (packAwarded ?? this.packAwarded),
    );
  }
}

class ChallengeNotifier extends StateNotifier<ChallengeState> {
  final Ref ref;
  static final _rng = Random();

  ChallengeNotifier(this.ref) : super(const ChallengeState()) {
    _loadProgress();
  }

  /// Load saved progress from SharedPreferences.
  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final weekNumber = _getWeekNumber();
    final savedWeek = prefs.getInt(ChallengeConfig.weeklyWeekNumberKey) ?? 0;

    if (savedWeek != weekNumber) {
      // New week — reset all progress
      await _resetWeeklyProgress(prefs, weekNumber);
      return;
    }

    final savedJson = prefs.getString(ChallengeConfig.weeklyProgressKey);
    if (savedJson == null || savedJson.isEmpty) {
      // No saved progress — generate fresh opponents
      await _generateNewOpponents(prefs, weekNumber);
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(savedJson);
      final opponents = decoded
          .map((e) => ChallengeOpponent.fromJson(e as Map<String, dynamic>))
          .toList();

      final allDone = opponents.every((o) => o.isDefeated);
      final firstLocked = _findFirstLockedIndex(opponents);

      state = ChallengeState(
        opponents: opponents,
        isLoaded: true,
        allCompleted: allDone,
        currentOpponentIndex: firstLocked > 0 ? firstLocked - 1 : 0,
      );
    } catch (_) {
      await _generateNewOpponents(prefs, weekNumber);
    }
  }

  int _findFirstLockedIndex(List<ChallengeOpponent> opponents) {
    for (int i = 0; i < opponents.length; i++) {
      if (opponents[i].isLocked) return i;
    }
    return opponents.length - 1;
  }

  /// Reset progress for a new week.
  Future<void> _resetWeeklyProgress(
      SharedPreferences prefs, int weekNumber) async {
    await prefs.setInt(ChallengeConfig.weeklyWeekNumberKey, weekNumber);
    await _generateNewOpponents(prefs, weekNumber);
  }

  /// Generate fresh opponent ladder.
  Future<void> _generateNewOpponents(
      SharedPreferences prefs, int weekNumber) async {
    final opponents = <ChallengeOpponent>[];
    final usedNames = <String>{};

    int opponentIndex = 0;
    for (final tier in ChallengeConfig.tiers) {
      for (int j = 0; j < ChallengeConfig.opponentsPerTier; j++) {
        String teamName;
        do {
          teamName = AIOpponent.randomTeamName();
        } while (usedNames.contains(teamName));
        usedNames.add(teamName);

        final chemistry = 30 + _rng.nextInt(51); // 30-80
        final rating =
            tier.aiTeamRatingMin + _rng.nextInt(tier.aiTeamRatingMax - tier.aiTeamRatingMin + 1);

        final isFirst = opponentIndex == 0;

        opponents.add(ChallengeOpponent(
          index: opponentIndex,
          tierName: tier.name,
          difficulty: tier.difficulty,
          teamName: teamName,
          chemistry: chemistry,
          rating: rating,
          isDefeated: false,
          isLocked: !isFirst,
        ));
        opponentIndex++;
      }
    }

    // Persist
    final jsonList = opponents.map((o) => o.toJson()).toList();
    await prefs.setString(ChallengeConfig.weeklyProgressKey, jsonEncode(jsonList));
    await prefs.setInt(ChallengeConfig.weeklyWeekNumberKey, weekNumber);

    state = ChallengeState(
      opponents: opponents,
      isLoaded: true,
      allCompleted: false,
      currentOpponentIndex: 0,
    );
  }

  /// Mark the current opponent as defeated and unlock the next.
  Future<void> markCurrentAsDefeated(ChallengeOpponent opponent) async {
    final updated = <ChallengeOpponent>[];
    bool found = false;

    for (final o in state.opponents) {
      if (o.index == opponent.index && !o.isDefeated) {
        found = true;
        // Mark this opponent as defeated
        updated.add(o.copyWith(isDefeated: true));
      } else if (found && o.isLocked && !o.isDefeated) {
        // Unlock the next one (first locked after current)
        updated.add(o.copyWith(isLocked: false));
        found = false; // only unlock one
      } else {
        updated.add(o);
      }
    }

    // Check if all are done
    final allDone = updated.every((o) => o.isDefeated);
    final nextIndex = allDone
        ? updated.length - 1
        : _findNextUnbeatenIndex(updated);

    String? awardedPack;
    if (allDone) {
      awardedPack = ChallengeConfig.completionPack;
      await _awardCompletionPack();
    }

    // Persist
    final prefs = await SharedPreferences.getInstance();
    final jsonList = updated.map((o) => o.toJson()).toList();
    await prefs.setString(ChallengeConfig.weeklyProgressKey, jsonEncode(jsonList));

    state = ChallengeState(
      opponents: updated,
      isLoaded: true,
      allCompleted: allDone,
      currentOpponentIndex: nextIndex,
      packAwarded: awardedPack,
    );
  }

  int _findNextUnbeatenIndex(List<ChallengeOpponent> opponents) {
    for (int i = 0; i < opponents.length; i++) {
      if (!opponents[i].isDefeated) return i;
    }
    return opponents.length - 1;
  }

  /// Award the Elite Pack when all challenges are completed.
  Future<void> _awardCompletionPack() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Insert an Elite Pack into user_card_packs table
      await SupabaseService.client.from('user_card_packs').insert({
        'user_id': userId,
        'pack_name': ChallengeConfig.completionPack,
        'card_count': 5,
        'bronze_chance': 5,
        'silver_chance': 15,
        'gold_chance': 35,
        'elite_chance': 30,
        'legend_chance': 15,
        'opened': false,
        'source': 'challenge_reward',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Refresh packs
      ref.read(userCardPacksProvider.notifier).refresh();
    } catch (e) {
      Log.e('Failed to award challenge pack', e);
    }
  }

  /// Clear the pack awarded flag (after user sees it).
  void clearPackAwarded() {
    state = state.copyWith(clearPackAwarded: true);
  }

  /// Reset the entire challenge manually (for debugging or forced reset).
  Future<void> resetChallenges() async {
    final weekNumber = _getWeekNumber();
    final prefs = await SharedPreferences.getInstance();
    await _generateNewOpponents(prefs, weekNumber);
  }

  static int _getWeekNumber() {
    final now = DateTime.now();
    // Calculate ISO week number
    final startOfYear = DateTime(now.year, 1, 1);
    final days = now.difference(startOfYear).inDays;
    return ((startOfYear.weekday <= 4 ? 1 : 0) + days + startOfYear.weekday - 1) ~/ 7 + 1;
  }
}

