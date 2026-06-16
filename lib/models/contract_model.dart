import 'enums.dart';

class ContractType {
  final String id;
  final String name;
  final ContractTier tier;
  final int matchesAwarded;
  final String? imageUrl;
  final bool isAvailable;

  const ContractType({
    required this.id,
    required this.name,
    required this.tier,
    required this.matchesAwarded,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory ContractType.fromJson(Map<String, dynamic> json) {
    return ContractType(
      id: json['id'],
      name: json['name'],
      tier: ContractTier.fromValue(json['tier'] as String? ?? 'bronze'),
      matchesAwarded: json['matches_awarded'],
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier.value,
        'matches_awarded': matchesAwarded,
        'image_url': imageUrl,
        'is_available': isAvailable,
      };

  // Helper to get tier color for UI
  int get tierColor => tier.color;

  String get tierDisplayName {
    final s = tier.value;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class UserContract {
  final String id;
  final String userId;
  final String contractTypeId;
  final int quantity;
  final String source; // 'reward', 'purchase', 'tournament', 'market', 'pack', 'level_up'
  final DateTime acquiredAt;
  final ContractType? contractType; // Joined data

  const UserContract({
    required this.id,
    required this.userId,
    required this.contractTypeId,
    required this.quantity,
    required this.source,
    required this.acquiredAt,
    this.contractType,
  });

  factory UserContract.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'] ?? 1;
    if (qty <= 0) {
      throw ArgumentError('UserContract quantity must be > 0, got $qty');
    }
    final tier = json['contract_types'] != null ? json['contract_types']['tier'] as String? : null;
    if (tier != null && !['bronze', 'silver', 'gold', 'elite', 'legend'].contains(tier)) {
      throw ArgumentError('UserContract tier must be one of: bronze/silver/gold/elite/legend, got $tier');
    }
    return UserContract(
      id: json['id'],
      userId: json['user_id'],
      contractTypeId: json['contract_type_id'],
      quantity: qty,
      source: json['source'] ?? 'reward',
      acquiredAt: DateTime.parse(json['acquired_at']),
      contractType: json['contract_types'] != null
          ? ContractType.fromJson(json['contract_types'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'contract_type_id': contractTypeId,
        'quantity': quantity,
        'source': source,
        'acquired_at': acquiredAt.toIso8601String(),
      };

  UserContract copyWith({
    String? id,
    String? userId,
    String? contractTypeId,
    int? quantity,
    String? source,
    DateTime? acquiredAt,
    ContractType? contractType,
  }) {
    return UserContract(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contractTypeId: contractTypeId ?? this.contractTypeId,
      quantity: quantity ?? this.quantity,
      source: source ?? this.source,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      contractType: contractType ?? this.contractType,
    );
  }

  int get matchesAwarded => contractType?.matchesAwarded ?? 0;
  ContractTier get tier => contractType?.tier ?? ContractTier.bronze;
  String get name => contractType?.name ?? 'Unknown Contract';
}

class UserContractPack {
  final String id;
  final String userId;
  final String packName;
  final int contractCount;
  final double bronzeChance;
  final double silverChance;
  final double goldChance;
  final double eliteChance;
  final double legendChance;
  final String source; // 'reward', 'purchase', 'tournament', 'level_up'
  final bool opened;
  final DateTime createdAt;

  const UserContractPack({
    required this.id,
    required this.userId,
    required this.packName,
    this.contractCount = 3,
    this.bronzeChance = 60,
    this.silverChance = 25,
    this.goldChance = 10,
    this.eliteChance = 4,
    this.legendChance = 1,
    this.source = 'reward',
    this.opened = false,
    required this.createdAt,
  });

  factory UserContractPack.fromJson(Map<String, dynamic> json) {
    return UserContractPack(
      id: json['id'],
      userId: json['user_id'],
      packName: json['pack_name'],
      contractCount: json['contract_count'] ?? 3,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'pack_name': packName,
        'contract_count': contractCount,
        'bronze_chance': bronzeChance,
        'silver_chance': silverChance,
        'gold_chance': goldChance,
        'elite_chance': eliteChance,
        'legend_chance': legendChance,
        'source': source,
        'opened': opened,
        'created_at': createdAt.toIso8601String(),
      };

  // Pick a random rarity based on pack probabilities
  String pickRarity() {
    final rand = (DateTime.now().millisecondsSinceEpoch % 10000) / 10000.0 * 100;
    double cumulative = 0;

    cumulative += legendChance;
    if (rand < cumulative) return 'legend';

    cumulative += eliteChance;
    if (rand < cumulative) return 'elite';

    cumulative += goldChance;
    if (rand < cumulative) return 'gold';

    cumulative += silverChance;
    if (rand < cumulative) return 'silver';

    return 'bronze';
  }

  UserContractPack copyWith({
    String? id,
    String? userId,
    String? packName,
    int? contractCount,
    double? bronzeChance,
    double? silverChance,
    double? goldChance,
    double? eliteChance,
    double? legendChance,
    String? source,
    bool? opened,
    DateTime? createdAt,
  }) {
    return UserContractPack(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packName: packName ?? this.packName,
      contractCount: contractCount ?? this.contractCount,
      bronzeChance: bronzeChance ?? this.bronzeChance,
      silverChance: silverChance ?? this.silverChance,
      goldChance: goldChance ?? this.goldChance,
      eliteChance: eliteChance ?? this.eliteChance,
      legendChance: legendChance ?? this.legendChance,
      source: source ?? this.source,
      opened: opened ?? this.opened,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}