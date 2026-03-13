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
  final List<SquadPlayer> players;

  const Squad({
    required this.id,
    required this.teamId,
    required this.squadName,
    this.formation = '4-3-4',
    this.isActive = true,
    this.players = const [],
  });

  factory Squad.fromJson(Map<String, dynamic> json) {
    final playersList = (json['squad_players'] as List<dynamic>?)
            ?.map((p) => SquadPlayer.fromJson(p))
            .toList() ??
        [];
    playersList.sort((a, b) => a.position.compareTo(b.position));
    return Squad(
      id: json['id'],
      teamId: json['team_id'],
      squadName: json['squad_name'],
      formation: json['formation'] ?? '4-3-4',
      isActive: json['is_active'] ?? true,
      players: playersList,
    );
  }

  List<SquadPlayer> get playingXI =>
      players.where((p) => p.isPlayingXI).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  SquadPlayer? get captain =>
      players.where((p) => p.isCaptain).firstOrNull;

  SquadPlayer? get viceCaptain =>
      players.where((p) => p.isViceCaptain).firstOrNull;

  List<SquadPlayer> get bowlers => playingXI
      .where((p) =>
          p.userCard?.playerCard?.role == 'bowler' ||
          p.userCard?.playerCard?.role == 'all_rounder')
      .toList();
}

class SquadPlayer {
  final String id;
  final String squadId;
  final String userCardId;
  final int position;
  final bool isPlayingXI;
  final bool isCaptain;
  final bool isViceCaptain;
  final int? battingOrder;
  final int? bowlingOrder;
  final UserCard? userCard; // Joined data

  const SquadPlayer({
    required this.id,
    required this.squadId,
    required this.userCardId,
    required this.position,
    this.isPlayingXI = false,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.battingOrder,
    this.bowlingOrder,
    this.userCard,
  });

  factory SquadPlayer.fromJson(Map<String, dynamic> json) {
    return SquadPlayer(
      id: json['id'],
      squadId: json['squad_id'],
      userCardId: json['user_card_id'],
      position: json['position'],
      isPlayingXI: json['is_playing_xi'] ?? false,
      isCaptain: json['is_captain'] ?? false,
      isViceCaptain: json['is_vice_captain'] ?? false,
      battingOrder: json['batting_order'],
      bowlingOrder: json['bowling_order'],
      userCard: json['user_cards'] != null
          ? UserCard.fromJson(json['user_cards'])
          : null,
    );
  }
}
