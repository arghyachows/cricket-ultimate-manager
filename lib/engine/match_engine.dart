import 'dart:math';
import '../models/models.dart';
import 'commentary_templates.dart';
import 'probability_calculator.dart';

/// Ball-by-ball cricket match simulation engine.
/// Takes into account batting/bowling ratings, chemistry,
/// pitch conditions, form, fatigue, and randomness.
class MatchEngine {
  final List<LineupPlayer> homeXI;
  final List<LineupPlayer> awayXI;
  final int homeChemistry;
  final int awayChemistry;
  final int overs;
  final String pitchCondition;
  final String homeTeamName;
  final String awayTeamName;
  final bool homeBatsFirst;
  final Random _rng = Random();

  // Match state
  int _innings = 1;
  int _overNumber = 0;
  int _ballNumber = 0;
  int _score1 = 0;
  int _wickets1 = 0;
  int _score2 = 0;
  int _wickets2 = 0;

  /// Public accessors for final scores
  int get score1 => _score1;
  int get score2 => _score2;
  int get wickets1 => _wickets1;
  int get wickets2 => _wickets2;
  int get currentInnings => _innings;
  int get overNumber => _overNumber;
  int get ballNumber => _ballNumber;
  bool get matchComplete => _matchComplete;
  int get target => _target;
  int _currentBatsmanIndex = 0;
  int _currentBowlerIndex = 0;
  int _nonStrikerIndex = 1;
  int _nextBatsmanIndex = 2;
  bool _matchComplete = false;
  int _target = 0;
  bool _isSuperOver = false;
  bool _freeHitNext = false;

  // Batting/Bowling order
  late List<LineupPlayer> _battingOrder1;
  late List<LineupPlayer> _bowlingOrder1;
  late List<LineupPlayer> _battingOrder2;
  late List<LineupPlayer> _bowlingOrder2;

  // Current innings references
  late List<LineupPlayer> _currentBatting;
  late List<LineupPlayer> _currentBowling;

  MatchEngine({
    required this.homeXI,
    required this.awayXI,
    required this.homeChemistry,
    required this.awayChemistry,
    required this.overs,
    required this.pitchCondition,
    this.homeTeamName = 'Home',
    this.awayTeamName = 'Away',
    this.homeBatsFirst = true,
  }) {
    _battingOrder1 = List.from(homeBatsFirst ? homeXI : awayXI);
    
    List<LineupPlayer> getBowlingOrder(List<LineupPlayer> xi) {
      var bowlers = xi.where((p) =>
              p.userCard?.playerCard?.role == PlayerRole.bowler ||
              p.userCard?.playerCard?.role == PlayerRole.allRounder)
          .toList();
      if (bowlers.isEmpty) bowlers = List.from(xi);
      
      bowlers.sort((a, b) {
        if (a.isBowler1) return -1;
        if (b.isBowler1) return 1;
        if (a.isBowler2) return -1;
        if (b.isBowler2) return 1;
        return 0;
      });
      return bowlers;
    }

    _bowlingOrder1 = getBowlingOrder(homeBatsFirst ? homeXI : awayXI);
    _battingOrder2 = List.from(homeBatsFirst ? awayXI : homeXI);
    _bowlingOrder2 = getBowlingOrder(homeBatsFirst ? awayXI : homeXI);

    // First innings: batting order 1 bats, bowling order 2 bowls
    _currentBatting = _battingOrder1;
    _currentBowling = _bowlingOrder2;
    _currentBatsmanIndex = 0;
    _nonStrikerIndex = 1;
    _currentBowlerIndex = 0;
  }

  int get maxOvers => overs;

  /// Card ID of the batsman currently on strike (will face the next ball).
  String? get currentStrikerCardId =>
      _currentBatsmanIndex < _currentBatting.length
          ? _currentBatting[_currentBatsmanIndex].userCardId
          : null;

