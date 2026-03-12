class UserModel {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int coins;
  final int premiumTokens;
  final int xp;
  final int level;
  final String seasonTier;
  final int seasonPoints;
  final int matchesPlayed;
  final int matchesWon;
  final DateTime? lastDailyReward;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.coins = 5000,
    this.premiumTokens = 50,
    this.xp = 0,
    this.level = 1,
    this.seasonTier = 'bronze',
    this.seasonPoints = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.lastDailyReward,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      coins: json['coins'] ?? 5000,
      premiumTokens: json['premium_tokens'] ?? 50,
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      seasonTier: json['season_tier'] ?? 'bronze',
      seasonPoints: json['season_points'] ?? 0,
      matchesPlayed: json['matches_played'] ?? 0,
      matchesWon: json['matches_won'] ?? 0,
      lastDailyReward: json['last_daily_reward'] != null
          ? DateTime.parse(json['last_daily_reward'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'coins': coins,
        'premium_tokens': premiumTokens,
        'xp': xp,
        'level': level,
        'season_tier': seasonTier,
        'season_points': seasonPoints,
        'matches_played': matchesPlayed,
        'matches_won': matchesWon,
      };

  double get winRate =>
      matchesPlayed > 0 ? matchesWon / matchesPlayed * 100 : 0;

  UserModel copyWith({
    int? coins,
    int? premiumTokens,
    int? xp,
    int? level,
    int? seasonPoints,
    int? matchesPlayed,
    int? matchesWon,
  }) {
    return UserModel(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      coins: coins ?? this.coins,
      premiumTokens: premiumTokens ?? this.premiumTokens,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      seasonTier: seasonTier,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      lastDailyReward: lastDailyReward,
      createdAt: createdAt,
    );
  }
}
