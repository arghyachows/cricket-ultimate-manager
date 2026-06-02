import '../../models/models.dart';

/// Represents the state of a cricket match at any point.
class MatchState {
  final MatchModel? match;
  final List<MatchEvent> events;
  final bool isSimulating;
  final bool isMatchComplete;
  final String? currentCommentary;
  final int currentInnings;
  final Map<String, BatsmanStats> batsmanStats;
  final Map<String, BowlerStats> bowlerStats;
  final String homeTeamName;
  final String awayTeamName;
  final String matchFormat;
  final int matchOvers;
  final String matchDifficulty;
  final bool? homeWon;
  final int coinsAwarded;
  final int xpAwarded;
  final String pitchCondition;
  final String weatherCondition;
  final bool userWonToss;
  final String tossDecision;
  final bool homeBatsFirst;
  final int target;
  final List<String> xiOrder1;
  final List<String> xiOrder2;
  final String? levelUpPackAwarded;
  final int? newLevel;
  final String strikerCardId;
  final String nonStrikerCardId;
  final bool challengeMode;

  const MatchState({
    this.match,
    this.events = const [],
    this.isSimulating = false,
    this.isMatchComplete = false,
    this.currentCommentary,
    this.currentInnings = 1,
    this.batsmanStats = const {},
    this.bowlerStats = const {},
    this.homeTeamName = '',
    this.awayTeamName = '',
    this.matchFormat = 't20',
    this.matchOvers = 20,
    this.matchDifficulty = 'Village',
    this.homeWon,
    this.coinsAwarded = 0,
    this.xpAwarded = 0,
    this.pitchCondition = 'balanced',
    this.weatherCondition = 'clear',
    this.userWonToss = true,
    this.tossDecision = 'bat',
    this.homeBatsFirst = true,
    this.target = 0,
    this.xiOrder1 = const [],
    this.xiOrder2 = const [],
    this.levelUpPackAwarded,
    this.newLevel,
    this.strikerCardId = '',
    this.nonStrikerCardId = '',
    this.challengeMode = false,
  });

  bool get hasActiveMatch => isSimulating || isMatchComplete;

  int _inningsScore(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.scoreAfter;
  }

  int _inningsWickets(int inn) {
    if (events.isEmpty) return 0;
    final inns = events.where((e) => e.innings == inn);
    return inns.isEmpty ? 0 : inns.last.wicketsAfter;
  }

  String _inningsOvers(int inn) {
    final inns = events.where((e) => e.innings == inn && e.eventType != 'innings_break');
    if (inns.isEmpty) return '0.0';
    final legalBalls = inns.where((e) => e.eventType != 'wide' && e.eventType != 'no_ball').length;
    final overs = legalBalls ~/ 6;
    final balls = legalBalls % 6;
    return '$overs.$balls';
  }

  int get homeScore => homeBatsFirst ? _inningsScore(1) : _inningsScore(2);
  int get homeWickets => homeBatsFirst ? _inningsWickets(1) : _inningsWickets(2);
  String get homeOvers => homeBatsFirst ? _inningsOvers(1) : _inningsOvers(2);

  int get awayScore => homeBatsFirst ? _inningsScore(2) : _inningsScore(1);
  int get awayWickets => homeBatsFirst ? _inningsWickets(2) : _inningsWickets(1);
  String get awayOvers => homeBatsFirst ? _inningsOvers(2) : _inningsOvers(1);

  String get currentOvers => _inningsOvers(currentInnings);

  List<BatsmanStats> _orderedBatsmenForInnings(int innings, List<String> xiOrder) {
    final batsmen = batsmanStats.values.where((b) => b.innings == innings).toList();
    if (xiOrder.isEmpty) return batsmen;
    final statsMap = {for (final b in batsmen) b.name: b};
    final ordered = <BatsmanStats>[];
    for (final name in xiOrder) {
      ordered.add(statsMap[name] ?? BatsmanStats(name: name, innings: innings));
    }
    for (final b in batsmen) {
      if (!xiOrder.contains(b.name)) ordered.add(b);
    }
    return ordered;
  }