  /// Card ID of the non-striker.
  String? get currentNonStrikerCardId =>
      _nonStrikerIndex < _currentBatting.length
          ? _currentBatting[_nonStrikerIndex].userCardId
          : null;

  bool get isFirstInnings => _innings == 1;

  int get _currentWickets => isFirstInnings ? _wickets1 : _wickets2;

  LineupPlayer get _currentBatsman => _currentBatting[_currentBatsmanIndex];
  LineupPlayer get _currentBowler =>
      _currentBowling[_currentBowlerIndex % _currentBowling.length];

  String getBatsmanName(String cardId) {
    for (final p in [...homeXI, ...awayXI]) {
      if (p.userCardId == cardId) {
        return p.userCard?.playerCard?.playerName ?? 'Unknown';
      }
    }
    return 'Unknown';
  }

  String getBowlerName(String cardId) => getBatsmanName(cardId);

  /// Simulate one ball. Returns null when match is complete.
  MatchEvent? simulateNextBall() {
    if (_matchComplete) return null;

    _ballNumber++;
    if (_ballNumber > 6) {
      _ballNumber = 1;
      _overNumber++;
      // Rotate bowler each over
      _currentBowlerIndex++;
      // Rotate strike
      _swapStrike();
    }

    // Check if innings/match is over
    final maxOversForInnings = _isSuperOver ? 1 : maxOvers;
    final maxWicketsForInnings = _isSuperOver ? 2 : 10;
    
    if (_overNumber >= maxOversForInnings || _currentWickets >= maxWicketsForInnings) {
      if (isFirstInnings) {
        return _endInnings();
      } else {
        // Check for tie and trigger super over
        if (_score1 == _score2 && !_isSuperOver) {
          return _startSuperOver();
        }
        return _endMatch();
      }
    }

    // Second innings: check if target chased
    if (!isFirstInnings && _score2 > _target) {
      return _endMatch();
    }

    final batsman = _currentBatsman;
    final bowler = _currentBowler;

    final battingRating = batsman.userCard?.effectiveBatting ?? 50;
    final bowlingRating = bowler.userCard?.effectiveBowling ?? 50;
    final chemistry = isFirstInnings
        ? (homeBatsFirst ? homeChemistry : awayChemistry)
        : (homeBatsFirst ? awayChemistry : homeChemistry);

    // Calculate outcome using probability calculator module
    final outcome = calculateOutcome(
      battingRating: battingRating,
      bowlingRating: bowlingRating,
      chemistry: chemistry,
      batsman: batsman,
      bowler: bowler,
      isFirstInnings: isFirstInnings,
      currentScore: isFirstInnings ? _score1 : _score2,
      currentWickets: _currentWickets,
      overNumber: _overNumber,
      ballNumber: _ballNumber,
      maxOvers: maxOvers,
      target: _target,
      pitchCondition: pitchCondition,
      rng: _rng,
    );

    // Build event
    final batsmanName = batsman.userCard?.playerCard?.playerName ?? 'Batsman';
    final bowlerName = bowler.userCard?.playerCard?.playerName ?? 'Bowler';

    int runs = 0;
    bool isWicket = false;
    bool isBoundary = false;
    String eventType;
    String commentary;
    String? wicketTypeResult;
    String? fielderCardIdResult;
    final isFreeHit = _freeHitNext;

    switch (outcome) {
      case BallOutcome.dot:
        runs = 0;
        eventType = 'dot_ball';
        commentary = dotCommentary(batsmanName, bowlerName, _rng);
        if (isFreeHit) commentary += ' (Free Hit)';
        break;
      case BallOutcome.single:
        runs = 1;
        eventType = 'single';
        final singleOptions = [
          '$batsmanName pushes for a quick single.',
          'Good running! They scamper through for one.',
          '$batsmanName taps it into the gap, easy single.',
          'Quick single taken by $batsmanName.',
          '$batsmanName nudges it away for a single.',
          'They steal a single, good running between the wickets.',
          '$batsmanName works it into space for one run.',
        ];
        commentary = singleOptions[_rng.nextInt(singleOptions.length)];
        if (isFreeHit) commentary += ' (Free Hit)';
        _swapStrike();
        break;
      case BallOutcome.double:
        runs = 2;
        eventType = 'double';
        final doubleOptions = [
          '$batsmanName drives through the gap for two.',
          'Well placed! They come back for the second.',
          '$batsmanName finds the gap, comfortable two runs.',
          'Good running between the wickets, two runs added.',
          '$batsmanName works it into space for a couple.',
          'Pushed into the deep, they run hard for two.',
        ];
        commentary = doubleOptions[_rng.nextInt(doubleOptions.length)];
        if (isFreeHit) commentary += ' (Free Hit)';
        break;
      case BallOutcome.triple:
        runs = 3;
        eventType = 'triple';
        final tripleOptions = [
          '$batsmanName finds the gap, they run three!',
          'Excellent running! Three runs taken!',
          '$batsmanName pushes it into the deep, they hustle for three!',
          'Great placement, they run hard for three runs!',
          'Into the gap! They sprint back for the third!',
        ];
        commentary = tripleOptions[_rng.nextInt(tripleOptions.length)];
        if (isFreeHit) commentary += ' (Free Hit)';
        _swapStrike();
        break;
      case BallOutcome.four:
        runs = 4;
        isBoundary = true;
        eventType = 'four';
        commentary = fourCommentary(batsmanName, bowlerName, _rng);
        if (isFreeHit) commentary += ' (Free Hit)';
        break;
      case BallOutcome.six:
        runs = 6;
        isBoundary = true;
        eventType = 'six';
        commentary = sixCommentary(batsmanName, _rng);
        if (isFreeHit) commentary += ' (Free Hit)';
        break;
      case BallOutcome.wicket:
        // No wicket on free hit
        if (isFreeHit) {
          runs = 0;
          eventType = 'dot_ball';
          commentary = '$batsmanName misses but it\'s a FREE HIT! No wicket!';
          isWicket = false;
        } else {
          runs = 0;
          isWicket = true;
          eventType = 'wicket';
          wicketTypeResult = _randomWicketType();
          final fielder = _pickFielder(wicketTypeResult, bowler);
          fielderCardIdResult = fielder?.userCardId;
          final fielderName = fielder?.userCard?.playerCard?.playerName;
          commentary = wicketCommentary(batsmanName, bowlerName, wicketTypeResult, fielderName, _rng);
        }
        break;
      case BallOutcome.wide:
        runs = 1;
        eventType = 'wide';
        final wideOptions = [
          'Wide ball from $bowlerName. Extra run.',
          'WIDE! $bowlerName loses his line.',
          'That\'s wide! $bowlerName strays down the leg side.',
          'Wide called! Poor delivery from $bowlerName.',
          'WIDE! $bowlerName misses his mark.',
          '$bowlerName sprays it wide, extra run conceded.',
        ];
        commentary = wideOptions[_rng.nextInt(wideOptions.length)];
        _ballNumber--; // Doesn't count as a legal ball
        break;
      case BallOutcome.noBall:
        runs = 1;
        eventType = 'no_ball';
        final noBallOptions = [
          'No ball! Free hit coming up.',
          'NO BALL! $bowlerName oversteps! FREE HIT next!',
          'That\'s a no ball! Extra delivery.',
          'NO BALL called! $bowlerName has overstepped.',
          'Free hit next ball! $bowlerName oversteps the crease.',
          '$bowlerName oversteps, that\'s a no ball!',
        ];
        commentary = noBallOptions[_rng.nextInt(noBallOptions.length)];
        _ballNumber--;
        _freeHitNext = true; // Set free hit for next ball
        break;
    }

    // Update score
    if (isFirstInnings) {
      _score1 += runs;
      if (isWicket) {
        _wickets1++;
        _advanceBatsman();
      }
    } else {
      _score2 += runs;
      if (isWicket) {
        _wickets2++;
        _advanceBatsman();
      }
    }

    // Clear free hit flag after the ball (unless it was a wide/no-ball)
    if (eventType != 'no_ball' && eventType != 'wide') {
      _freeHitNext = false;
    }

    // Check second innings chase
    if (!isFirstInnings && _score2 > _target) {
      _matchComplete = true;
    }

    return MatchEvent(
      id: '${_innings}_${_overNumber}_$_ballNumber',
      matchId: '',
      innings: _innings,
      overNumber: _overNumber,
      ballNumber: _ballNumber,
      battingTeamId: '',
      bowlingTeamId: '',
      batsmanCardId: batsman.userCardId,
      bowlerCardId: bowler.userCardId,
      eventType: eventType,
      runs: runs,
      isBoundary: isBoundary,
      isWicket: isWicket,
      wicketType: wicketTypeResult,
      fielderCardId: fielderCardIdResult,
      commentary: commentary,
      scoreAfter: isFirstInnings ? _score1 : _score2,
      wicketsAfter: isFirstInnings ? _wickets1 : _wickets2,
    );
  }

