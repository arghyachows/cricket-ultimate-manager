import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'logger.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  // ---- AUTH ----
  static Future<AuthResponse> signUp(String email, String password, String username) async {
    final response = await auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': username},
    );
    if (response.user != null) {
      // Trigger on auth.users creates the row; update it to ensure username is set
      await client.from('users').upsert({
        'id': response.user!.id,
        'username': username,
        'display_name': username,
      });
    }
    return response;
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await auth.signOut(scope: SignOutScope.global);
  }

  static String? get currentUserId => auth.currentUser?.id;
  static bool get isAuthenticated => auth.currentUser != null;

  // ---- USER ----
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final response =
        await client.from('users').select().eq('id', userId).single();
    return response;
  }

  static Future<void> updateUserCoins(int amount) async {
    final userId = currentUserId;
    if (userId == null) return;
    await client
        .from('users')
        .update({'coins': amount})
        .eq('id', userId);
  }

  static Future<void> quickSellCard(String userCardId, int sellPrice) async {
    await client.rpc('quick_sell_card', params: {
      'p_user_card_id': userCardId,
      'p_sell_price': sellPrice,
    });
  }

  static Future<void> deleteUserCard(String userCardId) async {
    await client.from('user_cards').delete().eq('id', userCardId);
  }

  // ---- CARDS ----
  static Future<List<Map<String, dynamic>>> getPlayerCards({
    String? rarity,
    String? role,
  }) async {
    var query = client.from('player_cards').select();
    if (rarity != null) query = query.eq('rarity', rarity);
    if (role != null) query = query.eq('role', role);
    return await query.order('rating', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> getUserCards() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('user_cards')
        .select('*, player_cards:card_id(*)')
        .eq('user_id', userId);
  }

  // ---- PACKS ----
  static Future<List<Map<String, dynamic>>> getPackTypes() async {
    return await client
        .from('pack_types')
        .select()
        .eq('is_available', true);
  }

  // ---- TEAMS ----
  static Future<Map<String, dynamic>?> getActiveTeam() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final result = await client
        .from('teams')
        .select('*, squads(*, squad_players(*, user_cards(*, player_cards(*))), lineup_players(*, user_cards(*, player_cards(*))))')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('position', referencedTable: 'squads.squad_players')
        .order('batting_order', referencedTable: 'squads.lineup_players')
        .maybeSingle();
    return result;
  }

  static Future<Map<String, dynamic>> createTeam(String name) async {
    final userId = currentUserId!;
    final team = await client.from('teams').insert({
      'user_id': userId,
      'team_name': name,
    }).select().single();

    await client.from('squads').insert({
      'team_id': team['id'],
      'squad_name': 'Main Squad',
    });

    return team;
  }

  // ---- TRANSFER MARKET ----
  static Future<List<Map<String, dynamic>>> getMarketListings({
    String? rarity,
    String? role,
    String? sortBy,
    String? listingType, // 'card', 'contract', or null for all
  }) async {
    // Build select string dynamically based on listing type
    // contract_types join only for contract listings to avoid FK errors
    final selectStr = listingType == 'contract'
        ? '*, user_cards(*, player_cards(*)), users!seller_id(username), contract_types!contract_type_id(*)'
        : '*, user_cards(*, player_cards(*)), users!seller_id(username)';

    final baseQuery = client.from('transfer_market')
        .select(selectStr)
        .eq('status', 'active');

    // Apply listing type filter
    dynamic query = listingType != null
        ? baseQuery.eq('listing_type', listingType)
        : baseQuery;

    // Apply sorting
    switch (sortBy) {
      case 'price_asc':
        query = query.order('buy_now_price', ascending: true);
        break;
      case 'price_desc':
        query = query.order('buy_now_price', ascending: false);
        break;
      case 'ending_soon':
        query = query.order('expires_at', ascending: true);
        break;
      case 'newest':
      default:
        query = query.order('created_at', ascending: false);
        break;
    }

    // Filter by rarity/role for card listings only (client-side for now)
    if (rarity != null || role != null) {
      // Complex query needed; filtering done client-side in provider
    }

    return await query;
  }

  static RealtimeChannel subscribeToMarket(
      void Function(Map<String, dynamic>) onUpdate) {
    return client
        .channel('market_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transfer_market',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'market_bids',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to user_cards changes for the given user
  static RealtimeChannel subscribeToUserCards(
      String userId, void Function() onUpdate) {
    return client
        .channel('user_cards_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  /// Subscribe to users table changes for the given user
  static RealtimeChannel subscribeToUser(
      String userId, void Function() onUpdate) {
    return client
        .channel('user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  /// Subscribe to squad_players changes for the given user.
  ///
  /// Filters on `user_id` so the client only receives realtime updates for
  /// squad players that belong to this user's team.  Without this filter every
  /// authenticated client would receive every squad_players change in the
  /// system, which is both a privacy concern and unnecessary network overhead.
  static RealtimeChannel subscribeToSquad(
      String userId, void Function() onUpdate) {
    return client
        .channel('squad_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'squad_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  // ---- MATCHES ----
  static Future<void> grantLevelUpPack(String userId, int oldLevel, int newLevel) async {
    if (newLevel <= oldLevel) return;
    final packName = AppConstants.packNameForLevel(newLevel);
    if (packName == null) return;
    final probs = AppConstants.packProbabilities[packName];
    if (probs == null) return;
    await client.from('user_card_packs').insert({
      'user_id': userId,
      'pack_name': packName,
      'card_count': 3,
      'bronze_chance': (probs['bronze']! * 100),
      'silver_chance': (probs['silver']! * 100),
      'gold_chance': (probs['gold']! * 100),
      'elite_chance': (probs['elite']! * 100),
      'legend_chance': (probs['legend']! * 100),
      'source': 'reward',
      'opened': false,
    });
  }

  static Future<void> grantLevelUpContractPack(String userId, int oldLevel, int newLevel) async {
    if (newLevel <= oldLevel) return;
    try {
      await client.rpc('grant_level_up_contract_pack', params: {
        'p_user_id': userId,
        'p_old_level': oldLevel,
        'p_new_level': newLevel,
      });
    } catch (e) {
      Log.e('Grant level up contract pack failed', e);
    }
  }

  static Future<List<Map<String, dynamic>>> getMatches() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('matches')
        .select()
        .or('home_user_id.eq.$userId,away_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(20);
  }

  static RealtimeChannel subscribeToMatch(
      String matchId, void Function(Map<String, dynamic>) onEvent) {
    return client
        .channel('match_$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'match_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) => onEvent(payload.newRecord),
        )
        .subscribe();
  }

  // ---- LEADERBOARD ----
  static Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    return await client
        .from('users')
        .select('id, username, level, season_tier, season_points, matches_played, matches_won')
        .order('season_points', ascending: false)
        .limit(limit);
  }

  // ---- TOURNAMENTS ----
  static Future<List<Map<String, dynamic>>> getTournaments() async {
    return await client
        .from('tournaments')
        .select('*, tournament_participants(count)')
        .neq('status', 'completed')
        .order('starts_at');
  }

  // ---- DAILY OBJECTIVES ----
  static Future<List<Map<String, dynamic>>> getDailyObjectives() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('daily_objectives')
        .select()
        .eq('user_id', userId)
        .eq('date', DateTime.now().toIso8601String().substring(0, 10));
  }

  // ---- TRANSACTIONS ----
  static Future<List<Map<String, dynamic>>> getTransactions({int limit = 20}) async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  // ---- CONTRACTS ----
  static Future<List<Map<String, dynamic>>> getContractTypes() async {
    return await client
        .from('contract_types')
        .select()
        .eq('is_available', true);
  }

  static Future<List<Map<String, dynamic>>> getUserContracts() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('user_contracts')
        .select('*, contract_types:contract_type_id(*)')
        .eq('user_id', userId)
        .gt('quantity', 0);
  }

  static Future<List<Map<String, dynamic>>> getUserContractPacks() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await client
        .from('user_contract_packs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  static RealtimeChannel subscribeToContracts(
      String userId, void Function() onUpdate) {
    return client
        .channel('user_contracts_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_contracts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToContractPacks(
      String userId, void Function() onUpdate) {
    return client
        .channel('user_contract_packs_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_contract_packs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
