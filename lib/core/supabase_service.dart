import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    var query = client
        .from('transfer_market')
        .select('*, user_cards(*, player_cards(*)), users!seller_id(username)')
        .eq('status', 'active');

    return await query.order('created_at', ascending: false);
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

  /// Subscribe to squad_players changes (team updates)
  static RealtimeChannel subscribeToSquad(
      String userId, void Function() onUpdate) {
    return client
        .channel('squad_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'squad_players',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  // ---- MATCHES ----
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
        .gt('matches_played', 0)
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
}
