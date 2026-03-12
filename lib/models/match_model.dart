class MatchModel {
  final String id;
  final String homeTeamId;
  final String awayTeamId;
  final String homeUserId;
  final String? awayUserId;
  final String format;
  final String status;
  final String pitchCondition;
  final String? tossWinner;
  final String? tossDecision;
  final int homeScore;
  final int homeWickets;
  final double homeOvers;
  final int awayScore;
  final int awayWickets;
  final double awayOvers;
  final String? winnerTeamId;
  final String? winnerUserId;
  final int homeChemistry;
  final int awayChemistry;
  final int coinsReward;
  final int xpReward;
  final DateTime createdAt;

  const MatchModel({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeUserId,
    this.awayUserId,
    this.format = 't20',
    this.status = 'pending',
    this.pitchCondition = 'balanced',
    this.tossWinner,
    this.tossDecision,
    this.homeScore = 0,
    this.homeWickets = 0,
    this.homeOvers = 0,
    this.awayScore = 0,
    this.awayWickets = 0,
    this.awayOvers = 0,
    this.winnerTeamId,
    this.winnerUserId,
    this.homeChemistry = 0,
    this.awayChemistry = 0,
    this.coinsReward = 0,
    this.xpReward = 0,
    required this.createdAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      homeTeamId: json['home_team_id'],
      awayTeamId: json['away_team_id'],
      homeUserId: json['home_user_id'],
      awayUserId: json['away_user_id'],
      format: json['format'] ?? 't20',
      status: json['status'] ?? 'pending',
      pitchCondition: json['pitch_condition'] ?? 'balanced',
      tossWinner: json['toss_winner'],
      tossDecision: json['toss_decision'],
      homeScore: json['home_score'] ?? 0,
      homeWickets: json['home_wickets'] ?? 0,
      homeOvers: (json['home_overs'] ?? 0).toDouble(),
      awayScore: json['away_score'] ?? 0,
      awayWickets: json['away_wickets'] ?? 0,
      awayOvers: (json['away_overs'] ?? 0).toDouble(),
      winnerTeamId: json['winner_team_id'],
      winnerUserId: json['winner_user_id'],
      homeChemistry: json['home_chemistry'] ?? 0,
      awayChemistry: json['away_chemistry'] ?? 0,
      coinsReward: json['coins_reward'] ?? 0,
      xpReward: json['xp_reward'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get homeScoreDisplay => '$homeScore/$homeWickets ($homeOvers ov)';
  String get awayScoreDisplay => '$awayScore/$awayWickets ($awayOvers ov)';

  bool get isCompleted => status == 'completed';
  bool get isLive => status == 'in_progress';

  int get maxOvers {
    switch (format) {
      case 't20':
        return 20;
      case 'odi':
        return 50;
      default:
        return 20;
    }
  }
}

class MatchEvent {
  final String id;
  final String matchId;
  final int innings;
  final int overNumber;
  final int ballNumber;
  final String battingTeamId;
  final String bowlingTeamId;
  final String batsmanCardId;
  final String bowlerCardId;
  final String eventType;
  final int runs;
  final bool isBoundary;
  final bool isWicket;
  final String? wicketType;
  final String? fielderCardId;
  final String? commentary;
  final int scoreAfter;
  final int wicketsAfter;

  const MatchEvent({
    required this.id,
    required this.matchId,
    required this.innings,
    required this.overNumber,
    required this.ballNumber,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.batsmanCardId,
    required this.bowlerCardId,
    required this.eventType,
    this.runs = 0,
    this.isBoundary = false,
    this.isWicket = false,
    this.wicketType,
    this.fielderCardId,
    this.commentary,
    this.scoreAfter = 0,
    this.wicketsAfter = 0,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      id: json['id'],
      matchId: json['match_id'],
      innings: json['innings'],
      overNumber: json['over_number'],
      ballNumber: json['ball_number'],
      battingTeamId: json['batting_team_id'],
      bowlingTeamId: json['bowling_team_id'],
      batsmanCardId: json['batsman_card_id'],
      bowlerCardId: json['bowler_card_id'],
      eventType: json['event_type'],
      runs: json['runs'] ?? 0,
      isBoundary: json['is_boundary'] ?? false,
      isWicket: json['is_wicket'] ?? false,
      wicketType: json['wicket_type'],
      fielderCardId: json['fielder_card_id'],
      commentary: json['commentary'],
      scoreAfter: json['score_after'] ?? 0,
      wicketsAfter: json['wickets_after'] ?? 0,
    );
  }

  String get overDisplay => '$overNumber.$ballNumber';
}