  MatchEvent? _endInnings() {
    if (isFirstInnings) {
      _target = _score1;

      // Correct end-of-innings over/ball:
      // _ballNumber was already incremented for the next (non-existent) ball.
      int endOver, endBall;
      if (_ballNumber == 1 && _overNumber > 0) {
        // Rolled over from ball 6 → complete over boundary
        endOver = _overNumber;
        endBall = 0;
      } else {
        endOver = _overNumber;
        endBall = _ballNumber > 0 ? _ballNumber - 1 : 0;
      }

      // Save innings 1 player IDs before swapping to innings 2
      final lastBatsmanId = _currentBatting[_currentBatsmanIndex].userCardId;
      final lastBowlerId = _currentBowling[_currentBowlerIndex % _currentBowling.length].userCardId;

      _innings = 2;
      _overNumber = 0;
      _ballNumber = 0;
      _currentBatting = _battingOrder2;
      _currentBowling = _bowlingOrder1;
      _currentBatsmanIndex = 0;
      _nonStrikerIndex = 1;
      _nextBatsmanIndex = 2;
      _currentBowlerIndex = 0;
      _freeHitNext = false;

      final commentary = _isSuperOver
          ? 'End of Super Over first innings. Score: $_score1/$_wickets1. Target: ${_target + 1}'
          : 'End of first innings. Score: $_score1/$_wickets1. Target: ${_target + 1}';

      return MatchEvent(
        id: 'innings_break',
        matchId: '',
        innings: 1,
        overNumber: endOver,
        ballNumber: endBall,
        battingTeamId: '',
        bowlingTeamId: '',
        batsmanCardId: lastBatsmanId,
        bowlerCardId: lastBowlerId,
        eventType: 'innings_break',
        runs: 0,
        commentary: commentary,
        scoreAfter: _score1,
        wicketsAfter: _wickets1,
      );
    } else {
      return _endMatch();
    }
  }

