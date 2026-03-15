import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'team_provider.dart';

final multiplayerProvider = StateNotifierProvider<MultiplayerNotifier, MultiplayerState>((ref) {
  return MultiplayerNotifier(ref);
});

class MultiplayerState {
  final List<MultiplayerRoom> rooms;
  final MultiplayerRoom? currentRoom;
  final List<RoomPresence> usersInRoom;
  final List<MatchChallenge> pendingChallenges;
  final bool isLoading;
  final String? error;
  final bool isConnected;
  final String? matchStartedId; // New field to trigger navigation

  const MultiplayerState({
    this.rooms = const [],
    this.currentRoom,
    this.usersInRoom = const [],
    this.pendingChallenges = const [],
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
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConnected: isConnected ?? this.isConnected,
      matchStartedId: matchStartedId,
    );
  }
}

class MultiplayerNotifier extends StateNotifier<MultiplayerState> {
  final Ref ref;
  RealtimeChannel? _roomChannel;
  Timer? _heartbeatTimer;
  String? _currentPresenceId;

  MultiplayerNotifier(this.ref) : super(const MultiplayerState());

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

  Future<void> joinRoom(String roomId) async {
    print('=== JOIN ROOM START ==');
    print('Room ID: $roomId');
    
    try {
      final userId = SupabaseService.currentUserId;
      print('User ID: $userId');
      
      if (userId == null) {
        state = state.copyWith(error: 'User not authenticated');
        print('ERROR: User not authenticated');
        return;
      }

      // Ensure user and team data are loaded before proceeding
      var user = ref.read(currentUserProvider).valueOrNull;
      var team = ref.read(teamProvider).valueOrNull;

      if (user == null) {
        print('User not loaded yet, refreshing...');
        await ref.read(currentUserProvider.notifier).loadUser();
        user = ref.read(currentUserProvider).valueOrNull;
      }
      if (team == null) {
        print('Team not loaded yet, refreshing...');
        await ref.read(teamProvider.notifier).loadTeam();
        team = ref.read(teamProvider).valueOrNull;
      }
      
      print('User: ${user?.username}, Team: ${team?.teamName}');
      
      if (user == null || team == null) {
        state = state.copyWith(error: 'User or team data not available. Please ensure you have created a team.');
        print('ERROR: User or team data not available');
        return;
      }

      // Leave current room if any
      await leaveRoom();

      // Find the room
      final room = state.rooms.firstWhere((r) => r.id == roomId);
      print('Found room: ${room.roomName}');
      state = state.copyWith(currentRoom: room, isLoading: true);

      // Clean up any stale presence for this user across all rooms
      print('Cleaning up stale presence...');
      await SupabaseService.client
          .from('room_presence')
          .delete()
          .eq('user_id', userId);

      // Create presence record in database
      print('Creating presence record...');
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
      print('Presence created: $_currentPresenceId');

      // Load initial room data
      print('Loading room users...');
      await _loadRoomUsers(roomId);
      print('Loaded ${state.usersInRoom.length} users');
      
      print('Loading challenges...');
      await _loadPendingChallenges();
      print('Loaded ${state.pendingChallenges.length} challenges');

      // Setup WebSocket channel for real-time updates
      print('Setting up realtime channel...');
      await _setupRealtimeChannel(roomId, userId);
      print('Realtime channel setup complete');

      // Start heartbeat to keep presence alive
      _startHeartbeat();
      print('Heartbeat started');

      state = state.copyWith(isLoading: false, isConnected: true);
      print('=== JOIN ROOM SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== JOIN ROOM ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(error: e.toString(), isLoading: false, isConnected: false);
    }
  }

  Future<void> _setupRealtimeChannel(String roomId, String userId) async {
    // Unsubscribe from previous channel
    await _roomChannel?.unsubscribe();

    // Create a single channel for all room events
    _roomChannel = SupabaseService.client.channel('multiplayer_room_$roomId');

    // Listen to presence changes (users joining/leaving)
    _roomChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            _handleUserJoined(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'room_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            _handleUserUpdated(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'room_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            _handleUserLeft(payload.oldRecord);
          },
        );

    // Listen to challenges directed at this user
    _roomChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'match_challenges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'challenged_id',
            value: userId,
          ),
          callback: (payload) {
            _handleChallengeReceived(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'match_challenges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'challenger_id',
            value: userId,
          ),
          callback: (payload) {
            _handleChallengeUpdated(payload.newRecord);
          },
        );

