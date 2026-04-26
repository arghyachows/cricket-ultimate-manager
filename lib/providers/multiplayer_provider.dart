import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'team_provider.dart';
import 'match_provider.dart';

final multiplayerProvider = StateNotifierProvider<MultiplayerNotifier, MultiplayerState>((ref) {
  return MultiplayerNotifier(ref);
});

/// Checks DB for any active (waiting/in_progress) multiplayer match for the current user.
/// Returns the match row map, or null if no active/recent match.
final activeMultiplayerMatchProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;

  final active = await SupabaseService.client
      .from('multiplayer_matches')
      .select()
      .or('home_user_id.eq.$userId,away_user_id.eq.$userId')
      .inFilter('status', ['waiting', 'in_progress'])
      .order('created_at', ascending: false)
      .limit(1);

  if (active.isNotEmpty) {
    return active.first;
  }
  return null;
});

class MultiplayerState {
  final List<MultiplayerRoom> rooms;
  final MultiplayerRoom? currentRoom;
  final List<RoomPresence> usersInRoom;
  final List<MatchChallenge> pendingChallenges;
  final List<LobbyChatMessage> chatMessages;
  final bool isLoading;
  final String? error;
  final bool isConnected;
  final String? matchStartedId;

  const MultiplayerState({
    this.rooms = const [],
    this.currentRoom,
    this.usersInRoom = const [],
    this.pendingChallenges = const [],
    this.chatMessages = const [],
    this.isLoading = false,
    this.error,
    this.isConnected = false,
    this.matchStartedId,
  });

  MultiplayerState copyWith({
    List<MultiplayerRoom>? rooms,
    MultiplayerRoom? currentRoom,
    List<RoomPresence>? usersInRoom,
    List<MatchChallenge>? pendingChallenges,
    List<LobbyChatMessage>? chatMessages,
    bool? isLoading,
    String? error,
    bool? isConnected,
    String? matchStartedId,
  }) {
    return MultiplayerState(
      rooms: rooms ?? this.rooms,
      currentRoom: currentRoom ?? this.currentRoom,
      usersInRoom: usersInRoom ?? this.usersInRoom,
      pendingChallenges: pendingChallenges ?? this.pendingChallenges,
      chatMessages: chatMessages ?? this.chatMessages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConnected: isConnected ?? this.isConnected,
      matchStartedId: matchStartedId ?? this.matchStartedId,
    );
  }
}

