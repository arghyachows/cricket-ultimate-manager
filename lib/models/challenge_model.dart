/// Model for Quick Match Challenge tier data.
class ChallengeTier {
  final String name;
  final String difficulty;
  final int aiTeamRatingMin;
  final int aiTeamRatingMax;

  const ChallengeTier({
    required this.name,
    required this.difficulty,
    required this.aiTeamRatingMin,
    required this.aiTeamRatingMax,
  });
}

/// Represents one challenge opponent in the ladder.
class ChallengeOpponent {
  final int index;
  final String tierName;
  final String difficulty;
  final String teamName;
  final int chemistry;
  final int rating;
  final bool isDefeated;
  final bool isLocked;

  const ChallengeOpponent({
    required this.index,
    required this.tierName,
    required this.difficulty,
    required this.teamName,
    required this.chemistry,
    required this.rating,
    this.isDefeated = false,
    this.isLocked = true,
  });

  ChallengeOpponent copyWith({
    int? index,
    String? tierName,
    String? difficulty,
    String? teamName,
    int? chemistry,
    int? rating,
    bool? isDefeated,
    bool? isLocked,
  }) {
    return ChallengeOpponent(
      index: index ?? this.index,
      tierName: tierName ?? this.tierName,
      difficulty: difficulty ?? this.difficulty,
      teamName: teamName ?? this.teamName,
      chemistry: chemistry ?? this.chemistry,
      rating: rating ?? this.rating,
      isDefeated: isDefeated ?? this.isDefeated,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'tierName': tierName,
    'difficulty': difficulty,
    'teamName': teamName,
    'chemistry': chemistry,
    'rating': rating,
    'isDefeated': isDefeated,
    'isLocked': isLocked,
  };

  factory ChallengeOpponent.fromJson(Map<String, dynamic> json) {
    return ChallengeOpponent(
      index: json['index'] as int,
      tierName: json['tierName'] as String,
      difficulty: json['difficulty'] as String,
      teamName: json['teamName'] as String,
      chemistry: json['chemistry'] as int,
      rating: json['rating'] as int,
      isDefeated: json['isDefeated'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? true,
    );
  }
}

/// All challenge tiers defining the progression ladder.
/// Starts from easier Village opponents and escalates to International.
class ChallengeConfig {
  static const List<ChallengeTier> tiers = [
    ChallengeTier(
      name: 'Rookie',
      difficulty: 'Village',
      aiTeamRatingMin: 55,
      aiTeamRatingMax: 65,
    ),
    ChallengeTier(
      name: 'Amateur',
      difficulty: 'Village',
      aiTeamRatingMin: 65,
      aiTeamRatingMax: 72,
    ),
    ChallengeTier(
      name: 'Semi-Pro',
      difficulty: 'Domestic',
      aiTeamRatingMin: 72,
      aiTeamRatingMax: 78,
    ),
    ChallengeTier(
      name: 'Professional',
      difficulty: 'Domestic',
      aiTeamRatingMin: 78,
      aiTeamRatingMax: 84,
    ),
    ChallengeTier(
      name: 'Champion',
      difficulty: 'International',
      aiTeamRatingMin: 84,
      aiTeamRatingMax: 90,
    ),
    ChallengeTier(
      name: 'Elite',
      difficulty: 'International',
      aiTeamRatingMin: 90,
      aiTeamRatingMax: 97,
    ),
  ];

  static const int opponentsPerTier = 2;
  static int get totalOpponents => opponentsPerTier * tiers.length; // 12

  /// Reward for completing all challenges (Elite Pack).
  static const String completionPack = 'Elite Pack';

  /// Weekly reset key for SharedPreferences.
  static const String weeklyProgressKey = 'challenge_weekly_progress';
  static const String weeklyWeekNumberKey = 'challenge_week_number';
}