    // Listen to multiplayer matches being created
    _roomChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'multiplayer_matches',
          callback: (payload) {
            _handleMatchCreated(payload.newRecord, userId);
          },
        );

    // Subscribe to the channel
    await _roomChannel!.subscribe();
  }

  void _handleUserJoined(Map<String, dynamic> data) {
    try {
      final newUser = RoomPresence.fromJson(data);
      // Check if user already exists (avoid duplicates)
      if (!state.usersInRoom.any((u) => u.id == newUser.id)) {
        final updatedUsers = [...state.usersInRoom, newUser];
        state = state.copyWith(usersInRoom: updatedUsers);
      }
    } catch (e) {
      print('Error handling user joined: $e');
    }
  }

  void _handleUserUpdated(Map<String, dynamic> data) {
    try {
      final updatedUser = RoomPresence.fromJson(data);
      final updatedUsers = state.usersInRoom.map((u) {
        return u.id == updatedUser.id ? updatedUser : u;
      }).toList();
      state = state.copyWith(usersInRoom: updatedUsers);
    } catch (e) {
      print('Error handling user updated: $e');
    }
  }

  void _handleUserLeft(Map<String, dynamic> data) {
    try {
      final deletedId = data['id'];
      final updatedUsers = state.usersInRoom.where((u) => u.id != deletedId).toList();
      state = state.copyWith(usersInRoom: updatedUsers);
    } catch (e) {
      print('Error handling user left: $e');
    }
  }

  void _handleChallengeReceived(Map<String, dynamic> data) {
    try {
      final challenge = MatchChallenge.fromJson(data);
      if (challenge.status == 'pending') {
        final updatedChallenges = [...state.pendingChallenges, challenge];
        state = state.copyWith(pendingChallenges: updatedChallenges);
      }
    } catch (e) {
      print('Error handling challenge received: $e');
    }
  }

  void _handleChallengeUpdated(Map<String, dynamic> data) {
    try {
      final updatedChallenge = MatchChallenge.fromJson(data);
      // Remove from pending if no longer pending
      if (updatedChallenge.status != 'pending') {
        final updatedChallenges = state.pendingChallenges
            .where((c) => c.id != updatedChallenge.id)
            .toList();
        state = state.copyWith(pendingChallenges: updatedChallenges);
      }
    } catch (e) {
      print('Error handling challenge updated: $e');
    }
  }

  void _handleMatchCreated(Map<String, dynamic> data, String userId) {
    try {
      print('Match created event received: $data');
      final matchId = data['id'];
      final homeUserId = data['home_user_id'];
      final awayUserId = data['away_user_id'];
      
      // Check if this user is part of the match
      if (homeUserId == userId || awayUserId == userId) {
        print('User is part of match, triggering navigation');
        // Trigger navigation by setting matchStartedId
        state = state.copyWith(matchStartedId: matchId);
      }
    } catch (e) {
      print('Error handling match created: $e');
    }
  }

  void clearMatchStarted() {
    state = state.copyWith(matchStartedId: null);
  }

  Future<void> _loadRoomUsers(String roomId) async {
    try {
      final data = await SupabaseService.client
          .from('room_presence')
          .select()
          .eq('room_id', roomId)
          .order('joined_at');

      final users = (data as List).map((json) => RoomPresence.fromJson(json)).toList();
      state = state.copyWith(usersInRoom: users);
    } catch (e) {
      print('Error loading room users: $e');
    }
  }

  Future<void> _loadPendingChallenges() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final data = await SupabaseService.client
          .from('match_challenges')
          .select()
          .eq('challenged_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final challenges = (data as List).map((json) => MatchChallenge.fromJson(json)).toList();
      state = state.copyWith(pendingChallenges: challenges);
    } catch (e) {
      print('Error loading challenges: $e');
    }
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
        } catch (e) {
          print('Heartbeat error: $e');
        }
      }
    });
  }

  Future<void> sendChallenge(String targetUserId, String targetTeamId, int overs) async {
    try {
      final userId = SupabaseService.currentUserId;
      final teamAsync = ref.read(teamProvider);
      final team = teamAsync.valueOrNull;
      
      if (userId == null || team == null || state.currentRoom == null) {
        state = state.copyWith(error: 'Cannot send challenge');
        return;
      }

      await SupabaseService.client.from('match_challenges').insert({
        'room_id': state.currentRoom!.id,
        'challenger_id': userId,
        'challenged_id': targetUserId,
        'challenger_team_id': team.id,
        'challenged_team_id': targetTeamId,
        'match_overs': overs,
        'match_format': overs >= 50 ? 'odi' : overs >= 20 ? 't20' : 'quick',
      });
    } catch (e) {
      state = state.copyWith(error: 'Failed to send challenge: $e');
    }
  }

  Future<void> respondToChallenge(String challengeId, bool accept) async {
    try {
      if (accept) {
        // Get challenge details
        final challengeData = await SupabaseService.client
            .from('match_challenges')
            .select()
            .eq('id', challengeId)
            .single();

        // Update challenge status
        await SupabaseService.client
            .from('match_challenges')
            .update({
              'status': 'accepted',
              'responded_at': DateTime.now().toIso8601String(),
            })
            .eq('id', challengeId);

        // Fetch actual team names
        String homeTeamName = 'Home';
        String awayTeamName = 'Away';
        try {
          final homeTeam = await SupabaseService.client
              .from('teams')
              .select('team_name')
              .eq('id', challengeData['challenger_team_id'])
              .single();
          homeTeamName = homeTeam['team_name'] ?? 'Home';
          final awayTeam = await SupabaseService.client
              .from('teams')
              .select('team_name')
              .eq('id', challengeData['challenged_team_id'])
              .single();
          awayTeamName = awayTeam['team_name'] ?? 'Away';
        } catch (_) {}

        // Create multiplayer match
        final match = await SupabaseService.client
            .from('multiplayer_matches')
            .insert({
              'challenge_id': challengeId,
              'home_user_id': challengeData['challenger_id'],
              'away_user_id': challengeData['challenged_id'],
              'home_team_id': challengeData['challenger_team_id'],
              'away_team_id': challengeData['challenged_team_id'],
              'home_team_name': homeTeamName,
              'away_team_name': awayTeamName,
              'match_format': challengeData['match_format'],
              'match_overs': challengeData['match_overs'],
              'status': 'waiting',
            })
            .select()
            .single();

        print('Match created: ${match['id']}');
      } else {
        // Decline challenge
        await SupabaseService.client
            .from('match_challenges')
            .update({
              'status': 'declined',
              'responded_at': DateTime.now().toIso8601String(),
            })
            .eq('id', challengeId);
      }

      // Remove from local state immediately
      final updatedChallenges = state.pendingChallenges
          .where((c) => c.id != challengeId)
          .toList();
      state = state.copyWith(pendingChallenges: updatedChallenges);
    } catch (e) {
      print('Error responding to challenge: $e');
      state = state.copyWith(error: 'Failed to respond to challenge: $e');
    }
  }

  Future<void> refreshRoom() async {
    if (state.currentRoom != null) {
      await _loadRoomUsers(state.currentRoom!.id);
      await _loadPendingChallenges();
    }
  }

  Future<void> leaveRoom() async {
    try {
      // Cancel heartbeat
      _heartbeatTimer?.cancel();
      
      // Unsubscribe from channel
      await _roomChannel?.unsubscribe();
      _roomChannel = null;

      // Delete presence record
      if (_currentPresenceId != null) {
        await SupabaseService.client
            .from('room_presence')
            .delete()
            .eq('id', _currentPresenceId!);
        _currentPresenceId = null;
      }

      // Clear state
      state = state.copyWith(
        currentRoom: null,
        usersInRoom: [],
        pendingChallenges: [],
        isConnected: false,
      );
    } catch (e) {
      print('Error leaving room: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _roomChannel?.unsubscribe();
    super.dispose();
  }
}
