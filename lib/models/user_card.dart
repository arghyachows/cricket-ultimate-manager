import 'player_card.dart';

class UserCard {
  final String id;
  final String userId;
  final String cardId;
  final int level;
  final int xp;
  final int form;
  final int fatigue;
  final int matchesPlayed;
  final int runsScored;
  final int wicketsTaken;
  final bool isTradeable;
  final DateTime acquiredAt;
  final int contractsRemaining;
  final int contractsMax;
  final PlayerCard? playerCard; // Joined data

  const UserCard({
    required this.id,
    required this.userId,
    required this.cardId,
    this.level = 1,
    this.xp = 0,
    this.form = 50,
    this.fatigue = 0,
    this.matchesPlayed = 0,
    this.runsScored = 0,
    this.wicketsTaken = 0,
    this.isTradeable = true,
    required this.acquiredAt,
    this.contractsRemaining = 7,
    this.contractsMax = 7,
    this.playerCard,
  });

  factory UserCard.fromJson(Map<String, dynamic> json) {
    return UserCard(
      id: json['id'],
      userId: json['user_id'],
      cardId: json['card_id'],
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      form: json['form'] ?? 50,
      fatigue: json['fatigue'] ?? 0,
      matchesPlayed: json['matches_played'] ?? 0,
      runsScored: json['runs_scored'] ?? 0,
      wicketsTaken: json['wickets_taken'] ?? 0,
      isTradeable: json['is_tradeable'] ?? true,
      acquiredAt: DateTime.parse(json['acquired_at'] ?? json['created_at']),
      contractsRemaining: json['contracts_remaining'] ?? 7,
      contractsMax: json['contracts_max'] ?? 7,
      playerCard: json['player_cards'] != null
          ? PlayerCard.fromJson(json['player_cards'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'card_id': cardId,
        'level': level,
        'xp': xp,
        'form': form,
        'fatigue': fatigue,
        'matches_played': matchesPlayed,
        'runs_scored': runsScored,
        'wickets_taken': wicketsTaken,
        'is_tradeable': isTradeable,
        'contracts_remaining': contractsRemaining,
        'contracts_max': contractsMax,
      };

  // Effective rating with boosts from level, form, fatigue
  int get effectiveRating {
    if (playerCard == null) return 0;
    final base = playerCard!.rating;
    final levelBonus = (level - 1) * 1;
    final formBonus = ((form - 50) / 10).round();
    final fatiguePenalty = (fatigue / 20).round();
    return (base + levelBonus + formBonus - fatiguePenalty).clamp(1, 99);
  }

  int get effectiveBatting {
    if (playerCard == null) return 0;
    final base = playerCard!.batting;
    final formMod = ((form - 50) / 10).round();
    final fatigueMod = (fatigue / 20).round();
    return (base + formMod - fatigueMod).clamp(1, 99);
  }

  int get effectiveBowling {
    if (playerCard == null) return 0;
    final base = playerCard!.bowling;
    final formMod = ((form - 50) / 10).round();
    final fatigueMod = (fatigue / 20).round();
    return (base + formMod - fatigueMod).clamp(1, 99);
  }

  int get effectiveStamina {
    if (playerCard == null) return 0;
    final base = playerCard!.stamina;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectivePace {
    if (playerCard == null) return 0;
    final base = playerCard!.pace;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveSpin {
    if (playerCard == null) return 0;
    final base = playerCard!.spin;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveAggression {
    if (playerCard == null) return 0;
    final base = playerCard!.aggression;
    final formMod = ((form - 50) / 10).round();
    return (base + formMod).clamp(1, 99);
  }

  int get effectiveTechnique {
    if (playerCard == null) return 0;
    final base = playerCard!.technique;
    final formMod = ((form - 50) / 10).round();
    return (base + formMod).clamp(1, 99);
  }

  int get effectivePower {
    if (playerCard == null) return 0;
    final base = playerCard!.power;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveConsistency {
    if (playerCard == null) return 0;
    final base = playerCard!.consistency;
    final formMod = ((form - 50) / 10).round();
    return (base + formMod).clamp(1, 99);
  }

  int get effectiveTemperament {
    if (playerCard == null) return 0;
    final base = playerCard!.temperament;
    final formMod = ((form - 50) / 10).round();
    return (base + formMod).clamp(1, 99);
  }

  int get effectiveShotMaking {
    if (playerCard == null) return 0;
    final base = playerCard!.shotMaking;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveRunning {
    if (playerCard == null) return 0;
    final base = playerCard!.running;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveAccuracy {
    if (playerCard == null) return 0;
    final base = playerCard!.accuracy;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveVariations {
    if (playerCard == null) return 0;
    final base = playerCard!.variations;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveYorkers {
    if (playerCard == null) return 0;
    final base = playerCard!.yorkers;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  int get effectiveBouncer {
    if (playerCard == null) return 0;
    final base = playerCard!.bouncer;
    final fatigueMod = (fatigue / 20).round();
    return (base - fatigueMod).clamp(1, 99);
  }

  UserCard copyWith({
    int? level,
    int? xp,
    int? form,
    int? fatigue,
    int? matchesPlayed,
    int? runsScored,
    int? wicketsTaken,
    int? contractsRemaining,
    int? contractsMax,
  }) {
    return UserCard(
      id: id,
      userId: userId,
      cardId: cardId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      form: form ?? this.form,
      fatigue: fatigue ?? this.fatigue,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      runsScored: runsScored ?? this.runsScored,
      wicketsTaken: wicketsTaken ?? this.wicketsTaken,
      isTradeable: isTradeable,
      acquiredAt: acquiredAt,
      contractsRemaining: contractsRemaining ?? this.contractsRemaining,
      contractsMax: contractsMax ?? this.contractsMax,
      playerCard: playerCard,
    );
  }

  // Contract helpers
  bool get hasContracts => contractsRemaining > 0;
  bool get isOutOfContracts => contractsRemaining == 0;
  double get contractProgress => contractsMax > 0 ? contractsRemaining / contractsMax : 0;
}