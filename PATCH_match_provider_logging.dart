// PATCH FOR match_provider.dart
// Replace the _persistMatchRewards method with this version that has proper error logging

Future<void> _persistMatchRewards(int coins, int xp, bool won) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) {
    print('❌ [PERSIST] No user ID, cannot persist rewards');
    return;
  }

  print('💾 [PERSIST] Starting reward persistence...');
  print('💾 [PERSIST] User ID: $userId');
  print('💾 [PERSIST] Coins: $coins, XP: $xp, Won: $won');

  // Capture old level from DB before applying rewards
  int oldDbLevel = 1;
  int newDbLevel = 1;
  
  try {
    print('💾 [PERSIST] Calling award_match_rewards RPC...');
    
    // RPC returns jsonb: { old_level, new_level, pack_awarded }
    final result = await SupabaseService.client.rpc('award_match_rewards', params: {
      'p_user_id': userId,
      'p_coins': coins,
      'p_xp': xp,
      'p_won': won,
    });
    
    print('✅ [PERSIST] RPC call successful!');
    print('✅ [PERSIST] Result: $result');
    
    // RPC already inserts the pack atomically — no need to call grantLevelUpPack
    oldDbLevel = (result?['old_level'] as int? ?? 1);
    newDbLevel = (result?['new_level'] as int? ?? 1);
    
    print('✅ [PERSIST] Old level: $oldDbLevel, New level: $newDbLevel');
    
  } catch (error, stackTrace) {
    print('❌ [PERSIST] RPC call failed!');
    print('❌ [PERSIST] Error: $error');
    print('❌ [PERSIST] Stack trace: $stackTrace');
    print('⚠️ [PERSIST] Falling back to manual update...');
    
    // Fallback: direct update using fresh DB values to avoid double-counting
    try {
      print('⚠️ [PERSIST] Fetching current user data...');
      final data = await SupabaseService.getCurrentUser();
      
      if (data == null) {
        print('❌ [PERSIST] Could not fetch user data');
        return;
      }
      
      final dbCoins = (data['coins'] as int? ?? 0);
      final dbXp = (data['xp'] as int? ?? 0);
      final dbMatchesPlayed = (data['matches_played'] as int? ?? 0);
      final dbMatchesWon = (data['matches_won'] as int? ?? 0);
      final dbSeasonPoints = (data['season_points'] as int? ?? 0);
      
      print('⚠️ [PERSIST] Current DB values:');
      print('  - Coins: $dbCoins');
      print('  - XP: $dbXp');
      print('  - Matches Played: $dbMatchesPlayed');
      print('  - Matches Won: $dbMatchesWon');
      print('  - Season Points: $dbSeasonPoints');
      
      oldDbLevel = (dbXp ~/ AppConstants.xpPerLevel) + 1;
      final newXp = dbXp + xp;
      newDbLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
      final clampedLevel = newDbLevel > AppConstants.maxLevel ? AppConstants.maxLevel : newDbLevel;
      
      print('⚠️ [PERSIST] Updating user table directly...');
      print('  - New Coins: ${dbCoins + coins}');
      print('  - New XP: $newXp');
      print('  - New Level: $clampedLevel');
      print('  - New Matches Played: ${dbMatchesPlayed + 1}');
      print('  - New Matches Won: ${won ? dbMatchesWon + 1 : dbMatchesWon}');
      
      await SupabaseService.client.from('users').update({
        'coins': dbCoins + coins,
        'xp': newXp,
        'level': clampedLevel,
        'matches_played': dbMatchesPlayed + 1,
        if (won) 'matches_won': dbMatchesWon + 1,
        'season_points': dbSeasonPoints + (won ? 100 + min(clampedLevel * 5, 200) : 10 + min(clampedLevel, 50)),
      }).eq('id', userId);
      
      print('✅ [PERSIST] Direct update successful!');
      
      // Fallback path: manually grant pack since RPC didn't run
      try {
        if (newDbLevel > oldDbLevel) {
          print('🎁 [PERSIST] Level up detected! Granting pack...');
          await _grantLevelUpPackIfNeeded(userId, oldDbLevel, newDbLevel);
          print('✅ [PERSIST] Pack granted successfully!');
        }
      } catch (packError) {
        print('❌ [PERSIST] Failed to grant pack: $packError');
      }
      
    } catch (fallbackError, fallbackStack) {
      print('❌ [PERSIST] Fallback update also failed!');
      print('❌ [PERSIST] Error: $fallbackError');
      print('❌ [PERSIST] Stack trace: $fallbackStack');
    }
  }

  // Refresh AFTER DB writes complete so we read the updated values
  // Delay ensures the RPC transaction has committed before reading back
  print('🔄 [PERSIST] Refreshing user data...');
  await Future.delayed(const Duration(milliseconds: 800));
  await ref.read(currentUserProvider.notifier).silentRefresh();
  ref.read(userCardPacksProvider.notifier).refresh();
  print('✅ [PERSIST] Refresh complete!');
}
