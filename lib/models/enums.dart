// String-backed enums used across Cricket Ultimate Manager models.
//
// Each enum has a [value] getter returning the DB/serialized string, and a
// static [fromValue] factory for deserialization. This lets models use
// type-safe enums internally while keeping DB compatibility.

// ── Match Format ──────────────────────────────────────────────────

enum MatchFormat {
  t10('t10'),
  t20('t20'),
  odi('odi'),
  test('test');

  final String value;
  const MatchFormat(this.value);

  static MatchFormat fromValue(String v) =>
      MatchFormat.values.firstWhere((e) => e.value == v, orElse: () => t20);

  int get overs {
    switch (this) {
      case MatchFormat.t10:
        return 10;
      case MatchFormat.t20:
        return 20;
      case MatchFormat.odi:
        return 50;
      case MatchFormat.test:
        return 90;
    }
  }
}

// ── Match Status ──────────────────────────────────────────────────

enum MatchStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  abandoned('abandoned');

  final String value;
  const MatchStatus(this.value);

  static MatchStatus fromValue(String v) =>
      MatchStatus.values.firstWhere((e) => e.value == v, orElse: () => pending);

  bool get isLive => this == inProgress;
  bool get isDone => this == completed;
}

// ── Pitch Condition ───────────────────────────────────────────────

enum PitchCondition {
  balanced('balanced'),
  battingFriendly('batting_friendly'),
  bowlingFriendly('bowling_friendly'),
  spinFriendly('spin_friendly'),
  seamFriendly('seam_friendly');

  final String value;
  const PitchCondition(this.value);

  static PitchCondition fromValue(String v) =>
      PitchCondition.values.firstWhere((e) => e.value == v, orElse: () => balanced);
}

// ── Player Role ───────────────────────────────────────────────────

enum PlayerRole {
  batsman('batsman'),
  bowler('bowler'),
  allRounder('all_rounder'),
  wicketKeeper('wicket_keeper');

  final String value;
  const PlayerRole(this.value);

  static PlayerRole fromValue(String v) =>
      PlayerRole.values.firstWhere((e) => e.value == v, orElse: () => batsman);

  String get display {
    switch (this) {
      case PlayerRole.batsman:
        return 'BAT';
      case PlayerRole.bowler:
        return 'BOWL';
      case PlayerRole.allRounder:
        return 'ALL';
      case PlayerRole.wicketKeeper:
        return 'WK';
    }
  }

  String get label {
    switch (this) {
      case PlayerRole.batsman:
        return 'Batsman';
      case PlayerRole.bowler:
        return 'Bowler';
      case PlayerRole.allRounder:
        return 'All-rounder';
      case PlayerRole.wicketKeeper:
        return 'Wicket-keeper';
    }
  }
}

// ── Card Rarity ───────────────────────────────────────────────────

enum CardRarity {
  bronze('bronze'),
  silver('silver'),
  gold('gold'),
  elite('elite'),
  legend('legend');

  final String value;
  const CardRarity(this.value);

  static CardRarity fromValue(String v) =>
      CardRarity.values.firstWhere((e) => e.value == v, orElse: () => bronze);

  int get color {
    switch (this) {
      case CardRarity.bronze:
        return 0xFFCD7F32;
      case CardRarity.silver:
        return 0xFFC0C0C0;
      case CardRarity.gold:
        return 0xFFFFD700;
      case CardRarity.elite:
        return 0xFF9932CC;
      case CardRarity.legend:
        return 0xFFFF4500;
    }
  }
}

// ── Card Type ─────────────────────────────────────────────────────

enum CardType {
  standard('standard'),
  teamOfTheWeek('team_of_the_week'),
  event('event'),
  icon('icon'),
  flashback('flashback');

  final String value;
  const CardType(this.value);

  static CardType fromValue(String v) =>
      CardType.values.firstWhere((e) => e.value == v, orElse: () => standard);
}

// ── Market Listing Status ─────────────────────────────────────────

enum ListingStatus {
  active('active'),
  sold('sold'),
  expired('expired'),
  cancelled('cancelled');

  final String value;
  const ListingStatus(this.value);

  static ListingStatus fromValue(String v) =>
      ListingStatus.values.firstWhere((e) => e.value == v, orElse: () => active);
}

// ── Listing Type ──────────────────────────────────────────────────

enum ListingType {
  card('card'),
  contract('contract');

  final String value;
  const ListingType(this.value);

  static ListingType fromValue(String v) =>
      ListingType.values.firstWhere((e) => e.value == v, orElse: () => card);
}

// ── Bid Status ────────────────────────────────────────────────────

enum BidStatus {
  active('active'),
  outbid('outbid'),
  won('won'),
  lost('lost');

  final String value;
  const BidStatus(this.value);

  static BidStatus fromValue(String v) =>
      BidStatus.values.firstWhere((e) => e.value == v, orElse: () => active);
}

// ── Contract Tier ─────────────────────────────────────────────────

enum ContractTier {
  bronze('bronze'),
  silver('silver'),
  gold('gold'),
  elite('elite'),
  legend('legend');

  final String value;
  const ContractTier(this.value);

  static ContractTier fromValue(String v) =>
      ContractTier.values.firstWhere((e) => e.value == v, orElse: () => bronze);

  int get color {
    switch (this) {
      case ContractTier.bronze:
        return 0xFFCD7F32;
      case ContractTier.silver:
        return 0xFFC0C0C0;
      case ContractTier.gold:
        return 0xFFFFD700;
      case ContractTier.elite:
        return 0xFF9932CC;
      case ContractTier.legend:
        return 0xFFFF4500;
    }
  }
}

// ── Season Tier ───────────────────────────────────────────────────

enum SeasonTier {
  bronze('bronze'),
  silver('silver'),
  gold('gold'),
  elite('elite'),
  champion('champion');

  final String value;
  const SeasonTier(this.value);

  static SeasonTier fromValue(String v) =>
      SeasonTier.values.firstWhere((e) => e.value == v, orElse: () => bronze);
}

// ── Objective Status ──────────────────────────────────────────────

enum ObjectiveStatus {
  active('active'),
  completed('completed'),
  claimed('claimed');

  final String value;
  const ObjectiveStatus(this.value);

  static ObjectiveStatus fromValue(String v) =>
      ObjectiveStatus.values.firstWhere((e) => e.value == v, orElse: () => active);
}

// ── Tournament Status ─────────────────────────────────────────────

enum TournamentStatus {
  open('open'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const TournamentStatus(this.value);

  static TournamentStatus fromValue(String v) =>
      TournamentStatus.values.firstWhere((e) => e.value == v, orElse: () => open);
}

// ── Challenge Status ──────────────────────────────────────────────

enum ChallengeStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired'),
  completed('completed');

  final String value;
  const ChallengeStatus(this.value);

  static ChallengeStatus fromValue(String v) =>
      ChallengeStatus.values.firstWhere((e) => e.value == v, orElse: () => pending);
}