  MatchEvent? _startSuperOver() {
    final lastBatsmanId = _currentBatting[_currentBatsmanIndex].userCardId;
    final lastBowlerId = _currentBowling[_currentBowlerIndex % _currentBowling.length].userCardId;

    // Store regular match scores
    final regularScore1 = _score1;
    final regularScore2 = _score2;
    final regularWickets1 = _wickets1;
    final regularWickets2 = _wickets2;

    // Reset for super over
    _isSuperOver = true;
    _innings = 1;
    _overNumber = 0;
    _ballNumber = 0;
    _score1 = 0;
    _wickets1 = 0;
    _score2 = 0;
    _wickets2 = 0;
    _target = 0;
    _freeHitNext = false;

    // Reset batting/bowling for super over (use same orders)
    _currentBatting = _battingOrder1;
    _currentBowling = _bowlingOrder2;
    _currentBatsmanIndex = 0;
    _nonStrikerIndex = 1;
    _nextBatsmanIndex = 2;
    _currentBowlerIndex = 0;

    return MatchEvent(
      id: 'super_over',
      matchId: '',
      innings: 2,
      overNumber: 0,
      ballNumber: 0,
      battingTeamId: '',
      bowlingTeamId: '',
      batsmanCardId: lastBatsmanId,
      bowlerCardId: lastBowlerId,
      eventType: 'super_over',
      runs: 0,
      commentary: 'Match tied at $regularScore1/$regularWickets1! SUPER OVER to decide the winner!',
      scoreAfter: regularScore2,
      wicketsAfter: regularWickets2,
    );
  }

