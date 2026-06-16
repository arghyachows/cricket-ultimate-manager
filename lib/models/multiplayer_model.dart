import 'enums.dart';

class MultiplayerRoom {
  final String id;
  final String roomName;
  final String roomCode;
  final int maxPlayers;
  final DateTime createdAt;

  const MultiplayerRoom({
    required this.id,
    required this.roomName,
    required this.roomCode,
    required this.maxPlayers,
    required this.createdAt,
  });

  factory MultiplayerRoom.fromJson(Map<String, dynamic> json) {
    return MultiplayerRoom(
      id: json['id'],
      roomName: json['room_name'],
      roomCode: json['room_code'],
      maxPlayers: json['max_players'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_name': roomName,
        'room_code': roomCode,
        'max_players': maxPlayers,
        'created_at': createdAt.toIso8601String(),
      };
}

class RoomPresence {
  final String id;
  final String roomId;
  final String userId;
  final String teamId;
  final String teamName;
  final int userLevel;
  final DateTime joinedAt;
  final DateTime lastSeen;

  const RoomPresence({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.userLevel,
    required this.joinedAt,
    required this.lastSeen,
  });

  factory RoomPresence.fromJson(Map<String, dynamic> json) {
    return RoomPresence(
      id: json['id'],
      roomId: json['room_id'],
      userId: json['user_id'],
      teamId: json['team_id'],
      teamName: json['team_name'],
      userLevel: json['user_level'] ?? 1,
      joinedAt: DateTime.parse(json['joined_at']),
      lastSeen: DateTime.parse(json['last_seen']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'user_id': userId,
        'team_id': teamId,
        'team_name': teamName,
        'user_level': userLevel,
        'joined_at': joinedAt.toIso8601String(),
        'last_seen': lastSeen.toIso8601String(),
      };
}

class MatchChallenge {
  final String id;
  final String roomId;
  final String challengerId;
  final String challengedId;
  final String challengerTeamId;
  final String challengedTeamId;
  final ChallengeStatus status;
  final String matchFormat;
  final int matchOvers;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  
  // Additional fields from joins
  final String? challengerName;
  final String? challengedName;
  final String? challengerTeamName;
  final String? challengedTeamName;

  const MatchChallenge({
    required this.id,
    required this.roomId,
    required this.challengerId,
    required this.challengedId,
    required this.challengerTeamId,
    required this.challengedTeamId,
    required this.status,
    required this.matchFormat,
    required this.matchOvers,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
    this.challengerName,
    this.challengedName,
    this.challengerTeamName,
    this.challengedTeamName,
  });

  factory MatchChallenge.fromJson(Map<String, dynamic> json) {
    return MatchChallenge(
      id: json['id'],
      roomId: json['room_id'],
      challengerId: json['challenger_id'],
      challengedId: json['challenged_id'],
      challengerTeamId: json['challenger_team_id'],
      challengedTeamId: json['challenged_team_id'],
      status: ChallengeStatus.fromValue(json['status'] as String?),
      matchFormat: json['match_format'] as String? ?? '',
      matchOvers: json['match_overs'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at']) : null,
      challengerName: json['challenger_name'],
      challengedName: json['challenged_name'],
      challengerTeamName: json['challenger_team_name'],
      challengedTeamName: json['challenged_team_name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'challenger_id': challengerId,
        'challenged_id': challengedId,
        'challenger_team_id': challengerTeamId,
        'challenged_team_id': challengedTeamId,
        'status': status.value,
        'match_format': matchFormat,
        'match_overs': matchOvers,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
      };

  bool get isPending => status == ChallengeStatus.pending;
  bool get isExpired => status == ChallengeStatus.expired || DateTime.now().isAfter(expiresAt);
}
