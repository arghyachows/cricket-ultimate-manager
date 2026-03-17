class UserCardPack {
  final String id;
  final String userId;
  final String packName;
  final int cardCount;
  final double bronzeChance;
  final double silverChance;
  final double goldChance;
  final double eliteChance;
  final double legendChance;
  final String source;
  final bool opened;
  final DateTime createdAt;

  const UserCardPack({
    required this.id,
    required this.userId,
    required this.packName,
    this.cardCount = 3,
    this.bronzeChance = 60,
    this.silverChance = 25,
    this.goldChance = 10,
    this.eliteChance = 4,
    this.legendChance = 1,
    this.source = 'reward',
    this.opened = false,
    required this.createdAt,
  });

  factory UserCardPack.fromJson(Map<String, dynamic> json) {
    return UserCardPack(
      id: json['id'],
      userId: json['user_id'],
      packName: json['pack_name'],
      cardCount: json['card_count'] ?? 3,
      bronzeChance: (json['bronze_chance'] ?? 60).toDouble(),
      silverChance: (json['silver_chance'] ?? 25).toDouble(),
      goldChance: (json['gold_chance'] ?? 10).toDouble(),
      eliteChance: (json['elite_chance'] ?? 4).toDouble(),
      legendChance: (json['legend_chance'] ?? 1).toDouble(),
      source: json['source'] ?? 'reward',
      opened: json['opened'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