class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  final Ref ref;
  RealtimeChannel? _roomChannel;
  Timer? _heartbeatTimer;
  String? _currentPresenceId;
  static const Duration _presenceFreshnessWindow = Duration(seconds: 35);

  MultiplayerNotifier(this.ref) : super(const MultiplayerState());

  List<RoomPresence> _normalizeUsersInRoom(List<RoomPresence> users) {
    final nowUtc = DateTime.now().toUtc();
    final latestByUserId = <String, RoomPresence>{};

    for (final user in users) {
      final lastSeenUtc = user.lastSeen.toUtc();
      if (nowUtc.difference(lastSeenUtc) > _presenceFreshnessWindow) {
        continue;
      }

      final existing = latestByUserId[user.userId];
      if (existing == null || user.joinedAt.isAfter(existing.joinedAt)) {
        latestByUserId[user.userId] = user;
      }
    }

    final normalized = latestByUserId.values.toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return normalized;
  }

  Future<void> loadRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await SupabaseService.client
          .from('multiplayer_rooms')
          .select()
          .order('created_at');
      
      final rooms = (data as List).map((json) => MultiplayerRoom.fromJson(json)).toList();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refreshRoom() async {
    if (state.currentRoom == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        _loadRoomUsers(state.currentRoom!.id),
        _loadPendingChallenges(),
        _loadChatHistory(state.currentRoom!.id),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = state.copyWith(error: 'User not authenticated');
        return;
      }

      var user = ref.read(currentUserProvider).valueOrNull;
      var team = ref.read(teamProvider).valueOrNull;

      if (user == null || team == null) {
        state = state.copyWith(error: 'User or team data not available.');
        return;
      }

      await leaveRoom();

      final room = state.rooms.firstWhere((r) => r.id == roomId);
      state = state.copyWith(currentRoom: room, isLoading: true);

      await SupabaseService.client
          .from('room_presence')
          .delete()
          .eq('user_id', userId);

      final presence = await SupabaseService.client
          .from('room_presence')
          .insert({
            'room_id': roomId,
            'user_id': userId,
            'team_id': team.id,
            'team_name': team.teamName,
            'user_level': user.level,
          })
          .select()
          .single();

      _currentPresenceId = presence['id'];

      await refreshRoom();
      await _setupRealtimeChannel(roomId, userId);
      _startHeartbeat();

      state = state.copyWith(isLoading: false, isConnected: true);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> _setupRealtimeChannel(String roomId, String userId) async {
    await _roomChannel?.unsubscribe();
    _roomChannel = SupabaseService.client.channel('multiplayer_room_$roomId');

    _roomChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_presence',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) => _loadRoomUsers(roomId),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'multiplayer_chats',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (payload) => _handleNewChatMessage(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'match_challenges',
          callback: (payload) => _loadPendingChallenges(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'multiplayer_matches',
          callback: (payload) => _handleMatchCreated(payload.newRecord, userId),
        );

    await _roomChannel!.subscribe();
  }

  void _handleMatchCreated(Map<String, dynamic> data, String userId) {
    final homeUserId = data['home_user_id'];
    final awayUserId = data['away_user_id'];
    if (homeUserId == userId || awayUserId == userId) {
      state = state.copyWith(matchStartedId: data['id']);
    }
  }

  void _handleNewChatMessage(Map<String, dynamic> data) {
    try {
      final message = LobbyChatMessage.fromJson(data);
      if (!state.chatMessages.any((m) => m.id == message.id)) {
        state = state.copyWith(chatMessages: [...state.chatMessages, message]);
      }
    } catch (e) {
      print('Chat error: $e');
    }
  }

  Future<void> _loadChatHistory(String roomId) async {
    final data = await SupabaseService.client
        .from('multiplayer_chats')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(50);
    
    final messages = (data as List).map((json) => LobbyChatMessage.fromJson(json)).toList();
    state = state.copyWith(chatMessages: messages);
  }

  Future<void> sendChatMessage(String message) async {
    if (message.trim().isEmpty || state.currentRoom == null) return;
    try {
      final userId = SupabaseService.currentUserId;
      final team = ref.read(teamProvider).valueOrNull;
      if (userId == null || team == null) return;

      await SupabaseService.client.from('multiplayer_chats').insert({
        'room_id': state.currentRoom!.id,
        'user_id': userId,
        'team_name': team.teamName,
        'message': message.trim(),
      });
    } catch (e) {
      state = state.copyWith(error: 'Chat failed: $e');
    }
  }

  void clearMatchStarted() {
    state = state.copyWith(matchStartedId: null);
  }

  Future<void> _loadRoomUsers(String roomId) async {
    final data = await SupabaseService.client
        .from('room_presence')
        .select()
        .eq('room_id', roomId)
        .order('joined_at');

    final users = _normalizeUsersInRoom(
      (data as List).map((json) => RoomPresence.fromJson(json)).toList(),
    );
    state = state.copyWith(usersInRoom: users);
  }

  Future<void> _loadPendingChallenges() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final data = await SupabaseService.client
        .from('match_challenges')
        .select('*, challenger:challenger_id(username)')
        .eq('challenged_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final challenges = (data as List).map((json) => MatchChallenge.fromJson(json)).toList();
    state = state.copyWith(pendingChallenges: challenges);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_currentPresenceId != null) {
        try {
          await SupabaseService.client
              .from('room_presence')
              .update({'last_seen': DateTime.now().toIso8601String()})
              .eq('id', _currentPresenceId!);
        } catch (_) {}
      }
    });
  }

  Future<void> sendChallenge(String targetUserId, String targetTeamId, int overs) async {
    try {
      final userId = SupabaseService.currentUserId;
      final team = ref.read(teamProvider).valueOrNull;
      if (userId == null || team == null || state.currentRoom == null) return;

      await SupabaseService.client.from('match_challenges').insert({
        'room_id': state.currentRoom!.id,
        'challenger_id': userId,
        'challenged_id': targetUserId,
        'challenger_team_id': team.id,
        'challenged_team_id': targetTeamId,
        'match_overs': overs,
        'match_format': overs >= 20 ? 't20' : 'quick',
      });
    } catch (e) {
      state = state.copyWith(error: 'Challenge failed: $e');
    }
  }

  Future<void> respondToChallenge(String challengeId, bool accept) async {
    try {
      if (accept) {
        final challengeData = await SupabaseService.client
            .from('match_challenges')
            .select()
            .eq('id', challengeId)
            .single();

        final userId = SupabaseService.currentUserId;
        final team = ref.read(teamProvider).valueOrNull;
        final homePresence = state.usersInRoom.firstWhere((u) => u.userId == challengeData['challenger_id'], orElse: () => null as RoomPresence);

        final match = await SupabaseService.client.from('multiplayer_matches').insert({
          'challenge_id': challengeId,
          'home_user_id': challengeData['challenger_id'],
          'away_user_id': challengeData['challenged_id'],
          'home_team_id': challengeData['challenger_team_id'],
          'away_team_id': challengeData['challenged_team_id'],
          'home_team_name': homePresence?.teamName ?? 'Home',
          'away_team_name': team?.teamName ?? 'Away',
          'match_format': challengeData['match_format'],
          'match_overs': challengeData['match_overs'],
          'status': 'waiting',
        }).select().single();

        state = state.copyWith(matchStartedId: match['id']);

        await SupabaseService.client
            .from('match_challenges')
            .update({
              'status': 'accepted', 
              'responded_at': DateTime.now().toUtc().toIso8601String()
            })
            .eq('id', challengeId);
      } else {
        await SupabaseService.client
            .from('match_challenges')
            .update({'status': 'declined', 'responded_at': DateTime.now().toIso8601String()})
            .eq('id', challengeId);
      }
      _loadPendingChallenges();
    } catch (e) {
      print('Error responding to challenge: $e');
      state = state.copyWith(error: 'Failed to respond: $e');
    }
  }

  Future<void> leaveRoom() async {
    _heartbeatTimer?.cancel();
    await _roomChannel?.unsubscribe();
    _roomChannel = null;

    if (_currentPresenceId != null) {
      await SupabaseService.client.from('room_presence').delete().eq('id', _currentPresenceId!);
      _currentPresenceId = null;
    }

    state = state.copyWith(
      currentRoom: null,
      usersInRoom: [],
      pendingChallenges: [],
      isConnected: false,
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _roomChannel?.unsubscribe();
    super.dispose();
  }
}