  MatchEvent? _endMatch() {
    _matchComplete = true;
    return null;
  }

  String getMatchResult() {
    final battingFirstName = homeBatsFirst ? homeTeamName : awayTeamName;
    final battingSecondName = homeBatsFirst ? awayTeamName : homeTeamName;
    
    if (_isSuperOver) {
      if (_score2 > _score1) {
        final wicketsRemaining = 10 - _wickets2;
        return '$battingSecondName wins the Super Over by $wicketsRemaining wickets!';
      } else if (_score1 > _score2) {
        final runDiff = _score1 - _score2;
        return '$battingFirstName wins the Super Over by $runDiff runs!';
      }
      // If super over is also tied, team batting second wins (fewer wickets lost rule)
      if (_wickets2 < _wickets1) {
        return '$battingSecondName wins on fewer wickets lost!';
      } else if (_wickets1 < _wickets2) {
        return '$battingFirstName wins on fewer wickets lost!';
      }
      return '$battingSecondName wins the Super Over!';
    }
    
    if (_score2 > _score1) {
      final wicketsRemaining = 10 - _wickets2;
      return '$battingSecondName wins by $wicketsRemaining wickets!';
    } else if (_score1 > _score2) {
      final runDiff = _score1 - _score2;
      return '$battingFirstName wins by $runDiff runs!';
    } else {
      return 'Match tied!';
    }
  }

  void _swapStrike() {
    final temp = _currentBatsmanIndex;
    _currentBatsmanIndex = _nonStrikerIndex;
    _nonStrikerIndex = temp;
  }

  void _advanceBatsman() {
    // New batsman replaces the dismissed one (current batsman)
    if (_nextBatsmanIndex < _currentBatting.length) {
      _currentBatsmanIndex = _nextBatsmanIndex;
      _nextBatsmanIndex++;
    }
  }

  String _randomWicketType() {
    final types = ['bowled', 'caught', 'lbw', 'run_out', 'stumped', 'caught_behind'];
    return types[_rng.nextInt(types.length)];
  }

  /// Pick a fielder for caught/stumped dismissals from the bowling team
  LineupPlayer? _pickFielder(String wicketType, LineupPlayer bowler) {
    if (wicketType == 'bowled' || wicketType == 'lbw') return null;
    // All players in the fielding side
    final allFielders = isFirstInnings
        ? (homeBatsFirst ? awayXI : homeXI)
        : (homeBatsFirst ? homeXI : awayXI);
    if (wicketType == 'caught_behind' || wicketType == 'stumped') {
      // Pick the wicket keeper
      final keepers = allFielders.where((p) => p.userCard?.playerCard?.role == PlayerRole.wicketKeeper).toList();
      if (keepers.isNotEmpty) return keepers[_rng.nextInt(keepers.length)];
    }
    // Pick any fielder (exclude batsman, exclude bowler for caught)
    final candidates = allFielders.where((p) => p.userCardId != bowler.userCardId).toList();
    if (candidates.isEmpty) return allFielders[_rng.nextInt(allFielders.length)];
    return candidates[_rng.nextInt(candidates.length)];
  }
}
