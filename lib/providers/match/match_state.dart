import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/models.dart';
import 'match_phase.dart';

export 'match_state_computed.dart';

part 'match_state.freezed.dart';

/// Represents the state of a cricket match at any point.
@freezed
class MatchState with _$MatchState {
  const factory MatchState({
    MatchModel? match,
    @Default([]) List<MatchEvent> events,
    @Default(false) bool isSimulating,
    @Default(false) bool isMatchComplete,
    String? currentCommentary,
    @Default(1) int currentInnings,
    @Default({}) Map<String, BatsmanStats> batsmanStats,
    @Default({}) Map<String, BowlerStats> bowlerStats,
    @Default('') String homeTeamName,
    @Default('') String awayTeamName,
    @Default('t20') String matchFormat,
    @Default(20) int matchOvers,
    @Default('Village') String matchDifficulty,
    bool? homeWon,
    @Default(0) int coinsAwarded,
    @Default(0) int xpAwarded,
    @Default('balanced') String pitchCondition,
    @Default('clear') String weatherCondition,
    @Default(true) bool userWonToss,
    @Default('bat') String tossDecision,
    @Default(true) bool homeBatsFirst,
    @Default(0) int target,
    @Default([]) List<String> xiOrder1,
    @Default([]) List<String> xiOrder2,
    @Default([]) List<String> userXiCardIds,
    String? levelUpPackAwarded,
    String? contractPackAwarded,
    int? newLevel,
    @Default('') String strikerCardId,
    @Default('') String nonStrikerCardId,
    @Default(false) bool challengeMode,
    @Default(MatchPhase.notStarted) MatchPhase phase,
  }) = _MatchState;

  const MatchState._();

  /// Valid phase transitions — single source of truth for match lifecycle.
  static const Map<MatchPhase, List<MatchPhase>> validTransitions = {
    MatchPhase.notStarted: [MatchPhase.toss],
    MatchPhase.toss: [MatchPhase.firstInnings, MatchPhase.abandoned],
    MatchPhase.firstInnings: [MatchPhase.inningsBreak, MatchPhase.abandoned],
    MatchPhase.inningsBreak: [MatchPhase.secondInnings, MatchPhase.abandoned],
    MatchPhase.secondInnings: [MatchPhase.matchComplete, MatchPhase.abandoned],
    MatchPhase.matchComplete: [],
    MatchPhase.abandoned: [],
  };

  /// Returns true if transitioning from [from] to [to] is valid.
  static bool isValidTransition(MatchPhase from, MatchPhase to) {
    return validTransitions[from]?.contains(to) ?? false;
  }

  factory MatchState.initial({
    MatchModel? match,
    List<MatchEvent> events = const [],
    bool isSimulating = false,
    bool isMatchComplete = false,
    String? currentCommentary,
    int currentInnings = 1,
    Map<String, BatsmanStats> batsmanStats = const {},
    Map<String, BowlerStats> bowlerStats = const {},
    String homeTeamName = '',
    String awayTeamName = '',
    String matchFormat = 't20',
    int matchOvers = 20,
    String matchDifficulty = 'Village',
    bool? homeWon,
    int coinsAwarded = 0,
    int xpAwarded = 0,
    String pitchCondition = 'balanced',
    String weatherCondition = 'clear',
    bool userWonToss = true,
    String tossDecision = 'bat',
    bool homeBatsFirst = true,
    int target = 0,
    List<String> xiOrder1 = const [],
    List<String> xiOrder2 = const [],
    List<String> userXiCardIds = const [],
    String? levelUpPackAwarded,
    String? contractPackAwarded,
    int? newLevel,
    String strikerCardId = '',
    String nonStrikerCardId = '',
    bool challengeMode = false,
  }) => MatchState(
    match: match,
    events: events,
    isSimulating: isSimulating,
    isMatchComplete: isMatchComplete,
    currentCommentary: currentCommentary,
    currentInnings: currentInnings,
    batsmanStats: batsmanStats,
    bowlerStats: bowlerStats,
    homeTeamName: homeTeamName,
    awayTeamName: awayTeamName,
    matchFormat: matchFormat,
    matchOvers: matchOvers,
    matchDifficulty: matchDifficulty,
    homeWon: homeWon,
    coinsAwarded: coinsAwarded,
    xpAwarded: xpAwarded,
    pitchCondition: pitchCondition,
    weatherCondition: weatherCondition,
    userWonToss: userWonToss,
    tossDecision: tossDecision,
    homeBatsFirst: homeBatsFirst,
    target: target,
    xiOrder1: xiOrder1,
    xiOrder2: xiOrder2,
    userXiCardIds: userXiCardIds,
    levelUpPackAwarded: levelUpPackAwarded,
    contractPackAwarded: contractPackAwarded,
    newLevel: newLevel,
    strikerCardId: strikerCardId,
    nonStrikerCardId: nonStrikerCardId,
    challengeMode: challengeMode,
  );
}