// ─── Multiplayer Match History Provider ─────────────────────────────────────

/// Fetches all completed multiplayer matches for the current user from the DB.
final multiplayerMatchHistoryProvider =
    FutureProvider.autoDispose<List<MatchSummary>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.client
      .from('multiplayer_matches')
      .select()
      .or('home_user_id.eq.$userId,away_user_id.eq.$userId')
      .eq('status', 'completed')
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List).map<MatchSummary>((m) {
    final isHome = m['home_user_id'] == userId;
    final winnerId = m['winner_user_id'];
    bool? homeWon;
    if (winnerId != null) {
      homeWon = winnerId == m['home_user_id'];
    }
    final userWon = (isHome && homeWon == true) || (!isHome && homeWon == false);

    // Deserialize scorecard
    Map<String, BatsmanStats> batsmanStats = {};
    Map<String, BowlerStats> bowlerStats = {};
    final sc = m['scorecard_data'];
    if (sc != null && sc is Map<String, dynamic>) {
      final batsmen = sc['batsmen'] as Map<String, dynamic>? ?? {};
      for (final e in batsmen.entries) {
        final b = e.value as Map<String, dynamic>;
        batsmanStats[e.key] = BatsmanStats(
          name: b['name'] as String? ?? '',
          innings: b['innings'] as int? ?? 1,
          battingOrder: b['battingOrder'] as int? ?? 99,
          runs: b['runs'] as int? ?? 0,
          balls: b['balls'] as int? ?? 0,
          fours: b['fours'] as int? ?? 0,
          sixes: b['sixes'] as int? ?? 0,
          isOut: b['isOut'] as bool? ?? false,
          dismissalType: b['dismissalType'] as String?,
        );
      }
      final bowlers = sc['bowlers'] as Map<String, dynamic>? ?? {};
      for (final e in bowlers.entries) {
        final b = e.value as Map<String, dynamic>;
        bowlerStats[e.key] = BowlerStats(
          name: b['name'] as String? ?? '',
          innings: b['innings'] as int? ?? 1,
          overs: (b['overs'] as num? ?? 0).toInt(),
          balls: (b['balls'] as num? ?? 0).toInt(),
          runs: (b['runs'] as num? ?? 0).toInt(),
          wickets: (b['wickets'] as num? ?? 0).toInt(),
        );
      }
    }

    return MatchSummary(
      homeTeamName: m['home_team_name'] ?? 'Home',
      awayTeamName: m['away_team_name'] ?? 'Away',
      format: m['match_format'] ?? 't20',
      homeScore: m['home_score'] ?? 0,
      homeWickets: m['home_wickets'] ?? 0,
      homeOvers: m['home_overs']?.toString() ?? '0.0',
      awayScore: m['away_score'] ?? 0,
      awayWickets: m['away_wickets'] ?? 0,
      awayOvers: m['away_overs']?.toString() ?? '0.0',
      homeWon: homeWon,
      coinsAwarded: 0,
      xpAwarded: 0,
      playedAt: DateTime.parse(m['created_at']),
      batsmanStats: batsmanStats,
      bowlerStats: bowlerStats,
      events: const [],
      homeBatsFirst: true,
    );
  }).toList();
});
