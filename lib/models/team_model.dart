import 'user_card.dart';

class Team {
  final String id;
  final String userId;
  final String teamName;
  final String? logoUrl;
  final int chemistry;
  final int overallRating;
  final bool isActive;
  final List<Squad> squads;

  const Team({
    required this.id,
    required this.userId,
    required this.teamName,
    this.logoUrl,
    this.chemistry = 0,
    this.overallRating = 0,
    this.isActive = true,
    this.squads = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      userId: json['user_id'],
      teamName: json['team_name'],
      logoUrl: json['logo_url'],
      chemistry: json['chemistry'] ?? 0,
      overallRating: json['overall_rating'] ?? 0,
      isActive: json['is_active'] ?? true,
      squads: (json['squads'] as List<dynamic>?)
              ?.map((s) => Squad.fromJson(s))
              .toList() ??
          [],
    );
  }

  Squad? get activeSquad => squads.isEmpty
      ? null
      : squads.firstWhere((s) => s.isActive, orElse: () => squads.first);
}

class Squad {
  final String id;
  final String teamId;
  final String squadName;
  final String formation;
  final bool isActive;
  final List<SquadPlayer> players;       // 30-slot roster
  final List<LineupPlayer> lineup;       // Playing XI (0-11 entries)

  const Squad({
    required this.id,
    required this.teamId,
    required this.squadName,
    this.formation = '4-3-4',
    this.isActive = true,
    this.players = const [],
    this.lineup = const [],
  });

  factory Squad.fromJson(Map<String, dynamic> json) {
    final playersList = (json['squad_players'] as List<dynamic>?)
            ?.map((p) => SquadPlayer.fromJson(p))
            .toList() ??
        [];
    playersList.sort((a, b) => a.position.compareTo(b.position));

    final lineupList = (json['lineup_players'] as List<dynamic>?)
            ?.map((l) => LineupPlayer.fromJson(l))
            .toList() ??
        [];
    lineupList.sort((a, b) => a.battingOrder.compareTo(b.battingOrder));

    return Squad(
      id: json['id'],
      teamId: json['team_id'],
      squadName: json['squad_name'],
      formation: json['formation'] ?? '4-3-4',
      isActive: json['is_active'] ?? true,
      players: playersList,
      lineup: lineupList,
    );
  }

  /// Playing XI as SquadPlayer-like objects for match engine compatibility.
  /// Returns LineupPlayers sorted by batting order.
  List<LineupPlayer> get playingXI => List.from(lineup)
    ..sort((a, b) => a.battingOrder.compareTo(b.battingOrder));

  LineupPlayer? get captain =>
      lineup.where((p) => p.isCaptain).firstOrNull;

  LineupPlayer? get viceCaptain =>
      lineup.where((p) => p.isViceCaptain).firstOrNull;

  List<LineupPlayer> get bowlers => playingXI
      .where((p) =>
          p.userCard?.playerCard?.role == 'bowler' ||
          p.userCard?.playerCard?.role == 'all_rounder')
      .toList();

  /// Check if a user_card is in the lineup
  bool isInLineup(String userCardId) =>
      lineup.any((l) => l.userCardId == userCardId);
}

/// Pure roster entry — no lineup/batting/captain info.
class SquadPlayer {
  final String id;
  final String squadId;
  final String userCardId;
  final int position;          // 1-30
  final UserCard? userCard;    // Joined data

  const SquadPlayer({
    required this.id,
    required this.squadId,
    required this.userCardId,
    required this.position,
    this.userCard,
  });

  factory SquadPlayer.fromJson(Map<String, dynamic> json) {
    return SquadPlayer(
      id: json['id'],
      squadId: json['squad_id'],
      userCardId: json['user_card_id'],
      position: json['position'],
      userCard: json['user_cards'] != null
          ? UserCard.fromJson(json['user_cards'])
          : null,
    );
  }
}

/// A player in the Playing XI lineup.
class LineupPlayer {
  final String id;
  final String squadId;
  final String userCardId;
  final int battingOrder;      // 1-11
  final bool isCaptain;
  final bool isViceCaptain;
  final UserCard? userCard;    // Joined data

  const LineupPlayer({
    required this.id,
    required this.squadId,
    required this.userCardId,
    required this.battingOrder,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.userCard,
  });

  factory LineupPlayer.fromJson(Map<String, dynamic> json) {
    return LineupPlayer(
      id: json['id'],
      squadId: json['squad_id'],
      userCardId: json['user_card_id'],
      battingOrder: json['batting_order'],
      isCaptain: json['is_captain'] ?? false,
      isViceCaptain: json['is_vice_captain'] ?? false,
      userCard: json['user_cards'] != null
          ? UserCard.fromJson(json['user_cards'])
          : null,
    );
  }
}