/// Per-batsman stats for display in the scorecard.
/// Kept mutable — updated frequently during ball-by-ball simulation.
class BatsmanStats {
  final String name;
  final int innings;
  final int battingOrder;
  int runs;
  int balls;
  int fours;
  int sixes;
  bool isOut;
  String? dismissalType;

  BatsmanStats({
    required this.name,
    required this.innings,
    this.battingOrder = 99,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalType,
  });

  double get strikeRate => balls > 0 ? (runs / balls) * 100 : 0;

  BatsmanStats copyWith({
    String? name,
    int? innings,
    int? battingOrder,
    int? runs,
    int? balls,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissalType,
  }) {
    return BatsmanStats(
      name: name ?? this.name,
      innings: innings ?? this.innings,
      battingOrder: battingOrder ?? this.battingOrder,
      runs: runs ?? this.runs,
      balls: balls ?? this.balls,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissalType: dismissalType ?? this.dismissalType,
    );
  }
}

/// Per-bowler stats for display in the scorecard.
/// Kept mutable — updated frequently during ball-by-ball simulation.
class BowlerStats {
  final String name;
  final int innings;
  int overs;
  int balls;
  int runs;
  int wickets;
  int maidens;
  int dotBalls;

  BowlerStats({
    required this.name,
    required this.innings,
    this.overs = 0,
    this.balls = 0,
    this.runs = 0,
    this.wickets = 0,
    this.maidens = 0,
    this.dotBalls = 0,
  });

  double get economy {
    final fullOvers = balls ~/ 6;
    final remainingBalls = balls % 6;
    final totalOvers = fullOvers + (remainingBalls / 6);
    return totalOvers > 0 ? runs / totalOvers : 0;
  }

  String get oversDisplay {
    final fullOvers = balls ~/ 6;
    final remainingBalls = balls % 6;
    return '$fullOvers.$remainingBalls';
  }

  BowlerStats copyWith({
    String? name,
    int? innings,
    int? overs,
    int? balls,
    int? runs,
    int? wickets,
    int? maidens,
    int? dotBalls,
  }) {
    return BowlerStats(
      name: name ?? this.name,
      innings: innings ?? this.innings,
      overs: overs ?? this.overs,
      balls: balls ?? this.balls,
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      maidens: maidens ?? this.maidens,
      dotBalls: dotBalls ?? this.dotBalls,
    );
  }
}

/// Immutable summary of a completed match for history display.
class MatchSummary {
  final String homeTeamName;
  final String awayTeamName;
  final String format;
  final int homeScore;
  final int homeWickets;
  final String homeOvers;
  final int awayScore;
  final int awayWickets;
  final String awayOvers;
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;
  final DateTime playedAt;
  final Map<String, BatsmanStats> batsmanStats;
  final Map<String, BowlerStats> bowlerStats;
  final List<MatchEvent> events;
  final bool homeBatsFirst;
  final List<String> xiOrder1;
  final List<String> xiOrder2;

  const MatchSummary({
    required this.homeTeamName,
    required this.awayTeamName,
    required this.format,
    required this.homeScore,
    required this.homeWickets,
    required this.homeOvers,
    required this.awayScore,
    required this.awayWickets,
    required this.awayOvers,
    required this.homeWon,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.playedAt,
    required this.batsmanStats,
    required this.bowlerStats,
    required this.events,
    this.homeBatsFirst = true,
    this.xiOrder1 = const [],
    this.xiOrder2 = const [],
  });

  String get battingFirstName => homeBatsFirst ? homeTeamName : awayTeamName;
  String get battingSecondName => homeBatsFirst ? awayTeamName : homeTeamName;
  int get inn1Score => homeBatsFirst ? homeScore : awayScore;
  int get inn1Wickets => homeBatsFirst ? homeWickets : awayWickets;
  String get inn1Overs => homeBatsFirst ? homeOvers : awayOvers;
  int get inn2Score => homeBatsFirst ? awayScore : homeScore;
  int get inn2Wickets => homeBatsFirst ? awayWickets : homeWickets;
  String get inn2Overs => homeBatsFirst ? awayOvers : homeOvers;

  String get resultText {
    if (homeWon == true) {
      return '$homeTeamName won!';
    } else if (homeWon == false) {
      return '$awayTeamName won!';
    }
    return 'Match Drawn';
  }
}