  List<BatsmanStats> get innings1Batsmen => _orderedBatsmenForInnings(1, xiOrder1);
  List<BatsmanStats> get innings2Batsmen => _orderedBatsmenForInnings(2, xiOrder2);
  List<BowlerStats> get innings1Bowlers => bowlerStats.values.where((b) => b.innings == 1).toList();
  List<BowlerStats> get innings2Bowlers => bowlerStats.values.where((b) => b.innings == 2).toList();
  List<BatsmanStats> get currentBatsmen =>
      batsmanStats.values.where((b) => b.innings == currentInnings && !b.isOut).toList();
  List<BowlerStats> get currentBowlers =>
      bowlerStats.values.where((b) => b.innings == currentInnings).toList();

  int get runsNeeded {
    if (currentInnings < 2 || target == 0) return 0;
    final chasingScore = _inningsScore(2);
    final needed = target + 1 - chasingScore;
    return needed > 0 ? needed : 0;
  }

  int get ballsRemaining {
    if (events.isEmpty) return matchOvers * 6;
    final inningsEvents = events.where((e) => e.innings == currentInnings);
    if (inningsEvents.isEmpty) return matchOvers * 6;
    final last = inningsEvents.last;
    final ballsBowled = last.overNumber * 6 + last.ballNumber;
    return (matchOvers * 6) - ballsBowled;
  }

  int get maxOversForFormat => matchFormat == 'odi' ? 50 : 20;

  double get requiredRunRate {
    if (currentInnings < 2 || ballsRemaining <= 0) return 0;
    return (runsNeeded / ballsRemaining) * 6;
  }

  MatchState copyWith({
    MatchModel? match,
    List<MatchEvent>? events,
    bool? isSimulating,
    bool? isMatchComplete,
    String? currentCommentary,
    int? currentInnings,
    Map<String, BatsmanStats>? batsmanStats,
    Map<String, BowlerStats>? bowlerStats,
    String? homeTeamName,
    String? awayTeamName,
    String? matchFormat,
    int? matchOvers,
    String? matchDifficulty,
    bool? homeWon,
    int? coinsAwarded,
    int? xpAwarded,
    String? pitchCondition,
    String? weatherCondition,
    bool? userWonToss,
    String? tossDecision,
    bool? homeBatsFirst,
    int? target,
    List<String>? xiOrder1,
    List<String>? xiOrder2,
    String? levelUpPackAwarded,
    int? newLevel,
    String? strikerCardId,
    String? nonStrikerCardId,
    bool? challengeMode,
    bool clearLevelUpPack = false,
  }) {
    return MatchState(
      match: match ?? this.match,
      events: events ?? this.events,
      isSimulating: isSimulating ?? this.isSimulating,
      isMatchComplete: isMatchComplete ?? this.isMatchComplete,
      currentCommentary: currentCommentary ?? this.currentCommentary,
      currentInnings: currentInnings ?? this.currentInnings,
      batsmanStats: batsmanStats ?? this.batsmanStats,
      bowlerStats: bowlerStats ?? this.bowlerStats,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      matchFormat: matchFormat ?? this.matchFormat,
      matchOvers: matchOvers ?? this.matchOvers,
      matchDifficulty: matchDifficulty ?? this.matchDifficulty,
      homeWon: homeWon ?? this.homeWon,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      pitchCondition: pitchCondition ?? this.pitchCondition,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      userWonToss: userWonToss ?? this.userWonToss,
      tossDecision: tossDecision ?? this.tossDecision,
      homeBatsFirst: homeBatsFirst ?? this.homeBatsFirst,
      target: target ?? this.target,
      xiOrder1: xiOrder1 ?? this.xiOrder1,
      xiOrder2: xiOrder2 ?? this.xiOrder2,
      levelUpPackAwarded: clearLevelUpPack ? null : (levelUpPackAwarded ?? this.levelUpPackAwarded),
      newLevel: clearLevelUpPack ? null : (newLevel ?? this.newLevel),
      strikerCardId: strikerCardId ?? this.strikerCardId,
      nonStrikerCardId: nonStrikerCardId ?? this.nonStrikerCardId,
      challengeMode: challengeMode ?? this.challengeMode,
    );
  }
}

/// Per-batsman stats for display in the scorecard.
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
}

/// Per-bowler stats for display in the scorecard.
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