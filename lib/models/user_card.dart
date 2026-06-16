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
  }) : assert(level >= 1, 'level must be >= 1'),
       assert(form >= 0 && form <= 100, 'form must be 0-100'),
       assert(fatigue >= 0, 'fatigue must be >= 0'),
       assert(contractsRemaining >= 0, 'contractsRemaining must be >= 0'),
       assert(contractsMax >= 0, 'contractsMax must be >= 0');

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
        'acquired_at': acquiredAt.toIso8601String(),
        'contracts_remaining': contractsRemaining,
        'contracts_max': contractsMax,
      };

  // ── Computed stats cache ──────────────────────────────────────
  // UserCard is immutable (all fields final), so computed values never change
  // after construction. We cache them to avoid recalculating 18 getters on
  // every UI frame (collection grids, squad builder, etc.).
  _CachedEffectiveStats? _cached;

  _CachedEffectiveStats get _stats {
    if (_cached == null) {
      _cached = _CachedEffectiveStats(playerCard, form, fatigue, level);
    }
    return _cached!;
  }

  /// Pre-computes all effective stats in one pass, then serves them via
  /// cached getters. Eliminates 18× redundant form/fatigue math per card.
  int get effectiveRating => _stats.rating;
  int get effectiveBatting => _stats.batting;
  int get effectiveBowling => _stats.bowling;
  int get effectiveStamina => _stats.stamina;
  int get effectivePace => _stats.pace;
  int get effectiveSpin => _stats.spin;
  int get effectiveAggression => _stats.aggression;
  int get effectiveTechnique => _stats.technique;
  int get effectivePower => _stats.power;
  int get effectiveConsistency => _stats.consistency;
  int get effectiveTemperament => _stats.temperament;
  int get effectiveShotMaking => _stats.shotMaking;
  int get effectiveRunning => _stats.running;
  int get effectiveAccuracy => _stats.accuracy;
  int get effectiveVariations => _stats.variations;
  int get effectiveYorkers => _stats.yorkers;
  int get effectiveBouncer => _stats.bouncer;


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

/// Pre-computed effective stats cache for [UserCard].
///
/// Since UserCard is fully immutable (all fields `final`), effective stats
/// computed from form/fatigue/level/playerCard never change, so we compute
/// them once and serve via cached getters. This eliminates 18× redundant
/// form/fatigue arithmetic per card per UI frame.
class _CachedEffectiveStats {
  final int rating;
  final int batting;
  final int bowling;
  final int stamina;
  final int pace;
  final int spin;
  final int aggression;
  final int technique;
  final int power;
  final int consistency;
  final int temperament;
  final int shotMaking;
  final int running;
  final int accuracy;
  final int variations;
  final int yorkers;
  final int bouncer;

  _CachedEffectiveStats(PlayerCard? pc, int form, int fatigue, int level) :
    rating = _compute(pc, pc?.rating ?? 0, form, fatigue, level, useForm: true, useFatigue: true, useLevel: true),
    batting = _compute(pc, pc?.batting ?? 0, form, fatigue, level, useForm: true, useFatigue: true),
    bowling = _compute(pc, pc?.bowling ?? 0, form, fatigue, level, useForm: true, useFatigue: true),
    stamina = _compute(pc, pc?.stamina ?? 0, form, fatigue, level, useFatigue: true),
    pace = _compute(pc, pc?.pace ?? 0, form, fatigue, level, useFatigue: true),
    spin = _compute(pc, pc?.spin ?? 0, form, fatigue, level, useFatigue: true),
    aggression = _compute(pc, pc?.aggression ?? 0, form, fatigue, level, useForm: true),
    technique = _compute(pc, pc?.technique ?? 0, form, fatigue, level, useForm: true),
    power = _compute(pc, pc?.power ?? 0, form, fatigue, level, useFatigue: true),
    consistency = _compute(pc, pc?.consistency ?? 0, form, fatigue, level, useForm: true),
    temperament = _compute(pc, pc?.temperament ?? 0, form, fatigue, level, useForm: true),
    shotMaking = _compute(pc, pc?.shotMaking ?? 0, form, fatigue, level, useFatigue: true),
    running = _compute(pc, pc?.running ?? 0, form, fatigue, level, useFatigue: true),
    accuracy = _compute(pc, pc?.accuracy ?? 0, form, fatigue, level, useFatigue: true),
    variations = _compute(pc, pc?.variations ?? 0, form, fatigue, level, useFatigue: true),
    yorkers = _compute(pc, pc?.yorkers ?? 0, form, fatigue, level, useFatigue: true),
    bouncer = _compute(pc, pc?.bouncer ?? 0, form, fatigue, level, useFatigue: true);

  static int _compute(
    PlayerCard? pc,
    int base,
    int form,
    int fatigue,
    int level, {
    bool useForm = false,
    bool useFatigue = false,
    bool useLevel = false,
  }) {
    if (pc == null) return 0;
    var value = base;
    if (useLevel) value += (level - 1) * 1;
    if (useForm) value += ((form - 50) / 10).round();
    if (useFatigue) value -= (fatigue / 20).round();
    return value.clamp(1, 99);
  }
}